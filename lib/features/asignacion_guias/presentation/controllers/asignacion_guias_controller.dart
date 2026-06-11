import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/native/controller_native_bridge.dart';
import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/asignacion_guias_local_repository.dart';
import '../../data/asignacion_guias_remote_repository.dart';
import '../../models/asignacion_guias_models.dart';

class AsignacionGuiasController extends ChangeNotifier {
  AsignacionGuiasController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    AsignacionGuiasRemoteRepository? remoteRepository,
    AsignacionGuiasLocalRepository? localRepository,
    ControllerNativeBridge? nativeBridge,
  }) : remoteRepository = remoteRepository ?? AsignacionGuiasRemoteRepository(),
       localRepository = localRepository ?? AsignacionGuiasLocalRepository(),
       nativeBridge = nativeBridge ?? ControllerNativeBridge();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final AsignacionGuiasRemoteRepository remoteRepository;
  final AsignacionGuiasLocalRepository localRepository;
  final ControllerNativeBridge nativeBridge;

  final messengerController = TextEditingController();
  final guideController = TextEditingController();

  List<AsignacionMessenger> messengers = const [];
  List<AsignacionGuideState> pendingGuides = const [];
  List<AssignedSheet> previousSheets = const [];
  AsignacionMessenger? selectedMessenger;

  bool loading = false;
  bool loadingMessengers = false;
  bool loadingPrevious = false;
  bool assigning = false;
  bool reassigningPrevious = false;
  int maxGuides = 20;
  String? errorMessage;
  String? statusMessage;

  List<AsignacionMessenger> get filteredMessengers {
    final query = messengerController.text.trim().toLowerCase();
    if (query.isEmpty) return messengers;
    return messengers
        .where((item) => item.nombre.toLowerCase().contains(query))
        .toList(growable: false);
  }

  int get totalPreviousGuides =>
      previousSheets.fold(0, (total, sheet) => total + sheet.guias.length);

  bool get canAssign =>
      !offline &&
      !assigning &&
      selectedMessenger != null &&
      pendingGuides.isNotEmpty;

  Future<void> initialize() async {
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      await localRepository.ensureSchema();
      maxGuides = await localRepository.maxGuiasAsignar();
      pendingGuides = await localRepository.loadPendingGuides();
      await _loadMessengers();
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible iniciar asignación de guías.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void messengerTextChanged() {
    if (selectedMessenger != null &&
        messengerController.text.trim() != selectedMessenger!.nombre.trim()) {
      selectedMessenger = null;
    }
    _clearMessages();
    notifyListeners();
  }

  void selectMessenger(AsignacionMessenger messenger) {
    selectedMessenger = messenger;
    messengerController.text = messenger.nombre;
    _clearMessages();
    notifyListeners();
  }

  void clearMessenger() {
    selectedMessenger = null;
    messengerController.clear();
    guideController.clear();
    _clearMessages();
    notifyListeners();
  }

  Future<void> scanOrSearchGuide() async {
    final typedGuide = _cleanGuide(guideController.text);
    if (typedGuide.isNotEmpty) {
      await validateGuide(typedGuide);
      return;
    }
    final scanned = _cleanGuide(await nativeBridge.scanQrCode());
    if (scanned.isEmpty) return;
    guideController.text = scanned;
    await validateGuide(scanned);
  }

  Future<void> validateGuide(String value) async {
    final selected = selectedMessenger;
    if (selected == null) {
      _setError('Selecciona un apoyo antes de asignar guías.');
      return;
    }
    if (offline) {
      _setError('Sin conexión para consultar la guía.');
      return;
    }
    final guideNumber = _cleanGuide(value);
    if (guideNumber.isEmpty) {
      _setError('Número de guía inválido');
      return;
    }
    if (_existsPendingGuide(guideNumber)) {
      _setError(
        'La guía que intentas escanear ya ha sido asignada o escaneada previamente.',
      );
      return;
    }
    if (pendingGuides.length >= maxGuides) {
      _setError(
        'Solo es posible asignar $maxGuides envíos por lote, asigne y genere un nuevo lote',
      );
      return;
    }

    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      final guide = await remoteRepository.getEstadoGuia(
        config: apiConfig,
        appInformation: appInformation,
        numeroGuia: guideNumber,
      );
      pendingGuides = [guide, ...pendingGuides];
      await localRepository.savePendingGuide(guide);
      guideController.clear();
      statusMessage = 'Guía agregada para asignación.';
    } catch (error) {
      errorMessage = _messageFromError(error, fallback: 'Falla consulta');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> deletePendingGuide(AsignacionGuideState guide) async {
    pendingGuides = pendingGuides
        .where((item) => item.numeroGuia != guide.numeroGuia)
        .toList(growable: false);
    await localRepository.deletePendingGuide(guide.numeroGuia);
    _clearMessages();
    notifyListeners();
  }

  Future<void> assignGuides() async {
    final selected = selectedMessenger;
    if (selected == null || pendingGuides.isEmpty) {
      _setError('Selecciona un apoyo y agrega al menos una guía.');
      return;
    }
    assigning = true;
    _clearMessages();
    notifyListeners();
    try {
      final result = await _reassignGuides(
        messenger: selected,
        guideNumbers: pendingGuides.map((item) => item.numeroGuia).toList(),
      );
      if (result.guiasSinAsignar.isEmpty) {
        pendingGuides = const [];
        await localRepository.clearPendingGuides();
        statusMessage = 'Creación completa';
      } else {
        final failed = pendingGuides
            .where((item) => result.guiasSinAsignar.contains(item.numeroGuia))
            .map((item) => item.copyWith(esReasignacionFallida: true))
            .toList(growable: false);
        pendingGuides = failed;
        await localRepository.replacePendingGuides(failed);
        errorMessage =
            'Se encontraron (${failed.length}) guías en un estado invalido. Por favor, elimínelas.';
      }
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Fallo el servicio, intenta de nuevo.',
      );
    } finally {
      assigning = false;
      notifyListeners();
    }
  }

  Future<void> loadPreviousGuides() async {
    final selected = selectedMessenger;
    if (selected == null) {
      _setError('Selecciona un apoyo para consultar guías anteriores.');
      return;
    }
    if (offline) {
      _setError('Sin conexión para consultar guías anteriores.');
      return;
    }
    loadingPrevious = true;
    _clearMessages();
    notifyListeners();
    try {
      final sheets = await remoteRepository.getHistoricoGuiasApoyo(
        config: apiConfig,
        appInformation: appInformation,
        idMensajero: selected.idMensajero,
      );
      previousSheets = sheets.planillas;
      await localRepository.savePreviousSheetsAndMessengers(
        sheets: sheets,
        messengers: messengers,
      );
      statusMessage = 'Guías anteriores consultadas.';
    } catch (error) {
      errorMessage = _messageFromError(error, fallback: 'Falla consulta');
    } finally {
      loadingPrevious = false;
      notifyListeners();
    }
  }

  Future<void> reassignGuideToParent({
    required int sheetIndex,
    required int guideIndex,
  }) async {
    if (!_validSheetGuideIndex(sheetIndex, guideIndex)) return;
    final guide = previousSheets[sheetIndex].guias[guideIndex];
    await _reassignPreviousGuides(
      guideNumbers: [guide.numeroGuia],
      target: _parentMessenger(),
      afterSuccess: (failed) {
        if (failed.isEmpty) {
          _removePreviousGuide(sheetIndex, guideIndex);
          statusMessage = 'Creación completa';
        } else {
          errorMessage =
              'Ninguna de las guías pudo ser desasignada debido a su estado actual.';
        }
      },
    );
  }

  Future<void> reassignSheetToParent(int sheetIndex) async {
    if (sheetIndex < 0 || sheetIndex >= previousSheets.length) return;
    final guideNumbers = previousSheets[sheetIndex].guias
        .map((item) => item.numeroGuia)
        .toList(growable: false);
    await _reassignPreviousGuides(
      guideNumbers: guideNumbers,
      target: _parentMessenger(),
      afterSuccess: (failed) {
        if (failed.isEmpty) {
          previousSheets = [...previousSheets]..removeAt(sheetIndex);
          statusMessage = 'Creación completa';
        } else {
          errorMessage =
              'De las guías seleccionadas ${failed.length} no pudieron ser desasignadas debido a su estado.';
          unawaited(loadPreviousGuides());
        }
      },
    );
  }

  Future<void> reassignPreviousPlanilladas(AsignacionMessenger target) async {
    final guides = previousSheets
        .expand((sheet) => sheet.guias)
        .where((guide) => guide.isPlanillada)
        .map((guide) => guide.numeroGuia)
        .toList(growable: false);
    if (guides.isEmpty) {
      _setError('No hay guías planilladas para reasignar.');
      return;
    }
    await _reassignPreviousGuides(
      guideNumbers: guides,
      target: target,
      afterSuccess: (failed) {
        if (failed.isEmpty) {
          previousSheets = const [];
          statusMessage = target.idMensajero == _parentMessenger().idMensajero
              ? 'Creación completa'
              : 'Envíos asignados correctamente a: ${target.nombre}';
        } else {
          _keepFailedPreviousGuides(failed);
          errorMessage =
              'Se encontraron (${failed.length}) guías en un estado invalido. Por favor, elimínelas.';
        }
      },
    );
  }

  Future<void> _loadMessengers() async {
    if (offline) return;
    loadingMessengers = true;
    notifyListeners();
    try {
      final tokens = await localRepository.loadAccessTokens();
      messengers = await remoteRepository.getMensajerosData(
        config: apiConfig,
        appInformation: appInformation,
        tokens: tokens,
      );
      if (messengers.isEmpty) {
        errorMessage =
            'No tienes apoyos para reasignar guías, dirígete al modulo de "Mis Apoyos" para crear uno.';
      }
    } catch (error) {
      errorMessage = _messageFromError(error, fallback: 'Falla consulta');
    } finally {
      loadingMessengers = false;
    }
  }

  Future<ReassignGuidesResult> _reassignGuides({
    required AsignacionMessenger messenger,
    required List<int> guideNumbers,
  }) async {
    final tokens = await localRepository.loadAccessTokens();
    final compressed = remoteRepository.compressReassignmentBody(
      idCiudad: appInformation.idCiudad,
      nombreCiudad: appInformation.nombreCiudad,
      idMensajero: messenger.idMensajero,
      idTipoMensajero: messenger.idTipoMensajero,
      nombreMensajero: messenger.nombre,
      listaGuias: guideNumbers,
    );
    return remoteRepository.reAsignarGuias(
      config: apiConfig,
      tokens: tokens,
      compressedRequest: compressed,
    );
  }

  Future<void> _reassignPreviousGuides({
    required List<int> guideNumbers,
    required AsignacionMessenger target,
    required void Function(List<int> failed) afterSuccess,
  }) async {
    if (offline) {
      _setError('Sin conexión para reasignar guías.');
      return;
    }
    reassigningPrevious = true;
    _clearMessages();
    notifyListeners();
    try {
      final result = await _reassignGuides(
        messenger: target,
        guideNumbers: guideNumbers,
      );
      afterSuccess(result.guiasSinAsignar);
      await localRepository.savePreviousSheetsAndMessengers(
        sheets: PreviousSheets(planillas: previousSheets),
        messengers: messengers,
      );
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Fallo el servicio, intenta de nuevo.',
      );
    } finally {
      reassigningPrevious = false;
      notifyListeners();
    }
  }

  void _removePreviousGuide(int sheetIndex, int guideIndex) {
    final updated = [...previousSheets];
    final sheet = updated[sheetIndex];
    final guides = [...sheet.guias]..removeAt(guideIndex);
    if (guides.isEmpty) {
      updated.removeAt(sheetIndex);
    } else {
      updated[sheetIndex] = sheet.copyWith(guias: guides);
    }
    previousSheets = updated;
  }

  void _keepFailedPreviousGuides(List<int> failedGuideNumbers) {
    previousSheets = previousSheets
        .map((sheet) {
          final failedGuides = sheet.guias
              .where((guide) => failedGuideNumbers.contains(guide.numeroGuia))
              .map((guide) => guide.copyWith(esReasignacionFallida: true))
              .toList(growable: false);
          return sheet.copyWith(guias: failedGuides);
        })
        .where((sheet) => sheet.guias.isNotEmpty)
        .toList(growable: false);
  }

  AsignacionMessenger _parentMessenger() {
    return AsignacionMessenger.parent(
      idMensajero: int.tryParse(appInformation.idMensajero) ?? 0,
      idTipoMensajero: int.tryParse(appInformation.idTipoMensajero) ?? 0,
      nombre: appInformation.nombreMensajero,
    );
  }

  bool _validSheetGuideIndex(int sheetIndex, int guideIndex) {
    return sheetIndex >= 0 &&
        sheetIndex < previousSheets.length &&
        guideIndex >= 0 &&
        guideIndex < previousSheets[sheetIndex].guias.length;
  }

  bool _existsPendingGuide(String guideNumber) {
    final number = int.tryParse(guideNumber);
    if (number == null) return false;
    return pendingGuides.any((item) => item.numeroGuia == number);
  }

  String _cleanGuide(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  void _setError(String message) {
    errorMessage = message;
    statusMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    errorMessage = null;
    statusMessage = null;
  }

  String _messageFromError(Object error, {required String fallback}) {
    if (error is AsignacionGuiasException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  void dispose() {
    messengerController.dispose();
    guideController.dispose();
    super.dispose();
  }
}
