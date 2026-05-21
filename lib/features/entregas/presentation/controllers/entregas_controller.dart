import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/entregas_local_repository.dart';
import '../../data/entregas_remote_repository.dart';
import '../../models/entregas_models.dart';

typedef EntregaImageCompressor =
    Future<String> Function(
      String imageBase64, {
      required int maxDimension,
      required int quality,
      required int maxBase64Length,
    });

class EntregasController extends ChangeNotifier {
  EntregasController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    EntregasLocalRepository? localRepository,
    EntregasRemoteRepository? remoteRepository,
    this.imageCompressor,
  }) : localRepository = localRepository ?? EntregasLocalRepository(),
       remoteRepository = remoteRepository ?? EntregasRemoteRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final EntregasLocalRepository localRepository;
  final EntregasRemoteRepository remoteRepository;
  final EntregaImageCompressor? imageCompressor;

  EntregaGuideStatus selectedStatus = EntregaGuideStatus.enZona;
  bool loading = false;
  bool syncing = false;
  String statusMessage = '';
  String? errorMessage;
  int pendingSyncCount = 0;

  List<EntregaGuide> inZone = const [];
  List<EntregaGuide> delivered = const [];
  List<EntregaGuide> returned = const [];
  List<EntregaReason> returnReasons = const [];
  EntregaGuide? searchedGuide;

  Future<void> initialize() async {
    loading = true;
    errorMessage = null;
    statusMessage = 'Cargando entregas locales.';
    notifyListeners();
    try {
      await localRepository.ensureSchema();
      await _loadLocal();
      if (!offline) {
        await refreshInZone(silent: true);
        await loadReturnReasons(silent: true);
      }
      statusMessage = 'Entregas listas.';
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrent() async {
    switch (selectedStatus) {
      case EntregaGuideStatus.enZona:
        await refreshInZone();
        break;
      case EntregaGuideStatus.entregada:
        await refreshDelivered();
        break;
      case EntregaGuideStatus.devolucion:
        await refreshReturned();
        break;
    }
  }

  void selectStatus(EntregaGuideStatus status) {
    selectedStatus = status;
    notifyListeners();
  }

  Future<void> refreshInZone({bool silent = false}) async {
    await _runRemote(
      silent: silent,
      startMessage: 'Consultando guias en zona.',
      action: () async {
        final guides = await remoteRepository.fetchInZone(
          config: apiConfig,
          appInformation: appInformation,
        );
        await localRepository.saveGuides(guides, EntregaGuideStatus.enZona);
        inZone = await localRepository.loadGuides(EntregaGuideStatus.enZona);
        statusMessage = 'Guias en zona actualizadas: ${inZone.length}.';
      },
    );
  }

  Future<void> refreshDelivered({bool silent = false}) async {
    await _runRemote(
      silent: silent,
      startMessage: 'Consultando entregadas.',
      action: () async {
        final local = await localRepository.loadGuides(
          EntregaGuideStatus.entregada,
        );
        final remote = await remoteRepository.fetchDelivered(
          config: apiConfig,
          appInformation: appInformation,
          guideNumbers: local.map((guide) => guide.guideNumber).toList(),
        );
        if (remote.isNotEmpty) {
          await localRepository.saveGuides(
            remote,
            EntregaGuideStatus.entregada,
          );
        }
        delivered = await localRepository.loadGuides(
          EntregaGuideStatus.entregada,
        );
        statusMessage = 'Entregadas actualizadas: ${delivered.length}.';
      },
    );
  }

  Future<void> refreshReturned({bool silent = false}) async {
    await _runRemote(
      silent: silent,
      startMessage: 'Consultando devoluciones.',
      action: () async {
        final local = await localRepository.loadGuides(
          EntregaGuideStatus.devolucion,
        );
        final remote = await remoteRepository.fetchReturned(
          config: apiConfig,
          appInformation: appInformation,
          guideNumbers: local.map((guide) => guide.guideNumber).toList(),
        );
        if (remote.isNotEmpty) {
          await localRepository.saveGuides(
            remote,
            EntregaGuideStatus.devolucion,
          );
        }
        returned = await localRepository.loadGuides(
          EntregaGuideStatus.devolucion,
        );
        statusMessage = 'Devoluciones actualizadas: ${returned.length}.';
      },
    );
  }

  Future<void> loadReturnReasons({bool silent = false}) async {
    if (!silent) {
      loading = true;
      errorMessage = null;
      statusMessage = 'Cargando motivos de devolucion.';
      notifyListeners();
    }
    try {
      final local = await localRepository.loadReasons();
      returnReasons = local;
      if (!offline) {
        final remote = await remoteRepository.fetchReturnReasons(
          config: apiConfig,
          appInformation: appInformation,
        );
        if (remote.isNotEmpty) {
          await localRepository.saveReasons(remote);
          returnReasons = remote;
        }
      }
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Future<void> searchGuide(String input) async {
    final guide = input.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (guide.isEmpty) {
      throw const EntregaException('Ingresa o escanea un numero de guia.');
    }
    loading = true;
    errorMessage = null;
    statusMessage = 'Consultando guia $guide.';
    notifyListeners();
    try {
      searchedGuide = await localRepository.findGuide(guide);
      if (searchedGuide == null && !offline) {
        searchedGuide = await remoteRepository.searchGuide(
          config: apiConfig,
          appInformation: appInformation,
          guideNumber: guide,
        );
        final found = searchedGuide;
        if (found != null) {
          await localRepository.saveGuides([found], EntregaGuideStatus.enZona);
          await _loadLocal();
        }
      }
      if (searchedGuide == null) {
        throw EntregaException('No se encontro la guia $guide.');
      }
      statusMessage = 'Guia $guide lista para gestionar.';
    } on Object catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> completeDelivery({
    required EntregaGuide guide,
    required EntregaRecipientData recipient,
    required String signatureBase64,
    required String photoBase64,
    required bool isQr,
  }) async {
    _validateDelivery(recipient, signatureBase64, photoBase64);
    await _saveAndSync(
      guide: guide,
      type: EntregaDownloadType.entregaCorrectaMensajero,
      payload: _buildDownloadPayload(
        guide: guide,
        recipient: recipient,
        signatureBase64: signatureBase64,
        photoBase64: photoBase64,
        reason: null,
        type: EntregaDownloadType.entregaCorrectaMensajero,
      ),
      isQr: isQr,
    );
  }

  Future<void> completeReturn({
    required EntregaGuide guide,
    required EntregaReason reason,
    required String observations,
    required bool isQr,
  }) async {
    if (reason.id == 0) {
      throw const EntregaException('Selecciona un motivo de devolucion.');
    }
    final recipient = EntregaRecipientData(
      name: guide.recipientName,
      document: appInformation.identificacionUsuario,
      phone: guide.phone,
      observations: observations,
      housingTypeId: guide.housingTypeId,
    );
    await _saveAndSync(
      guide: guide,
      type: EntregaDownloadType.devolucionMensajero,
      payload: _buildDownloadPayload(
        guide: guide,
        recipient: recipient,
        signatureBase64: '',
        photoBase64: '',
        reason: reason,
        type: EntregaDownloadType.devolucionMensajero,
      ),
      isQr: isQr,
    );
  }

  Future<void> syncPending() async {
    syncing = true;
    errorMessage = null;
    statusMessage = 'Sincronizando descargues pendientes.';
    notifyListeners();
    try {
      final pending = await localRepository.pendingDownloads();
      var synced = 0;
      for (final download in pending) {
        try {
          final compactDownload = await _compactPendingDownload(download);
          final result = await remoteRepository.synchronizeDownload(
            config: apiConfig,
            appInformation: appInformation,
            download: compactDownload,
          );
          await localRepository.markDownloadSynced(compactDownload, result);
          synced++;
        } on Object catch (error) {
          await localRepository.markDownloadFailed(download, error);
        }
      }
      await _loadLocal();
      statusMessage = synced == pending.length
          ? 'Descargues sincronizados.'
          : 'Sincronizacion parcial: $synced de ${pending.length}.';
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _saveAndSync({
    required EntregaGuide guide,
    required EntregaDownloadType type,
    required Map<String, dynamic> payload,
    required bool isQr,
  }) async {
    if (await localRepository.isGuideAlreadyDownloaded(guide.guideNumber)) {
      throw EntregaException('La guia ${guide.guideNumber} ya fue descargada.');
    }
    loading = true;
    errorMessage = null;
    statusMessage = 'Guardando descargue offline.';
    notifyListeners();
    try {
      await localRepository.savePendingDownload(
        guide: guide,
        type: type,
        payload: payload,
        isQr: isQr,
      );
      await _loadLocal();
      statusMessage = type == EntregaDownloadType.devolucionMensajero
          ? 'Devolucion guardada offline.'
          : 'Entrega guardada offline.';
    } finally {
      loading = false;
      notifyListeners();
    }
    if (!offline) await syncPending();
  }

  Future<EntregaPendingDownload> _compactPendingDownload(
    EntregaPendingDownload download,
  ) async {
    if (download.type != EntregaDownloadType.entregaCorrectaMensajero ||
        imageCompressor == null) {
      return download;
    }

    final payload = _deepCopyMap(download.payload);
    var changed = false;

    final signature = payload['FirmaVirtual'];
    if (signature is Map<String, dynamic>) {
      final currentSignature = _cleanBase64(
        signature['Firma']?.toString() ?? '',
      );
      if (currentSignature.isNotEmpty) {
        final compactSignature = await _compactImage(
          currentSignature,
          maxDimension: 420,
          quality: 35,
          maxBase64Length: 10 * 1024,
          label: 'firma',
        );
        if (compactSignature != currentSignature) {
          signature['Firma'] = compactSignature;
          changed = true;
        }
      }
    }

    final evidences = payload['TipoEvidencia'];
    if (evidences is List) {
      for (final evidence in evidences) {
        if (evidence is! Map<String, dynamic>) continue;
        final images = evidence['Imagenes'];
        if (images is! List) continue;
        for (var index = 0; index < images.length; index++) {
          final currentImage = _cleanBase64(images[index]?.toString() ?? '');
          if (currentImage.isEmpty) continue;
          final compactImage = await _compactImage(
            currentImage,
            maxDimension: 480,
            quality: 35,
            maxBase64Length: 45 * 1024,
            label: 'evidencia',
          );
          if (compactImage != currentImage) {
            images[index] = compactImage;
            changed = true;
          }
        }
      }
    }

    if (!changed) return download;
    return localRepository.updatePendingPayload(download, payload);
  }

  Future<String> _compactImage(
    String imageBase64, {
    required int maxDimension,
    required int quality,
    required int maxBase64Length,
    required String label,
  }) async {
    final compact = _cleanBase64(
      await imageCompressor!(
        imageBase64,
        maxDimension: maxDimension,
        quality: quality,
        maxBase64Length: maxBase64Length,
      ),
    );
    if (compact.isNotEmpty && compact.length <= maxBase64Length) {
      return compact;
    }
    if (imageBase64.length <= maxBase64Length) {
      return imageBase64;
    }
    throw EntregaException(
      'No fue posible comprimir la $label de entrega al tamano permitido.',
    );
  }

  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  String _cleanBase64(String value) {
    return value
        .split('base64,')
        .last
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  Future<void> _loadLocal() async {
    inZone = await localRepository.loadGuides(EntregaGuideStatus.enZona);
    delivered = await localRepository.loadGuides(EntregaGuideStatus.entregada);
    returned = await localRepository.loadGuides(EntregaGuideStatus.devolucion);
    pendingSyncCount = await localRepository.pendingCount();
  }

  Future<void> _runRemote({
    required bool silent,
    required String startMessage,
    required Future<void> Function() action,
  }) async {
    if (offline) {
      await _loadLocal();
      statusMessage = 'Modo offline: usando datos locales.';
      notifyListeners();
      return;
    }
    if (!silent) {
      loading = true;
      errorMessage = null;
      statusMessage = startMessage;
      notifyListeners();
    }
    try {
      await action();
      await _loadLocal();
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _buildDownloadPayload({
    required EntregaGuide guide,
    required EntregaRecipientData recipient,
    required String signatureBase64,
    required String photoBase64,
    required EntregaReason? reason,
    required EntregaDownloadType type,
  }) {
    final now = _formatControllerDate(DateTime.now());
    final guideNumber = int.tryParse(guide.guideNumber) ?? 0;
    final document = int.tryParse(recipient.numericDocument) ?? 0;
    final isReturn = type == EntregaDownloadType.devolucionMensajero;
    return _withoutNullValues({
      'EsAuditor': 0,
      'EsMaestra': 0,
      'EsOffline': 0,
      'EsPagoQR': 'false',
      'EsSello': 'false',
      'FechaAsignacion': guide.assignmentDate,
      'FechaEntrega': guide.auditDate.trim().isNotEmpty ? guide.auditDate : now,
      'MotivoGuia': reason?.toAwsJson(),
      'FechaGrabacion': now,
      'FirmaVirtual': signatureBase64.trim().isEmpty
          ? null
          : {
              'Documento': recipient.numericDocument,
              'Firma': signatureBase64,
              'IdTipoFirma': 1,
              'Nombre': recipient.name,
              'NumeroGuia': guideNumber,
              'Observaciones': recipient.observations,
            },
      'IdCiudad': appInformation.idCiudad,
      'IdEstado': 0,
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
      'NombreQuienRecibe': recipient.name,
      'NumeroGuia': guideNumber,
      'NumeroIntentoFallidoEntrega': guide.deliveryAttempt,
      'RecibidoGuia': isReturn
          ? null
          : {
              'EstadoRegistro': 'A',
              'IdAplicacionOrigen': 'PAM',
              'Identificacion': recipient.numericDocument,
              'NumeroGuia': guideNumber,
              'Otros': recipient.observations,
              'RecibidoPor': recipient.name,
              'Telefono': recipient.phone,
            },
      'TieneIntentoEntrega': reason?.deliveryAttempt ?? false,
      'TipoContador': 0,
      'TipoEvidencia': photoBase64.trim().isEmpty
          ? <Map<String, dynamic>>[]
          : [
              {
                'Imagenes': [photoBase64],
                'NombreEvidenciaControllerApp': 'Entrega mensajero',
                'TipoEvidenciaControllerApp': 1,
              },
            ],
      'TipoNovedad': 0,
      'TipoPredio': recipient.housingTypeId,
      'Observaciones': recipient.observations,
      'EntregaSinAsignacion': false,
      'IdTipoMensajero': int.tryParse(appInformation.idTipoMensajero) ?? 0,
      'NombreCompletoMensajero': appInformation.nombreMensajero,
      'Usuario': appInformation.nombreMensajero,
      'DescargueFueraDeRango': guide.raw['DescargueFueraDeRango'] ?? false,
      'UnidadHabitacional': recipient.housingTypeId,
    });
  }

  void _validateDelivery(
    EntregaRecipientData recipient,
    String signatureBase64,
    String photoBase64,
  ) {
    if (recipient.name.trim().isEmpty) {
      throw const EntregaException('Ingresa el nombre de quien recibe.');
    }
    if (recipient.numericDocument.isEmpty) {
      throw const EntregaException(
        'Ingresa la identificacion de quien recibe.',
      );
    }
    if (recipient.numericDocument.startsWith('0')) {
      throw const EntregaException(
        'La identificacion no puede iniciar en cero.',
      );
    }
    if (signatureBase64.trim().isEmpty) {
      throw const EntregaException('Captura la firma de entrega.');
    }
    if (photoBase64.trim().isEmpty) {
      throw const EntregaException('Captura la foto del paquete.');
    }
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
}
