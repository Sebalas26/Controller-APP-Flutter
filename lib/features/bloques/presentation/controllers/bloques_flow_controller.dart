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
  String? motherGuideNumber;
  YaapRouteState? routeState;
  List<YaapDelivery> deliveries = const [];
  List<YaapPendingBlock> pendingBlocks = const [];
  List<YaapRejectionReason> rejectionReasons = const [];

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
      motherGuideNumber = null;
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
        deliveries = const [];
        await localRepository.saveDeliveries(deliveries);
        motherGuideNumber = null;
        routeState = null;
        statusMessage = 'Mensajero validado.';
      },
    );
  }

  Future<void> prepareCourierForDeliveries() async {
    final current = courier;
    if (current == null) {
      throw const YaapException('Primero valida un mensajero.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Actualizando ruta.',
      action: () async {
        final routeUpdated = await remoteRepository.updateRoute(
          config: apiConfig,
          appInformation: appInformation,
          courier: current,
        );
        if (!routeUpdated) {
          throw const YaapException('No fue posible actualizar la ruta.');
        }
        final notified = await remoteRepository.notifyCourierAvailability(
          config: apiConfig,
          appInformation: appInformation,
          courier: current,
          enabled: true,
        );
        if (!notified) {
          throw const YaapException('No fue posible habilitar el mensajero.');
        }
        statusMessage = 'Mensajero habilitado.';
      },
    );
  }

  Future<void> loadDeliveryManagement() async {
    final current = courier;
    if (current == null) {
      throw const YaapException('Primero valida un mensajero.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Consultando entregas.',
      action: () async {
        await _refreshDeliveriesRemote(current);
        await _validateAndAssignCurrentBlockRemote(current);
        final routeId = current.routeId;
        routeState = routeId.isEmpty
            ? null
            : await remoteRepository.validateRouteState(
                config: apiConfig,
                appInformation: appInformation,
                routeId: routeId,
              );
        if (_isApprovedRoute(routeState)) {
          await _completeApprovedRoute(current);
          statusMessage = 'Entrega cerrada correctamente.';
        } else if (_isRejectedRoute(routeState)) {
          statusMessage = 'Ruta rechazada. Revisa las guias reportadas.';
        } else if (_isPendingRoute(routeState)) {
          statusMessage = 'Ruta pendiente por aprobacion.';
        } else {
          statusMessage = 'Entregas listas para gestionar.';
        }
      },
    );
  }

  Future<void> validateAndAssignCurrentBlock() async {
    final current = courier;
    if (current == null) {
      throw const YaapException('Primero valida un mensajero.');
    }
    final firstGuide = current.guideNumbers
        .map((guide) => guide.replaceAll(RegExp(r'[^0-9]'), '').trim())
        .firstWhere((guide) => guide.isNotEmpty, orElse: () => '');
    if (firstGuide.isEmpty) {
      throw const YaapException('El mensajero no tiene guias para validar.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Asignando gestion de bloque.',
      action: () async {
        await _validateAndAssignCurrentBlockRemote(current);
        statusMessage = 'Gestion del bloque asignada.';
      },
    );
  }

  Future<void> _validateAndAssignCurrentBlockRemote(YaapCourier current) async {
    final firstGuide = current.guideNumbers
        .map((guide) => guide.replaceAll(RegExp(r'[^0-9]'), '').trim())
        .firstWhere((guide) => guide.isNotEmpty, orElse: () => '');
    if (firstGuide.isEmpty) {
      throw const YaapException('El mensajero no tiene guias para validar.');
    }
    final guideMother = await remoteRepository.validateMotherGuide(
      config: apiConfig,
      appInformation: appInformation,
      guideNumber: firstGuide,
    );
    final cleanMotherGuide = guideMother
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    if (cleanMotherGuide.isEmpty) {
      throw const YaapException(
        'No pudimos encontrar el numero del bloque. Intentalo de nuevo.',
      );
    }
    motherGuideNumber = cleanMotherGuide;

    final assigned = await remoteRepository.assignBlock(
      config: apiConfig,
      appInformation: appInformation,
      block: YaapPendingBlock(
        raw: {
          ...current.raw,
          'numeroGuiaMadre': cleanMotherGuide,
          'numeroGuiaAsignacion': firstGuide,
          'guiasBloque': current.guideNumbers,
        },
        id: 0,
        motherGuideNumber: firstGuide,
        courierDocument: current.document,
        courierName: current.name,
        assignedUser: _currentUserName,
        photoUrl: current.photoUrl,
        status: 'pendiente',
        guideNumbers: current.guideNumbers,
        createdAt: DateTime.now(),
        endsAt: null,
      ),
    );
    if (!assigned) {
      throw const YaapException(
        'No fue posible asignar la gestion del bloque.',
      );
    }
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
        await _refreshDeliveriesRemote(current);
        statusMessage = 'Entregas actualizadas: ${deliveries.length}.';
      },
    );
  }

  Future<void> loadRejectionReasons() async {
    if (rejectionReasons.isNotEmpty) return;
    _ensureOnline();
    await _runRemote(
      startMessage: 'Consultando causales de rechazo.',
      action: () async {
        rejectionReasons = await remoteRepository.fetchRejectionReasons(
          config: apiConfig,
          appInformation: appInformation,
        );
        if (rejectionReasons.isEmpty) {
          throw const YaapException('No se encontraron causales de rechazo.');
        }
        statusMessage = 'Causales de rechazo cargadas.';
      },
    );
  }

  Future<void> rejectCourier({
    required YaapRejectionReason reason,
    required List<String> guideNumbers,
  }) async {
    final current = courier;
    if (current == null) {
      throw const YaapException('Primero valida un mensajero.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Rechazando mensajero.',
      action: () async {
        if (reason.requiresGuideSelection) {
          final selected = guideNumbers
              .map((guide) => guide.replaceAll(RegExp(r'[^0-9]'), '').trim())
              .where((guide) => guide.isNotEmpty)
              .toSet();
          if (selected.isEmpty) {
            throw const YaapException(
              'Selecciona al menos una guia para rechazar.',
            );
          }
          if (deliveries.isEmpty) {
            await _refreshDeliveriesRemote(current);
          }
          final selectedDeliveries = deliveries
              .where(
                (delivery) => selected.contains(
                  delivery.guideNumber.replaceAll(RegExp(r'[^0-9]'), '').trim(),
                ),
              )
              .toList(growable: false);
          if (selectedDeliveries.isEmpty) {
            throw const YaapException(
              'No fue posible encontrar las guias seleccionadas.',
            );
          }
          final rejected = await remoteRepository.markRejectionGuides(
            config: apiConfig,
            appInformation: appInformation,
            reasonId: reason.id,
            deliveries: selectedDeliveries,
          );
          if (!rejected) {
            throw const YaapException(
              'No fue posible rechazar las guias seleccionadas.',
            );
          }
        } else {
          final notified = await remoteRepository.notifyCourierAvailability(
            config: apiConfig,
            appInformation: appInformation,
            courier: current,
            enabled: false,
          );
          if (!notified) {
            throw const YaapException('No fue posible rechazar el mensajero.');
          }
        }
        await _clearCurrentCourier();
        statusMessage = 'Mensajero rechazado.';
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

  Future<void> closeCurrentDelivery() async {
    final guideMother = motherGuideNumber?.trim() ?? '';
    if (guideMother.isEmpty) {
      throw const YaapException('No se encontro la guia madre del bloque.');
    }
    _ensureOnline();
    await _runRemote(
      startMessage: 'Validando cierre de entrega.',
      action: () async {
        final verified = await remoteRepository.verifyBlockGuides(
          config: apiConfig,
          appInformation: appInformation,
          motherGuideNumber: guideMother,
        );
        if (!verified) {
          throw const YaapException('Faltan envios por verificar.');
        }
        statusMessage = 'Entrega verificada correctamente.';
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
    motherGuideNumber = block.motherGuideNumber;
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

  Future<void> _refreshDeliveriesRemote(YaapCourier current) async {
    deliveries = await remoteRepository.fetchDeliveries(
      config: apiConfig,
      appInformation: appInformation,
      guideNumbers: current.guideNumbers,
    );
    await localRepository.saveDeliveries(deliveries);
  }

  Future<void> _completeApprovedRoute(YaapCourier current) async {
    final guideMother = motherGuideNumber?.trim() ?? '';
    if (guideMother.isEmpty) {
      throw const YaapException('No se encontro la guia madre del bloque.');
    }
    final assigned = await remoteRepository.assignSheet(
      config: apiConfig,
      appInformation: appInformation,
      courier: current,
    );
    if (!assigned) {
      throw const YaapException('No fue posible asignar la planilla.');
    }
    final delivered = await remoteRepository.deliverBlock(
      config: apiConfig,
      appInformation: appInformation,
      motherGuideNumber: guideMother,
    );
    if (!delivered) {
      throw const YaapException('No fue posible entregar el bloque.');
    }
    final closed = await remoteRepository.closeMotherGuide(
      config: apiConfig,
      appInformation: appInformation,
      motherGuideNumber: guideMother,
    );
    if (!closed) {
      throw const YaapException('No fue posible cerrar la guia madre.');
    }
  }

  Future<void> _clearCurrentCourier() async {
    courier = null;
    motherGuideNumber = null;
    routeState = null;
    deliveries = const [];
    await localRepository.clearCourierAndDeliveries();
  }

  bool _isApprovedRoute(YaapRouteState? state) {
    return state?.status.toLowerCase().contains('aprob') ?? false;
  }

  bool _isRejectedRoute(YaapRouteState? state) {
    return state?.status.toLowerCase().contains('rechaz') ?? false;
  }

  bool _isPendingRoute(YaapRouteState? state) {
    return state?.status.toLowerCase().contains('pend') ?? false;
  }

  void _ensureOnline() {
    if (offline) {
      throw const YaapException('Este flujo requiere conexion.');
    }
  }

  String get _currentUserName {
    if (appInformation.nombreUsuario.trim().isNotEmpty) {
      return appInformation.nombreUsuario.trim();
    }
    if (appInformation.idUsuario.trim().isNotEmpty) {
      return appInformation.idUsuario.trim();
    }
    return appInformation.identificacionUsuario.trim();
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
