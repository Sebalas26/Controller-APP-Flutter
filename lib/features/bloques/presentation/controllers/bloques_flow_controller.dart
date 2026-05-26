import 'package:flutter/foundation.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/bloques_local_repository.dart';
import '../../data/bloques_remote_repository.dart';
import '../../models/bloques_models.dart';

class BloquesFlowController extends ChangeNotifier {
  BloquesFlowController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    BloquesLocalRepository? localRepository,
    BloquesRemoteRepository? remoteRepository,
  }) : localRepository = localRepository ?? BloquesLocalRepository(),
       remoteRepository = remoteRepository ?? BloquesRemoteRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final BloquesLocalRepository localRepository;
  final BloquesRemoteRepository remoteRepository;

  bool loading = false;
  bool busyRemote = false;
  String statusMessage = '';
  String? errorMessage;
  YaapCourier? courier;
  YaapRouteState? routeState;
  List<YaapDelivery> deliveries = const [];
  List<YaapPendingBlock> pendingBlocks = const [];

  Future<void> initialize() async {
    loading = true;
    errorMessage = null;
    statusMessage = 'Cargando datos de bloques.';
    notifyListeners();
    try {
      await localRepository.ensureSchema();
      courier = await localRepository.loadCourier();
      deliveries = await localRepository.loadDeliveries();
      pendingBlocks = await localRepository.loadPendingBlocks();
      if (!offline) {
        await refreshPendingBlocks(silent: true);
      }
      statusMessage = 'Bloques listos.';
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<YaapQrIdentity> identityFromQr(String qrCodeData) {
    return remoteRepository.identityFromQr(qrCodeData);
  }

  Future<void> identifyCourier(String document, String otp) async {
    final cleanDocument = document.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final cleanOtp = otp.trim();
    if (cleanDocument.isEmpty || cleanOtp.isEmpty) {
      throw const YaapException('Ingresa documento y codigo OTP.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Validando mensajero.',
      action: () async {
        courier = await remoteRepository.identifyCourier(
          config: apiConfig,
          appInformation: appInformation,
          document: cleanDocument,
          otp: cleanOtp,
        );
        await localRepository.saveCourier(courier!);
        await refreshDeliveries(silent: true);
        final routeId = courier?.routeId ?? '';
        if (routeId.isNotEmpty) {
          routeState = await remoteRepository.validateRouteState(
            config: apiConfig,
            appInformation: appInformation,
            routeId: routeId,
          );
        }
        statusMessage = 'Mensajero validado.';
      },
    );
  }

  Future<void> refreshDeliveries({bool silent = false}) async {
    final current = courier;
    if (current == null) {
      throw const YaapException('Primero valida un mensajero.');
    }
    _ensureOnline();
    await _runRemote(
      silent: silent,
      startMessage: 'Consultando entregas.',
      action: () async {
        deliveries = await remoteRepository.fetchDeliveries(
          config: apiConfig,
          appInformation: appInformation,
          guideNumbers: current.guideNumbers,
        );
        await localRepository.saveDeliveries(deliveries);
        statusMessage = 'Entregas actualizadas: ${deliveries.length}.';
      },
    );
  }

  Future<void> assignCurrentSheet() async {
    final current = courier;
    if (current == null) {
      throw const YaapException('Primero valida un mensajero.');
    }
    if (current.guideNumbers.isEmpty) {
      throw const YaapException('El mensajero no tiene guias para asignar.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Asignando planilla.',
      action: () async {
        final assigned = await remoteRepository.assignSheet(
          config: apiConfig,
          appInformation: appInformation,
          courier: current,
        );
        if (!assigned) {
          throw const YaapException('No fue posible asignar la planilla.');
        }
        statusMessage = 'Planilla asignada.';
      },
    );
  }

  Future<void> refreshPendingBlocks({bool silent = false}) async {
    _ensureOnline();
    await _runRemote(
      silent: silent,
      startMessage: 'Consultando bloques pendientes.',
      action: () async {
        pendingBlocks = await remoteRepository.fetchPendingBlocks(
          config: apiConfig,
          appInformation: appInformation,
        );
        await localRepository.savePendingBlocks(pendingBlocks);
        statusMessage = 'Bloques pendientes: ${pendingBlocks.length}.';
      },
    );
  }

  Future<void> assignBlock(YaapPendingBlock block) async {
    _ensureOnline();
    await _runRemote(
      startMessage: 'Asignando gestion de bloque.',
      action: () async {
        final assigned = await remoteRepository.assignBlock(
          config: apiConfig,
          appInformation: appInformation,
          block: block,
        );
        if (!assigned) {
          throw const YaapException('No fue posible asignar el bloque.');
        }
        statusMessage = 'Bloque ${block.motherGuideNumber} asignado.';
        await refreshPendingBlocks(silent: true);
      },
    );
  }

  Future<void> validateBlockManagement(YaapPendingBlock block) async {
    _ensureOnline();
    await _runRemote(
      startMessage: 'Validando gestion del bloque.',
      action: () async {
        final valid = await remoteRepository.validateBlockManagement(
          config: apiConfig,
          appInformation: appInformation,
          block: block,
        );
        if (!valid) {
          throw YaapException(
            'El bloque ${block.motherGuideNumber} no esta disponible.',
          );
        }
        statusMessage = 'Bloque ${block.motherGuideNumber} disponible.';
      },
    );
  }

  void openPendingBlock(YaapPendingBlock block) {
    final guides =
        block.guideNumbers.isEmpty && block.motherGuideNumber.isNotEmpty
        ? [block.motherGuideNumber]
        : block.guideNumbers;
    courier = YaapCourier(
      raw: block.raw,
      document: block.courierDocument,
      name: block.courierName,
      photoUrl: block.photoUrl,
      routeId: '',
      guideNumbers: guides,
      otp: '',
    );
    deliveries = guides
        .map(
          (guide) => YaapDelivery(
            raw: {'NumeroGuia': guide, 'Bloque': block.motherGuideNumber},
            guideNumber: guide,
            location: 0,
            locationType: 0,
            locationDetail: block.courierName.isEmpty
                ? 'Bloque ${block.motherGuideNumber}'
                : block.courierName,
            description: 'Bloque ${block.motherGuideNumber}',
            weight: 0,
            admissionId: 0,
            stateId: 0,
          ),
        )
        .toList(growable: false);
    statusMessage = 'Bloque ${block.motherGuideNumber} listo para gestionar.';
    notifyListeners();
  }

  void markDeliveryVerified(String guideNumber) {
    deliveries = deliveries
        .map(
          (delivery) => delivery.guideNumber == guideNumber
              ? delivery.copyWith(verified: !delivery.verified)
              : delivery,
        )
        .toList(growable: false);
    notifyListeners();
  }

  void _ensureOnline() {
    if (offline) {
      throw const YaapException('Este flujo requiere conexion.');
    }
  }

  Future<void> _runRemote({
    required String startMessage,
    required Future<void> Function() action,
    bool silent = false,
  }) async {
    if (!silent) {
      busyRemote = true;
      errorMessage = null;
      statusMessage = startMessage;
      notifyListeners();
    }
    try {
      await action();
    } on Object catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      if (!silent) busyRemote = false;
      notifyListeners();
    }
  }
}
