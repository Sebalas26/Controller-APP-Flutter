import 'package:flutter/foundation.dart';

import '../../../login/login.dart';
import '../../../vender/models/vender_models.dart';
import '../../../../shared/network/controller_api_config.dart';
import '../../data/recoger_local_repository.dart';
import '../../data/recoger_remote_repository.dart';
import '../../models/recoger_models.dart';

enum RecogerTab { disponibles, reservadas, efectivas }

class RecogerController extends ChangeNotifier {
  RecogerController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    RecogerRemoteRepository? remoteRepository,
    RecogerLocalRepository? localRepository,
  }) : remoteRepository = remoteRepository ?? RecogerRemoteRepository(),
       localRepository = localRepository ?? RecogerLocalRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final RecogerRemoteRepository remoteRepository;
  final RecogerLocalRepository localRepository;

  RecogerTab selectedTab = RecogerTab.disponibles;
  RecogidaItem? selectedPickup;
  List<RecogidaItem> disponibles = const [];
  List<RecogidaItem> reservadas = const [];
  List<RecogidaItem> efectivas = const [];
  List<RecogidaPreenvio> preenvios = const [];
  bool loading = false;
  bool syncing = false;
  bool showPreenvios = false;
  String statusMessage = '';
  String? errorMessage;
  VenderPickupExecutionResult? lastBillingResult;

  Future<void> initialize() async {
    await _guarded(() async {
      reservadas = await localRepository.fixedPickups();
      efectivas = await localRepository.cachedEffectivePickups();
      if (!offline) {
        await Future.wait([
          refreshAvailable(silent: true),
          refreshReserved(silent: true),
          refreshEffective(silent: true),
        ]);
      }
    }, loadingValue: true);
  }

  void selectTab(RecogerTab tab) {
    selectedTab = tab;
    notifyListeners();
  }

  Future<void> refreshCurrent() {
    return switch (selectedTab) {
      RecogerTab.disponibles => refreshAvailable(),
      RecogerTab.reservadas => refreshReserved(),
      RecogerTab.efectivas => refreshEffective(),
    };
  }

  Future<void> refreshAvailable({bool silent = false}) async {
    if (offline) {
      statusMessage = 'Sin conexion para consultar recogidas disponibles.';
      notifyListeners();
      return;
    }
    await _guarded(() async {
      disponibles = await remoteRepository.fetchAvailable(
        config: apiConfig,
        appInformation: appInformation,
      );
      statusMessage = 'Recogidas disponibles actualizadas.';
    }, syncingValue: !silent);
  }

  Future<void> refreshReserved({bool silent = false}) async {
    await _guarded(() async {
      if (offline) {
        reservadas = await localRepository.fixedPickups();
        statusMessage = 'Recogidas reservadas cargadas desde BD local.';
        return;
      }
      final remote = await remoteRepository.fetchReserved(
        config: apiConfig,
        appInformation: appInformation,
      );
      await localRepository.saveFixedPickups(remote);
      reservadas = await localRepository.fixedPickups();
      final motives = await remoteRepository.fetchCancelMotives(
        config: apiConfig,
        appInformation: appInformation,
      );
      await localRepository.saveMotivos(motives);
      statusMessage = 'Recogidas reservadas actualizadas.';
    }, syncingValue: !silent);
  }

  Future<void> refreshEffective({bool silent = false}) async {
    await _guarded(() async {
      if (offline) {
        efectivas = await localRepository.cachedEffectivePickups();
        statusMessage = 'Recogidas efectivas cargadas desde BD local.';
        return;
      }
      final remote = await remoteRepository.fetchEffective(
        config: apiConfig,
        appInformation: appInformation,
      );
      await localRepository.cacheEffectivePickups(remote, online: true);
      efectivas = await localRepository.cachedEffectivePickups();
      statusMessage = 'Recogidas efectivas actualizadas.';
    }, syncingValue: !silent);
  }

  Future<void> assignAvailable(RecogidaItem pickup) async {
    await _guarded(() async {
      await remoteRepository.assignPickup(
        config: apiConfig,
        appInformation: appInformation,
        pickup: pickup,
      );
      disponibles = disponibles.where((item) => item.id != pickup.id).toList();
      await localRepository.markReserved(pickup);
      reservadas = await localRepository.fixedPickups();
      statusMessage = 'La recogida se ha asignado.';
      selectedTab = RecogerTab.reservadas;
    }, syncingValue: true);
  }

  Future<void> openPreguides(RecogidaItem pickup) async {
    await _guarded(() async {
      selectedPickup = pickup;
      showPreenvios = true;
      lastBillingResult = null;
      preenvios = await localRepository.cachedPreguides(pickup.id);
      notifyListeners();
      if (!offline) {
        final remote = await remoteRepository.fetchPreguides(
          config: apiConfig,
          appInformation: appInformation,
          pickupId: pickup.id,
        );
        await localRepository.cachePreguides(pickup.id, remote);
        preenvios = remote;
      }
      statusMessage = 'Preenvios de la recogida cargados.';
    }, syncingValue: true);
  }

  void closePreguides() {
    showPreenvios = false;
    selectedPickup = null;
    preenvios = const [];
    notifyListeners();
  }

  Future<void> searchPreguide(String value) async {
    final guide = value.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (guide.isEmpty) return;
    await _guarded(() async {
      final local = preenvios.where((item) {
        return item.guideNumber.contains(guide) || item.id == guide;
      }).toList();
      if (local.isNotEmpty) {
        preenvios = [...local, ...preenvios.where((item) => !local.contains(item))];
        statusMessage = 'Preenvio encontrado en la recogida.';
        return;
      }
      if (offline) {
        throw const RecogidaException('Sin conexion para buscar el preenvio.');
      }
      final found = await remoteRepository.searchPreguide(
        config: apiConfig,
        appInformation: appInformation,
        preguideNumber: guide,
      );
      if (found == null) {
        throw const RecogidaException('No se encontro el preenvio.');
      }
      preenvios = [found, ...preenvios];
      final pickup = selectedPickup;
      if (pickup != null) {
        await localRepository.cachePreguides(pickup.id, preenvios);
      }
      statusMessage = 'Preenvio encontrado.';
    }, syncingValue: true);
  }

  Future<void> executeBilling() async {
    final pickup = selectedPickup;
    if (pickup == null) return;
    await _guarded(() async {
      if (preenvios.isEmpty) {
        throw const RecogidaException('No hay preenvios para facturar.');
      }
      final preInvoiceId = _preInvoiceId(preenvios);
      lastBillingResult = await remoteRepository.executePickup(
        config: apiConfig,
        appInformation: appInformation,
        preguides: preenvios,
        pickupId: pickup.id,
        preInvoiceId: preInvoiceId,
      );
      statusMessage = lastBillingResult?.message ??
          'La recogida fue cerrada de forma exitosa.';
      await refreshEffective(silent: true);
    }, syncingValue: true);
  }

  int _preInvoiceId(List<RecogidaPreenvio> source) {
    for (final preguide in source) {
      final value = _deepInt(preguide.raw, const [
        'idPreFactura',
        'IdPreFactura',
        'numeroPreFactura',
        'NumeroPreFactura',
      ]);
      if (value > 0) return value;
    }
    return 0;
  }

  Future<void> _guarded(
    Future<void> Function() action, {
    bool loadingValue = false,
    bool syncingValue = false,
  }) async {
    loading = loadingValue;
    syncing = syncingValue;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      loading = false;
      syncing = false;
      notifyListeners();
    }
  }

  int _deepInt(Object? value, List<String> keys) {
    if (value is Map<String, dynamic>) {
      for (final key in keys) {
        final raw = value[key];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        final parsed = int.tryParse(raw?.toString().trim() ?? '');
        if (parsed != null) return parsed;
      }
      for (final child in value.values) {
        final found = _deepInt(child, keys);
        if (found > 0) return found;
      }
    } else if (value is Map) {
      return _deepInt(Map<String, dynamic>.from(value), keys);
    } else if (value is List) {
      for (final child in value) {
        final found = _deepInt(child, keys);
        if (found > 0) return found;
      }
    }
    return 0;
  }
}
