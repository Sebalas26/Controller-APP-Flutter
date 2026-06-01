import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/native/controller_native_bridge.dart';
import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/anular_guia_remote_repository.dart';
import '../../models/anular_guia_models.dart';

class AnularGuiaController extends ChangeNotifier {
  AnularGuiaController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    String initialGuideNumber = '',
    AnularGuiaRemoteRepository? remoteRepository,
    ControllerNativeBridge? nativeBridge,
  }) : remoteRepository = remoteRepository ?? AnularGuiaRemoteRepository(),
       nativeBridge = nativeBridge ?? ControllerNativeBridge() {
    final guideNumber = _cleanGuide(initialGuideNumber);
    if (guideNumber.isNotEmpty) {
      guiaController.text = guideNumber;
      step = AnularGuiaStep.guia;
    }
  }

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final AnularGuiaRemoteRepository remoteRepository;
  final ControllerNativeBridge nativeBridge;

  final guiaController = TextEditingController();
  final codigoController = TextEditingController();
  final nuevoNumeroController = TextEditingController();

  AnularGuiaStep step = AnularGuiaStep.informacion;
  List<AnulacionReason> reasons = const [];
  AnulacionReason? selectedReason;
  AnularGuide? guide;
  RepresentativePhone? representativePhone;
  AnularGuideResult? cancellationResult;
  bool representativeLegal = false;
  bool phoneModified = false;
  bool loading = false;
  bool sendingCode = false;
  bool cancelling = false;
  int resendRemainingSeconds = 0;
  String modifiedPhone = '';
  String? errorMessage;
  String? statusMessage;

  String _generatedCode = '';
  DateTime? _codeSentAt;
  Timer? _resendTimer;

  bool get canConsultGuide => !loading && !offline;
  bool get canContinueGuide => guide != null && selectedReason != null;
  bool get canContinueRegisteredPhone {
    final phone = representativePhone?.phone ?? '';
    return validateRegisteredPhone(phone) == true && !loading;
  }

  bool get canSaveModifiedPhone {
    return validateModifiedPhone(nuevoNumeroController.text) && !loading;
  }

  bool get canConfirmCode {
    return codigoController.text.trim().length == 6 && !cancelling;
  }

  String get currentOtpPhone {
    if (representativeLegal && phoneModified) return modifiedPhone;
    if (representativeLegal) return representativePhone?.phone ?? '';
    return guide?.telefonoRemitente ?? '';
  }

  Future<void> initialize() async {
    await _loadReasons();
  }

  void continueFromInfo() {
    step = AnularGuiaStep.guia;
    _clearMessages();
    notifyListeners();
  }

  void guideInputChanged() {
    guide = null;
    selectedReason = null;
    cancellationResult = null;
    _clearMessages();
    notifyListeners();
  }

  Future<void> consultGuide() async {
    if (offline) {
      _setError('Sin conexión para consultar la guía.');
      return;
    }
    var guideNumber = _cleanGuide(guiaController.text);
    if (guideNumber.isEmpty) {
      guideNumber = _cleanGuide(await nativeBridge.scanQrCode());
      if (guideNumber.isEmpty) return;
      guiaController.text = guideNumber;
    }
    loading = true;
    guide = null;
    selectedReason = null;
    cancellationResult = null;
    _clearMessages();
    notifyListeners();
    try {
      final foundGuide = await remoteRepository.consultarEstadoGuia(
        config: apiConfig,
        appInformation: appInformation,
        numeroGuia: guideNumber,
      );
      _validateGuide(foundGuide);
      guide = foundGuide;
      statusMessage = 'Guía disponible para anulación.';
      await _loadReasons(silent: true);
    } catch (error) {
      guide = null;
      errorMessage = _messageFromError(
        error,
        fallback: 'La guía no existe o no pudo consultarse.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectReason(AnulacionReason? reason) {
    selectedReason = reason;
    _clearMessages();
    notifyListeners();
  }

  Future<void> continueFromGuide() async {
    final currentGuide = guide;
    final reason = selectedReason;
    if (currentGuide == null || reason == null) {
      _setError('Consulta una guía y selecciona un motivo.');
      return;
    }
    final selectedPosition = reasons.indexOf(reason);
    if (selectedPosition == 0) {
      representativeLegal = false;
      phoneModified = false;
      representativePhone = RepresentativePhone(
        phone: currentGuide.telefonoRemitente,
        serviceCenterId: currentGuide.idCentroServicioOrigen,
      );
      await _startOtpStep();
      return;
    }
    if (selectedPosition == 1) {
      await _loadRepresentativePhone(currentGuide.idCentroServicioOrigen);
      return;
    }
    _setError('Selecciona un motivo válido para continuar.');
  }

  Future<void> saveModifiedPhone() async {
    final currentGuide = guide;
    if (currentGuide == null) {
      _setError('Consulta una guía antes de cambiar el número.');
      return;
    }
    final phone = nuevoNumeroController.text.trim();
    if (!validateModifiedPhone(phone)) {
      _setError('Ingresa un celular válido.');
      return;
    }
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      final saved = await remoteRepository.guardarNumeroRepresentante(
        config: apiConfig,
        appInformation: appInformation,
        numeroGuia: currentGuide.numeroGuia.toString(),
        numeroRegistrado: representativePhone?.phone ?? '',
        numeroEnvio: phone,
      );
      if (!saved) {
        throw const AnularGuiaException('El número no pudo guardarse.');
      }
      phoneModified = true;
      modifiedPhone = phone;
      await _startOtpStep();
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'El número no pudo guardarse.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> continueWithRegisteredPhone() async {
    final phone = representativePhone?.phone ?? '';
    if (validateRegisteredPhone(phone) != true) {
      _setError('El número no corresponde a una línea celular.');
      return;
    }
    phoneModified = false;
    modifiedPhone = '';
    await _startOtpStep();
  }

  void goToChangePhone() {
    nuevoNumeroController.text = '';
    step = AnularGuiaStep.cambiarNumero;
    _clearMessages();
    notifyListeners();
  }

  void newPhoneInputChanged() {
    _clearMessages();
    notifyListeners();
  }

  void codeInputChanged() {
    _clearMessages();
    notifyListeners();
  }

  Future<void> resendCode() async {
    if (resendRemainingSeconds > 0 || sendingCode) return;
    await _sendVerificationCode();
  }

  Future<void> confirmCodeAndCancel() async {
    final currentGuide = guide;
    if (currentGuide == null) {
      _setError('Consulta una guía antes de confirmar la anulación.');
      return;
    }
    final inputCode = codigoController.text.trim();
    if (inputCode.length != 6) {
      _setError('Ingresa el código completo.');
      return;
    }
    if (!_isCodeAlive()) {
      _generatedCode = '';
      _setError('El código expiró.');
      return;
    }
    if (inputCode != _generatedCode) {
      _setError('Código inválido.');
      return;
    }
    if ((representativePhone?.serviceCenterId ?? 0) !=
        currentGuide.idCentroServicioOrigen) {
      _setError('La guía no pertenece al centro de servicio.');
      return;
    }
    cancelling = true;
    _clearMessages();
    notifyListeners();
    try {
      final result = await remoteRepository.anularGuia(
        config: apiConfig,
        appInformation: appInformation,
        guide: currentGuide,
      );
      cancellationResult = result;
      statusMessage = result.mensaje.trim().isEmpty
          ? 'Anulación exitosa.'
          : result.mensaje.trim();
      unawaited(_sendSuccessMessages());
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'Anulación no exitosa.',
      );
    } finally {
      cancelling = false;
      notifyListeners();
    }
  }

  void back() {
    switch (step) {
      case AnularGuiaStep.informacion:
        return;
      case AnularGuiaStep.guia:
        step = AnularGuiaStep.informacion;
        break;
      case AnularGuiaStep.confirmarNumero:
        step = AnularGuiaStep.guia;
        break;
      case AnularGuiaStep.cambiarNumero:
        step = AnularGuiaStep.confirmarNumero;
        break;
      case AnularGuiaStep.confirmarCodigo:
        if (representativeLegal && phoneModified) {
          step = AnularGuiaStep.cambiarNumero;
        } else if (representativeLegal) {
          step = AnularGuiaStep.confirmarNumero;
        } else {
          step = AnularGuiaStep.guia;
        }
        break;
    }
    _clearMessages();
    notifyListeners();
  }

  bool? validateRegisteredPhone(String phone) {
    final value = phone.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('3') || value.length != 10) return false;
    if (value.replaceAll(value[0], '').isEmpty) return false;
    return true;
  }

  bool validateModifiedPhone(String phone) {
    return RegExp(r'^3(?!.*(\d)\1{3})\d{9}$').hasMatch(phone.trim());
  }

  Future<void> _loadReasons({bool silent = false}) async {
    if (reasons.isNotEmpty) return;
    if (!silent) {
      loading = true;
      _clearMessages();
      notifyListeners();
    }
    try {
      reasons = await remoteRepository.obtenerMotivosAnulacion(
        config: apiConfig,
        appInformation: appInformation,
      );
    } catch (error) {
      if (!silent) {
        errorMessage = _messageFromError(
          error,
          fallback: 'No fue posible consultar motivos.',
        );
      }
    } finally {
      if (!silent) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadRepresentativePhone(int serviceCenterId) async {
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      representativePhone = await remoteRepository.obtenerNumeroRepresentante(
        config: apiConfig,
        appInformation: appInformation,
        idCentroServicio: serviceCenterId,
      );
      representativeLegal = true;
      phoneModified = false;
      modifiedPhone = '';
      step = AnularGuiaStep.confirmarNumero;
      final validation = validateRegisteredPhone(
        representativePhone?.phone ?? '',
      );
      if (validation == null) {
        errorMessage = 'No existe un número registrado.';
      } else if (!validation) {
        errorMessage = 'El número no corresponde a una línea celular.';
      }
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible consultar el número registrado.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _startOtpStep() async {
    step = AnularGuiaStep.confirmarCodigo;
    codigoController.text = '';
    _clearMessages();
    notifyListeners();
    await _sendVerificationCode();
  }

  Future<void> _sendVerificationCode() async {
    final currentGuide = guide;
    if (currentGuide == null) return;
    final phone = currentOtpPhone;
    if (phone.trim().isEmpty) {
      _setError('No existe número celular para enviar el código.');
      return;
    }
    sendingCode = true;
    _clearMessages();
    notifyListeners();
    try {
      _generatedCode = _newSmsCode();
      final template = await remoteRepository.obtenerPlantillaCodigoSms(
        apiConfig,
      );
      final message = _formatMessage(
        template,
        _otpRecipientName(currentGuide),
        currentGuide.numeroGuia.toString(),
        _generatedCode,
        '\uD83D\uDCCB',
        '.',
      );
      final sent = await remoteRepository.enviarSms(
        config: apiConfig,
        numeroTelefono: phone,
        mensaje: message,
      );
      if (!sent) {
        _codeSentAt = null;
        throw const AnularGuiaException('No fue posible enviar el código.');
      }
      _codeSentAt = DateTime.now();
      statusMessage = 'Código enviado.';
      _startResendTimer();
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'No fue posible enviar el código.',
      );
    } finally {
      sendingCode = false;
      notifyListeners();
    }
  }

  Future<void> _sendSuccessMessages() async {
    final currentGuide = guide;
    if (currentGuide == null) return;
    try {
      final template = await remoteRepository.obtenerPlantillaAnulacionExitosa(
        apiConfig,
      );
      await remoteRepository.enviarSms(
        config: apiConfig,
        numeroTelefono: currentGuide.telefonoRemitente,
        mensaje: _formatMessage(
          template,
          currentGuide.nombreCompletoRemitente,
          currentGuide.numeroGuia.toString(),
        ),
      );
      await remoteRepository.enviarSms(
        config: apiConfig,
        numeroTelefono: currentGuide.telefonoDestinatario,
        mensaje: _formatMessage(
          template,
          currentGuide.nombreCompletoDestinatario,
          currentGuide.numeroGuia.toString(),
        ),
      );
      if (representativeLegal) {
        final canal = 'CANAL ID: ${currentGuide.idCentroServicioOrigen}';
        final representativeMessage = _formatMessage(
          template,
          canal,
          currentGuide.numeroGuia.toString(),
          '\uD83D\uDCCB',
        );
        await remoteRepository.enviarSms(
          config: apiConfig,
          numeroTelefono: representativePhone?.phone ?? '',
          mensaje: representativeMessage,
        );
        if (phoneModified) {
          await remoteRepository.enviarSms(
            config: apiConfig,
            numeroTelefono: modifiedPhone,
            mensaje: representativeMessage,
          );
        }
      }
    } catch (_) {
      // El SMS de confirmación no debe bloquear una anulación ya confirmada.
    }
  }

  void _validateGuide(AnularGuide? foundGuide) {
    if (foundGuide == null) {
      throw const AnularGuiaException('No se pudo consultar la guía.');
    }
    final serviceCenterId = int.tryParse(appInformation.idCentroServicio) ?? 0;
    if (foundGuide.idCentroServicioOrigen != serviceCenterId) {
      throw const AnularGuiaException(
        'La guía no pertenece al centro de servicio.',
      );
    }
    if (_hoursSinceAdmission(foundGuide.fechaAdmision) >= 24) {
      throw const AnularGuiaException(
        'La guía supera el tiempo permitido para anulación.',
      );
    }
    if (foundGuide.estadoGuia != AnularGuide.estadoAdmitida) {
      throw const AnularGuiaException('La guía no se encuentra admitida.');
    }
  }

  int _hoursSinceAdmission(String dateText) {
    try {
      final admissionDate = DateTime.parse(dateText);
      return DateTime.now().difference(admissionDate).inHours;
    } catch (_) {
      return 24;
    }
  }

  String _otpRecipientName(AnularGuide currentGuide) {
    if (representativeLegal) {
      return 'Canar ID ${representativePhone?.serviceCenterId ?? 0}';
    }
    return currentGuide.nombreCompletoRemitente;
  }

  String _formatMessage(
    String template,
    String arg0, [
    String? arg1,
    String? arg2,
    String? arg3,
    String? arg4,
  ]) {
    var text = template;
    final args = [arg0, arg1, arg2, arg3, arg4];
    for (var index = 0; index < args.length; index++) {
      final value = args[index];
      if (value != null) text = text.replaceAll('{$index}', value);
    }
    return text;
  }

  String _newSmsCode() {
    final random = math.Random.secure();
    String code;
    do {
      code = List.generate(6, (_) => random.nextInt(10)).join();
    } while (code == '000000');
    return code;
  }

  bool _isCodeAlive() {
    final sentAt = _codeSentAt;
    if (sentAt == null) return false;
    return DateTime.now().difference(sentAt) < const Duration(minutes: 5);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    resendRemainingSeconds = 180;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendRemainingSeconds <= 1) {
        resendRemainingSeconds = 0;
        timer.cancel();
      } else {
        resendRemainingSeconds -= 1;
      }
      notifyListeners();
    });
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
    if (error is AnularGuiaException) return error.message;
    return fallback;
  }

  String _cleanGuide(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    guiaController.dispose();
    codigoController.dispose();
    nuevoNumeroController.dispose();
    super.dispose();
  }
}
