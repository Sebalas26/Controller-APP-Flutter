import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../entregas/entregas.dart';
import '../../../login/login.dart';
import '../../data/multientrega_local_repository.dart';
import '../../data/multientrega_remote_repository.dart';
import '../../models/multientrega_models.dart';

class MultientregaController extends ChangeNotifier {
  MultientregaController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    MultientregaLocalRepository? localRepository,
    MultientregaRemoteRepository? remoteRepository,
  }) : localRepository = localRepository ?? MultientregaLocalRepository(),
       remoteRepository = remoteRepository ?? MultientregaRemoteRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final MultientregaLocalRepository localRepository;
  final MultientregaRemoteRepository remoteRepository;

  final guideController = TextEditingController();
  final receiverController = TextEditingController();
  final documentController = TextEditingController();
  final observationsController = TextEditingController();

  List<MultientregaGuide> guides = const [];
  bool loading = false;
  bool saving = false;
  bool sealEnabled = false;
  int maxGuides = 50;
  String signatureBase64 = '';
  String sealBase64 = '';
  String? errorMessage;
  String? statusMessage;

  bool get canAddGuide => !loading && !saving && guides.length < maxGuides;
  bool get hasIncompletePhoto => guides.any((guide) => !guide.hasPhoto);
  bool get requiresSeal => guides.any((guide) => guide.requiresSeal);
  bool get canGoToSignature => guides.length > 1 && !hasIncompletePhoto;
  bool get canSave {
    if (saving || guides.length <= 1 || hasIncompletePhoto) return false;
    if (receiverController.text.trim().isEmpty) return false;
    if (documentController.text.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
      return false;
    }
    if (signatureBase64.trim().isEmpty) return false;
    if ((requiresSeal || sealEnabled) && sealBase64.trim().isEmpty) {
      return false;
    }
    return true;
  }

  int get totalToCollect {
    return guides.fold<int>(0, (sum, guide) => sum + guide.valueToCollect);
  }

  Future<void> initialize() async {
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      await localRepository.ensureSchema();
      maxGuides = await localRepository.maxGuides();
      await _loadPending();
      sealEnabled = requiresSeal;
      statusMessage = guides.isEmpty
          ? 'Agrega guías para iniciar la multientrega.'
          : 'Guías de multientrega cargadas.';
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible cargar multientrega.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addGuide([String? value]) async {
    final guideNumber = _cleanGuide(value ?? guideController.text);
    if (guideNumber.isEmpty) {
      throw const MultientregaException('Digite o escanee una guía.');
    }
    if (hasIncompletePhoto) {
      throw const MultientregaException(
        'Tome la foto del envío para agregar otra guía',
      );
    }
    if (guides.length >= maxGuides) {
      throw const MultientregaException(
        'No es posible agregar más guías al listado, descargue la cantidad agregada y continúe con una nueva agrupación',
      );
    }
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      if (await localRepository.isAlreadyInProcess(guideNumber)) {
        throw const MultientregaException(
          'La guía ya se encuentra en el listado.',
        );
      }
      if (await localRepository.isAlreadyDownloaded(guideNumber)) {
        throw const MultientregaException(
          'La guía ya fue descargada de forma offline, esta pendiente por sincronización.',
        );
      }
      var guide = await localRepository.findGuide(guideNumber);
      if (guide == null && !offline) {
        guide = await remoteRepository.searchGuide(
          config: apiConfig,
          appInformation: appInformation,
          guideNumber: guideNumber,
        );
      }
      if (guide == null || !guide.isPendingDelivery) {
        throw const MultientregaException(
          'La guía no se encuentra asignada o su estado no está habilitado.',
        );
      }
      if (!_allowsMultientrega(guide)) {
        throw MultientregaException(
          'Esta guía con servicio ${guide.serviceName} no es permitida entregarla de manera múltiple',
        );
      }
      final item = MultientregaGuide(
        guide: guide,
        photoBase64: '',
        requiresSeal: _requiresSeal(guide),
        createdAt: DateTime.now(),
      );
      await localRepository.saveGuide(item);
      guideController.clear();
      await _loadPending();
      sealEnabled = requiresSeal;
      statusMessage = 'Guía $guideNumber agregada. Toma la foto del envío.';
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Falla en la consulta, intente de nuevo.',
      );
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updatePhoto(String guideNumber, String photoBase64) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty || photoBase64.trim().isEmpty) return;
    _clearMessages();
    await localRepository.updateGuidePhoto(guide, photoBase64);
    await _loadPending();
    statusMessage = 'Foto del envío registrada.';
    notifyListeners();
  }

  Future<void> deleteGuide(String guideNumber) async {
    _clearMessages();
    await localRepository.deleteGuide(guideNumber);
    await _loadPending();
    if (guides.isEmpty) {
      signatureBase64 = '';
      sealBase64 = '';
      sealEnabled = false;
    }
    statusMessage = 'Guía eliminada del listado.';
    notifyListeners();
  }

  Future<void> clearGuides() async {
    _clearMessages();
    await localRepository.clearPending();
    guides = const [];
    signatureBase64 = '';
    sealBase64 = '';
    sealEnabled = false;
    statusMessage = 'Listado de multientrega eliminado.';
    notifyListeners();
  }

  void setSealEnabled(bool value) {
    sealEnabled = requiresSeal || value;
    if (!sealEnabled) sealBase64 = '';
    _clearMessages();
    notifyListeners();
  }

  void setSignature(String value) {
    signatureBase64 = _cleanBase64(value);
    _clearMessages();
    notifyListeners();
  }

  void setSeal(String value) {
    sealBase64 = _cleanBase64(value);
    _clearMessages();
    notifyListeners();
  }

  void clearSignature() {
    signatureBase64 = '';
    _clearMessages();
    notifyListeners();
  }

  void clearSeal() {
    sealBase64 = '';
    _clearMessages();
    notifyListeners();
  }

  Future<void> saveMultientrega() async {
    if (saving) return;
    final receiver = MultientregaReceiverData(
      name: receiverController.text.trim(),
      document: documentController.text.trim(),
      observations: observationsController.text.trim(),
    );
    _validateFinal(receiver);
    saving = true;
    _clearMessages();
    notifyListeners();
    final guideNumbers = guides.map((item) => item.guideNumber).toList();
    try {
      final signatureId = await localRepository.activeSignatureId();
      await localRepository.saveSignatureData(
        signatureId: signatureId,
        receiver: receiver,
        signatureBase64: signatureBase64,
        sealBase64: sealBase64,
      );

      final savedDownloads = <EntregaPendingDownload>[];
      for (final item in guides) {
        final download = await localRepository.savePendingDownload(
          guide: item.guide,
          payload: _buildDownloadPayload(
            item: item,
            receiver: receiver,
            signatureId: signatureId,
          ),
          isQr: false,
        );
        savedDownloads.add(download);
      }

      var synced = 0;
      if (!offline) {
        for (final download in savedDownloads) {
          try {
            final result = await remoteRepository.synchronizeDownload(
              config: apiConfig,
              appInformation: appInformation,
              download: download,
            );
            await localRepository.markDownloadSynced(download, result);
            synced++;
          } catch (error) {
            await localRepository.markDownloadFailed(download, error);
          }
        }
      }

      await localRepository.markGuidesFinalized(guideNumbers);
      await _loadPending();
      statusMessage = offline
          ? 'La descarga se ha generado satisfactoriamente por entrega múltiple.'
          : 'Descarga generada por entrega múltiple. Sincronizadas $synced de ${savedDownloads.length}.';
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible guardar la multientrega.',
      );
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _loadPending() async {
    guides = await localRepository.loadPendingGuides();
  }

  void _validateFinal(MultientregaReceiverData receiver) {
    if (guides.length <= 1) {
      throw const MultientregaException(
        'Agrega al menos dos guías para continuar con firma y sello.',
      );
    }
    if (hasIncompletePhoto) {
      throw const MultientregaException(
        'Tome la foto de cada envío para continuar.',
      );
    }
    if (receiver.name.trim().isEmpty) {
      throw const MultientregaException(
        'Ingresa quien recibe (nombre y apellido).',
      );
    }
    if (receiver.numericDocument.isEmpty) {
      throw const MultientregaException('Ingresa el número de documento.');
    }
    if (receiver.numericDocument.startsWith('0')) {
      throw const MultientregaException(
        'La identificación no puede iniciar en cero.',
      );
    }
    if (signatureBase64.trim().isEmpty) {
      throw const MultientregaException('Registra la firma del cliente.');
    }
    if ((requiresSeal || sealEnabled) && sealBase64.trim().isEmpty) {
      throw const MultientregaException('Toma la foto del sello.');
    }
  }

  Map<String, dynamic> _buildDownloadPayload({
    required MultientregaGuide item,
    required MultientregaReceiverData receiver,
    required int signatureId,
  }) {
    final guide = item.guide;
    final now = _formatControllerDate(DateTime.now());
    final guideNumber = int.tryParse(guide.guideNumber) ?? 0;
    final document = int.tryParse(receiver.numericDocument) ?? 0;
    final evidences = <Map<String, dynamic>>[
      {
        'Imagenes': [item.photoBase64],
        'NombreEvidenciaControllerApp': 'Entrega multientrega',
        'TipoEvidenciaControllerApp': 1,
      },
    ];
    if (sealBase64.trim().isNotEmpty) {
      evidences.add({
        'Imagenes': [sealBase64],
        'NombreEvidenciaControllerApp': 'Sello multientrega',
        'TipoEvidenciaControllerApp': 2,
      });
    }
    return _withoutNullValues({
      'EsAuditor': 0,
      'EsMaestra': 0,
      'EsOffline': 0,
      'EsPagoQR': 'false',
      'EsSello': (requiresSeal || sealEnabled).toString(),
      'FechaAsignacion': guide.assignmentDate,
      'FechaEntrega': guide.auditDate.trim().isNotEmpty ? guide.auditDate : now,
      'FechaGrabacion': now,
      'FirmaVirtual': {
        'Documento': receiver.numericDocument,
        'Firma': signatureBase64,
        'IdTipoFirma': 1,
        'Nombre': receiver.name,
        'NumeroGuia': guideNumber,
        'Observaciones': receiver.observations,
      },
      'IdCiudad': appInformation.idCiudad,
      'IdEstado': 0,
      'IdFirmaMultientrega': signatureId,
      'IdMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
      'IdPlanilla': guide.planSheet,
      'IdServicio': guide.serviceId,
      'IdSistema': 9,
      'IdTransaccion': 0,
      'IdentificacionQuienRecibe': document,
      'Latitud': guide.latitude,
      'Longitud': guide.longitude,
      'NombreCiudad': appInformation.nombreCiudad.trim().isNotEmpty
          ? appInformation.nombreCiudad
          : guide.city,
      'NombreQuienRecibe': receiver.name,
      'NumeroGuia': guideNumber,
      'NumeroIntentoFallidoEntrega': guide.deliveryAttempt,
      'RecibidoGuia': {
        'EstadoRegistro': 'ADICIONADO',
        'IdAplicacionOrigen': 'PAM',
        'Identificacion': receiver.numericDocument,
        'NumeroGuia': guideNumber,
        'Otros': receiver.observations,
        'RecibidoPor': receiver.name,
        'Telefono': guide.phone,
      },
      'TieneIntentoEntrega': false,
      'TipoContador': 0,
      'TipoEvidencia': evidences,
      'TipoNovedad': 0,
      'TipoPredio': guide.housingTypeId,
      'Observaciones': receiver.observations,
      'EntregaSinAsignacion': false,
      'IdTipoMensajero': int.tryParse(appInformation.idTipoMensajero) ?? 0,
      'NombreCompletoMensajero': appInformation.nombreMensajero,
      'Usuario': appInformation.nombreMensajero,
      'DescargueFueraDeRango': guide.raw['DescargueFueraDeRango'] ?? false,
      'UnidadHabitacional': guide.housingTypeId,
      'EsMultientrega': true,
    });
  }

  bool _allowsMultientrega(EntregaGuide guide) {
    final cambios = _asMap(guide.raw['Cambios'] ?? guide.raw['cambios']);
    if (cambios == null) return true;
    final direct = _findBool(cambios, 'PermiteMultientrega');
    if (direct != null) return direct;
    for (final value in cambios.values) {
      final nested = _asMap(value);
      if (nested == null) continue;
      final nestedValue = _findBool(nested, 'PermiteMultientrega');
      if (nestedValue == false) return false;
    }
    return true;
  }

  bool _requiresSeal(EntregaGuide guide) {
    final direct =
        _findBool(guide.raw, 'RequiereSelloMulti') ??
        _findBool(guide.raw, 'requiereSelloMulti') ??
        _findBool(guide.raw, 'EsSello');
    if (direct != null) return direct;
    final service = _asMap(guide.raw['Servicio'] ?? guide.raw['servicio']);
    if (service == null) return false;
    return _findBool(service, 'RequiereSelloMulti') ??
        _findBool(service, 'requiereSelloMulti') ??
        false;
  }

  bool? _findBool(Map<String, dynamic> json, String key) {
    final target = key.toLowerCase();
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() != target) continue;
      final value = entry.value;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text.isEmpty) return null;
      return text == 'true' || text == '1' || text == 'si';
    }
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on Object {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> _withoutNullValues(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Map<String, dynamic>) {
        result[entry.key] = _withoutNullValues(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  String _formatControllerDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-'
        '${two(date.month)}-${two(date.day)}T'
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  String _cleanGuide(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  String _cleanBase64(String value) {
    return value
        .split('base64,')
        .last
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  String _messageFromError(Object error, {required String fallback}) {
    if (error is MultientregaException) return error.message;
    if (error is EntregaException) return error.message;
    final text = error.toString().trim();
    if (text.isNotEmpty && text != 'Exception') return text;
    return fallback;
  }

  void _clearMessages() {
    errorMessage = null;
    statusMessage = null;
  }

  @override
  void dispose() {
    guideController.dispose();
    receiverController.dispose();
    documentController.dispose();
    observationsController.dispose();
    super.dispose();
  }
}
