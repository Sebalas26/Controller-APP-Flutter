import 'package:flutter/material.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/mis_mensajeros_local_repository.dart';
import '../../data/mis_mensajeros_remote_repository.dart';
import '../../models/mis_mensajeros_models.dart';

class MisMensajerosController extends ChangeNotifier {
  MisMensajerosController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    MisMensajerosRemoteRepository? remoteRepository,
    MisMensajerosLocalRepository? localRepository,
  }) : remoteRepository = remoteRepository ?? MisMensajerosRemoteRepository(),
       localRepository = localRepository ?? MisMensajerosLocalRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final MisMensajerosRemoteRepository remoteRepository;
  final MisMensajerosLocalRepository localRepository;

  final searchController = TextEditingController();
  final otpPhoneController = TextEditingController();

  List<MisMensajero> supports = const [];
  List<MisMensajero> filteredSupports = const [];
  bool loading = false;
  bool sendingOtp = false;
  bool updatingState = false;
  int supportLimit = 100;
  int activeSupportLimit = 20;
  String? errorMessage;
  String? statusMessage;

  int get activeSupports => supports.where((item) => item.usuarioActivo).length;

  Future<void> initialize() async {
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      await localRepository.ensureSchema();
      supportLimit = await localRepository.maxSupports();
      activeSupportLimit = await localRepository.maxActiveSupports();
      if (offline) {
        supports = await localRepository.loadCachedSupports();
        _applyFilter();
        if (supports.isEmpty) {
          errorMessage = 'Sin conexión y sin apoyos guardados localmente.';
        }
        return;
      }
      await loadSupports();
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Hubo una falla al consultar los apoyos',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadSupports() async {
    if (offline) {
      supports = await localRepository.loadCachedSupports();
      _applyFilter();
      notifyListeners();
      return;
    }
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      final tokens = await localRepository.loadTokens();
      supports = await remoteRepository.getApoyos(
        config: apiConfig,
        tokens: tokens,
        identificacionUsuario: appInformation.identificacionUsuario,
      );
      await localRepository.saveCachedSupports(supports);
      _applyFilter();
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Hubo una falla al consultar los apoyos',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void searchChanged() {
    _clearMessages();
    _applyFilter();
    notifyListeners();
  }

  void search() {
    _clearMessages();
    _applyFilter();
    notifyListeners();
  }

  bool get canCreateSupport {
    return !offline &&
        !sendingOtp &&
        !limitSupportExceeded &&
        !limitActiveExceeded;
  }

  bool get limitSupportExceeded => supports.length >= supportLimit;
  bool get limitActiveExceeded => activeSupports >= activeSupportLimit;

  String? validateCreateSupport() {
    if (offline) return 'Sin conexión para crear mensajeros.';
    if (limitSupportExceeded) return 'No hay cupo para nuevos mensajeros';
    if (limitActiveExceeded) return 'No Puede';
    return null;
  }

  Future<bool> generateOtpCode() async {
    final phone = _cleanPhone(otpPhoneController.text);
    if (!RegExp(r'^3\d{9}$').hasMatch(phone)) {
      _setError('Número celular inválido');
      return false;
    }
    sendingOtp = true;
    _clearMessages();
    notifyListeners();
    try {
      final tokens = await localRepository.loadTokens();
      final roleId = await localRepository.roleIdByName(appInformation.rol);
      await remoteRepository.generateOtpCode(
        config: apiConfig,
        tokens: tokens,
        centroServicio: int.tryParse(appInformation.idCentroServicio) ?? 0,
        numeroTelefono: phone,
        idRolApp: roleId,
      );
      otpPhoneController.clear();
      statusMessage = 'OTP creado y enviado con éxito';
      return true;
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible generar el código OTP.',
      );
      return false;
    } finally {
      sendingOtp = false;
      notifyListeners();
    }
  }

  Future<void> updateSupportState(MisMensajero support, bool active) async {
    if (offline) {
      _setError('Sin conexión para actualizar el apoyo.');
      return;
    }
    if (active && limitActiveExceeded) {
      _setError(
        'Has alcanzado el límite de Mensajeros creados. Solo puedes tener un máximo de \$$activeSupportLimit mensajeros activos.',
      );
      return;
    }
    updatingState = true;
    _clearMessages();
    notifyListeners();
    try {
      final tokens = await localRepository.loadTokens();
      await remoteRepository.updateSupportState(
        config: apiConfig,
        tokens: tokens,
        identificacionApoyo: support.identificacion,
        identificacionResponsable: appInformation.identificacionUsuario,
        active: active,
      );
      _replaceSupport(support.copyWith(usuarioActivo: active));
      await localRepository.saveCachedSupports(supports);
      statusMessage = active
          ? 'Se activó el mensajero ${support.nombre}'
          : await remoteRepository.sendPushNotification(
              title: 'Desactivación de usuario',
              body: 'Su usuario ha sido desactivado',
            );
    } catch (error) {
      errorMessage = _messageFromError(error, fallback: 'Falla consulta');
    } finally {
      updatingState = false;
      notifyListeners();
    }
  }

  void _replaceSupport(MisMensajero updated) {
    supports = supports
        .map((item) => item.idMensajero == updated.idMensajero ? updated : item)
        .toList(growable: false);
    supports = _sortSupports(supports);
    _applyFilter();
  }

  void _applyFilter() {
    final query = searchController.text.trim().toLowerCase();
    final list = query.isEmpty
        ? supports
        : supports
              .where((item) => item.nombre.toLowerCase().contains(query))
              .toList(growable: false);
    filteredSupports = _sortSupports(list);
  }

  List<MisMensajero> _sortSupports(List<MisMensajero> list) {
    final ordered = [...list];
    ordered.sort((left, right) {
      if (left.usuarioActivo != right.usuarioActivo) {
        return left.usuarioActivo ? -1 : 1;
      }
      return left.nombre.toLowerCase().compareTo(right.nombre.toLowerCase());
    });
    return ordered;
  }

  String _cleanPhone(String value) {
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
    if (error is MisMensajerosException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  void dispose() {
    searchController.dispose();
    otpPhoneController.dispose();
    super.dispose();
  }
}
