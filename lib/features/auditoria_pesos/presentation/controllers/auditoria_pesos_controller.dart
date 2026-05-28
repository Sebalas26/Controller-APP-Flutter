import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/native/controller_native_bridge.dart';
import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/auditoria_pesos_local_repository.dart';
import '../../data/auditoria_pesos_remote_repository.dart';
import '../../models/auditoria_pesos_models.dart';

class AuditoriaPesosController extends ChangeNotifier {
  AuditoriaPesosController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    AuditoriaPesosRemoteRepository? remoteRepository,
    AuditoriaPesosLocalRepository? localRepository,
    ControllerNativeBridge? nativeBridge,
  }) : remoteRepository = remoteRepository ?? AuditoriaPesosRemoteRepository(),
       localRepository = localRepository ?? AuditoriaPesosLocalRepository(),
       nativeBridge = nativeBridge ?? ControllerNativeBridge() {
    pesoBasculaController.addListener(_onWeightInputChanged);
    largoController.addListener(_onWeightInputChanged);
    anchoController.addListener(_onWeightInputChanged);
    altoController.addListener(_onWeightInputChanged);
  }

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final AuditoriaPesosRemoteRepository remoteRepository;
  final AuditoriaPesosLocalRepository localRepository;
  final ControllerNativeBridge nativeBridge;

  final guiaController = TextEditingController();
  final pesoBasculaController = TextEditingController();
  final largoController = TextEditingController();
  final anchoController = TextEditingController();
  final altoController = TextEditingController();
  final observacionesController = TextEditingController();

  AuditoriaPesosTab selectedTab = AuditoriaPesosTab.auditoria;
  AuditoriaWeightMode weightMode = AuditoriaWeightMode.bascula;
  AuditoriaGuide? guide;
  List<AuditoriaPhoto> photos = const [];
  AuditoriaReportSummary? reportSummary;
  List<AuditoriaReportDetail> reportDetails = const [];
  File? lastReportFile;
  String reportStartDate = '';
  String reportEndDate = '';
  int minVolumetricMeasure = 40;
  int volumetricWeight = 0;
  int differenceWeight = 0;
  bool loading = false;
  bool saving = false;
  bool takingPhoto = false;
  bool reportLoading = false;
  bool reportDownloading = false;
  String? errorMessage;
  String? statusMessage;

  bool get hasGuide => guide != null;
  bool get hasPhotos => photos.any((photo) => photo.hasImage);
  bool get canConsultReport =>
      reportStartDate.trim().isNotEmpty && reportEndDate.trim().isNotEmpty;

  int get newWeight {
    if (weightMode == AuditoriaWeightMode.volumetrico) return volumetricWeight;
    return int.tryParse(pesoBasculaController.text.trim()) ?? 0;
  }

  bool get canSave {
    final currentGuide = guide;
    if (currentGuide == null || saving || loading || takingPhoto) return false;
    if (photos.isEmpty || photos.any((photo) => !photo.hasImage)) return false;
    return _validateWeight(silent: true);
  }

  Future<void> initialize() async {
    minVolumetricMeasure = await localRepository.pesoMinimoVolumetrico();
    photos = _emptyPhotosForMode();
    notifyListeners();
  }

  void selectTab(AuditoriaPesosTab tab) {
    selectedTab = tab;
    _clearMessages();
    notifyListeners();
  }

  void guideInputChanged() {
    notifyListeners();
  }

  void setReportStartDate(DateTime date) {
    reportStartDate = auditoriaFormatDate(date);
    reportSummary = null;
    reportDetails = const [];
    lastReportFile = null;
    notifyListeners();
  }

  void setReportEndDate(DateTime date) {
    reportEndDate = auditoriaFormatDate(date);
    reportSummary = null;
    reportDetails = const [];
    lastReportFile = null;
    notifyListeners();
  }

  void setWeightMode(AuditoriaWeightMode mode) {
    if (weightMode == mode) return;
    weightMode = mode;
    _resetAuditEvidence(keepMode: true);
    photos = _emptyPhotosForMode();
    _recalculateWeight();
    notifyListeners();
  }

  Future<void> consultGuide() async {
    if (offline) {
      _setError('Sin conexión para consultar auditoría de pesos.');
      return;
    }
    var numeroGuia = _cleanGuide(guiaController.text);
    if (numeroGuia.isEmpty) {
      numeroGuia = _cleanGuide(await nativeBridge.scanQrCode());
      if (numeroGuia.isEmpty) return;
      guiaController.text = numeroGuia;
    }

    loading = true;
    _clearMessages();
    _resetAuditEvidence(keepMode: true);
    notifyListeners();
    try {
      final token = await remoteRepository.obtenerToken(apiConfig);
      guide = await remoteRepository.consultarGuia(
        config: apiConfig,
        appInformation: appInformation,
        token: token,
        numeroGuia: numeroGuia,
      );
      photos = _emptyPhotosForMode();
      statusMessage = 'Guía consultada correctamente.';
    } catch (error) {
      guide = null;
      photos = _emptyPhotosForMode();
      errorMessage = _messageFromError(
        error,
        fallback: 'No se pudo completar la consulta.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> captureMissingPhotos() async {
    final currentGuide = guide;
    if (currentGuide == null) {
      _setError('Consulta una guía antes de agregar fotos.');
      return;
    }
    for (var index = 0; index < photos.length; index++) {
      if (!photos[index].hasImage) {
        final captured = await takePhotoAt(index);
        if (!captured) break;
      }
    }
  }

  Future<bool> takePhotoAt(int index) async {
    final currentGuide = guide;
    if (currentGuide == null || index < 0 || index >= photos.length) {
      return false;
    }
    takingPhoto = true;
    _clearMessages();
    notifyListeners();
    try {
      final image = await nativeBridge.takePackagePhoto();
      if (image.trim().isEmpty) return false;
      final cleanBase64 = image.replaceAll(RegExp(r'\s'), '');
      final bytes = _base64Size(cleanBase64);
      final previous = photos[index];
      final updated = previous.copyWith(
        name: _photoName(currentGuide.numeroGuia, previous.title),
        size: bytes,
        type: 'jpg',
        base64File: cleanBase64,
        numeroGuia: currentGuide.numeroGuia,
      );
      photos = [
        for (var i = 0; i < photos.length; i++)
          i == index ? updated : photos[i],
      ];
      statusMessage = 'Foto ${previous.title.toLowerCase()} tomada.';
      return true;
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible tomar la foto.',
      );
      return false;
    } finally {
      takingPhoto = false;
      notifyListeners();
    }
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= photos.length) return;
    photos = [
      for (var i = 0; i < photos.length; i++)
        i == index ? photos[i].cleared() : photos[i],
    ];
    notifyListeners();
  }

  String? validationMessage() {
    if (guide == null) return 'Consulta una guía antes de guardar.';
    if (photos.any((photo) => !photo.hasImage)) {
      return 'Debes tomar todas las fotos requeridas.';
    }
    return _weightValidationMessage();
  }

  Future<void> saveAudit() async {
    final currentGuide = guide;
    if (offline) {
      _setError('Sin conexión para guardar la auditoría.');
      return;
    }
    final validation = validationMessage();
    if (currentGuide == null || validation != null) {
      _setError(validation ?? 'No se pudo validar la auditoría.');
      return;
    }

    saving = true;
    _clearMessages();
    notifyListeners();
    try {
      final photosToken = await remoteRepository.obtenerToken(apiConfig);
      await remoteRepository.guardarFotos(
        config: apiConfig,
        token: photosToken,
        fotos: photos,
      );
      final liquidationToken = await remoteRepository.obtenerToken(apiConfig);
      final result = await remoteRepository.guardarLiquidacion(
        config: apiConfig,
        appInformation: appInformation,
        token: liquidationToken,
        guia: currentGuide,
        pesoVolumetricoActivo: weightMode == AuditoriaWeightMode.volumetrico,
        observaciones: observacionesController.text.trim(),
        alto: int.tryParse(altoController.text.trim()) ?? 0,
        ancho: int.tryParse(anchoController.text.trim()) ?? 0,
        largo: int.tryParse(largoController.text.trim()) ?? 0,
        pesoBascula: int.tryParse(pesoBasculaController.text.trim()) ?? 0,
        diferenciaPesos: differenceWeight,
        pesoVolumetricoAproximado: volumetricWeight,
      );
      final message = result.message.trim();
      statusMessage = message.isEmpty
          ? 'Se guardó la guía satisfactoriamente.'
          : message;
      guiaController.clear();
      guide = null;
      _resetAuditEvidence(keepMode: false);
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'La guía no se pudo guardar.',
      );
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> consultReport() async {
    if (offline) {
      _setError('Sin conexión para consultar reportes.');
      return;
    }
    if (!canConsultReport) {
      _setError('Selecciona fecha inicial y fecha final.');
      return;
    }
    reportLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final token = await remoteRepository.obtenerToken(apiConfig);
      reportSummary = await remoteRepository.consultarReporte(
        config: apiConfig,
        appInformation: appInformation,
        token: token,
        fechaInicial: reportStartDate,
        fechaFinal: reportEndDate,
      );
      reportDetails = const [];
      lastReportFile = null;
      statusMessage = 'Información consultada correctamente.';
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Información no disponible.',
      );
    } finally {
      reportLoading = false;
      notifyListeners();
    }
  }

  Future<void> downloadDetailedReport() async {
    if (offline) {
      _setError('Sin conexión para descargar el informe.');
      return;
    }
    if (!canConsultReport) {
      _setError('Selecciona fecha inicial y fecha final.');
      return;
    }
    reportDownloading = true;
    _clearMessages();
    notifyListeners();
    try {
      final token = await remoteRepository.obtenerToken(apiConfig);
      final detail = await remoteRepository.consultarReporteDetallado(
        config: apiConfig,
        appInformation: appInformation,
        token: token,
        fechaInicial: reportStartDate,
        fechaFinal: reportEndDate,
      );
      if (detail.isEmpty) {
        throw const AuditoriaPesosException('Sin datos para el informe.');
      }
      reportDetails = detail;
      lastReportFile = await localRepository.guardarReporteDetallado(
        resumen: reportSummary,
        detalle: detail,
        fechaInicial: reportStartDate,
        fechaFinal: reportEndDate,
      );
      statusMessage = 'Descarga exitosa: ${lastReportFile!.path}';
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Información no disponible.',
      );
    } finally {
      reportDownloading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _clearMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    guiaController.dispose();
    pesoBasculaController.dispose();
    largoController.dispose();
    anchoController.dispose();
    altoController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

  void _onWeightInputChanged() {
    _recalculateWeight();
    notifyListeners();
  }

  void _recalculateWeight() {
    final currentGuide = guide;
    if (currentGuide == null) {
      volumetricWeight = 0;
      differenceWeight = 0;
      return;
    }
    if (weightMode == AuditoriaWeightMode.volumetrico) {
      final largo = int.tryParse(largoController.text.trim()) ?? 0;
      final ancho = int.tryParse(anchoController.text.trim()) ?? 0;
      final alto = int.tryParse(altoController.text.trim()) ?? 0;
      if (largo > 0 && ancho > 0 && alto > 0) {
        volumetricWeight = math.max(1, ((largo * ancho * alto) / 6000).ceil());
      } else {
        volumetricWeight = 0;
      }
    }
    final weight = newWeight;
    differenceWeight = weight - currentGuide.pesoAuditableSistema.toInt();
  }

  bool _validateWeight({required bool silent}) {
    final message = _weightValidationMessage();
    if (message == null) return true;
    if (!silent) _setError(message);
    return false;
  }

  String? _weightValidationMessage() {
    final currentGuide = guide;
    if (currentGuide == null) return 'Consulta una guía antes de guardar.';
    final weight = newWeight;
    if (weight <= 0) return 'Ingresa el nuevo peso.';
    if (weight <= currentGuide.pesoAuditableSistema.toInt()) {
      return 'El peso registrado no aplica para auditoría.';
    }
    if (currentGuide.idServicio == 6 && weight <= 30) {
      return 'El peso registrado no aplica para auditoría.';
    }
    if (weightMode == AuditoriaWeightMode.volumetrico) {
      final largo = int.tryParse(largoController.text.trim()) ?? 0;
      final ancho = int.tryParse(anchoController.text.trim()) ?? 0;
      final alto = int.tryParse(altoController.text.trim()) ?? 0;
      if (largo <= 0 || ancho <= 0 || alto <= 0) {
        return 'Falta diligenciar las medidas.';
      }
      if (largo <= minVolumetricMeasure &&
          ancho <= minVolumetricMeasure &&
          alto <= minVolumetricMeasure) {
        return 'Los valores registrados no aplican para peso volumétrico.';
      }
    }
    return null;
  }

  List<AuditoriaPhoto> _emptyPhotosForMode() {
    final titles = weightMode == AuditoriaWeightMode.volumetrico
        ? const ['Envio', 'Largo', 'Ancho', 'Alto']
        : const ['Envio', 'Bascula'];
    return [
      for (var i = 0; i < titles.length; i++)
        AuditoriaPhoto(title: titles[i], position: i),
    ];
  }

  void _resetAuditEvidence({required bool keepMode}) {
    pesoBasculaController.clear();
    largoController.clear();
    anchoController.clear();
    altoController.clear();
    observacionesController.clear();
    volumetricWeight = 0;
    differenceWeight = 0;
    if (!keepMode) weightMode = AuditoriaWeightMode.bascula;
    photos = _emptyPhotosForMode();
  }

  String _photoName(String guideNumber, String title) {
    return '${guideNumber}_${title.toLowerCase()}';
  }

  String _cleanGuide(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  int _base64Size(String value) {
    try {
      return base64Decode(value).length;
    } on Object {
      return value.length;
    }
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
    if (error is AuditoriaPesosException) return error.message;
    return fallback;
  }
}
