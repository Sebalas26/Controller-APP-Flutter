import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/tarjeta_comercial_local_repository.dart';
import '../../data/tarjeta_comercial_remote_repository.dart';
import '../../data/tarjeta_comercial_whatsapp_service.dart';
import '../../models/tarjeta_comercial_models.dart';

class TarjetaComercialController extends ChangeNotifier {
  TarjetaComercialController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    TarjetaComercialLocalRepository? localRepository,
    TarjetaComercialRemoteRepository? remoteRepository,
    TarjetaComercialWhatsappService? whatsappService,
  }) : localRepository = localRepository ?? TarjetaComercialLocalRepository(),
       remoteRepository =
           remoteRepository ?? TarjetaComercialRemoteRepository(),
       whatsappService =
           whatsappService ?? const TarjetaComercialWhatsappService();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final TarjetaComercialLocalRepository localRepository;
  final TarjetaComercialRemoteRepository remoteRepository;
  final TarjetaComercialWhatsappService whatsappService;

  final phoneController = TextEditingController();

  List<TarjetaComercialItem> items = const [];
  bool loading = false;
  bool sending = false;
  bool consentCommercial = false;
  bool consentData = false;
  String? errorMessage;
  String? statusMessage;

  bool get canSend => !loading && !sending;

  Future<void> initialize() async {
    loading = true;
    _clearMessages();
    notifyListeners();
    try {
      items = await localRepository.loadItems();
    } catch (_) {
      items = const [];
      errorMessage = 'No fue posible cargar la tarjeta comercial local.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void phoneChanged() {
    _clearMessages();
    notifyListeners();
  }

  void clearPhone() {
    phoneController.clear();
    _clearMessages();
    notifyListeners();
  }

  void toggleCommercialConsent(bool value) {
    consentCommercial = value;
    _clearMessages();
    notifyListeners();
  }

  void toggleDataConsent(bool value) {
    consentData = value;
    _clearMessages();
    notifyListeners();
  }

  Future<void> sendWhatsapp() async {
    if (sending) return;
    sending = true;
    _clearMessages();
    notifyListeners();
    try {
      final phone = _validatePhone(phoneController.text);
      if (!consentCommercial || !consentData) {
        throw const TarjetaComercialException(
          'Para avanzar informele al cliente la aceptación de tratamiento de datos personales',
        );
      }
      if (!offline) {
        unawaited(
          remoteRepository
              .registerPresentation(
                config: apiConfig,
                appInformation: appInformation,
                phone: phone,
              )
              .catchError((_) {}),
        );
      }
      final opened = await whatsappService.share(
        nationalPhone: '57$phone',
        message: _buildWhatsappMessage(),
      );
      if (!opened) {
        throw const TarjetaComercialException(
          'Para enviar la tarjeta comercial necesitas tener WhatsApp instalado.',
        );
      }
      statusMessage = 'Tarjeta comercial lista para compartir por WhatsApp.';
    } catch (error) {
      errorMessage = _messageFromError(
        error,
        fallback: 'El número ingresado no es valido.',
      );
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  String _validatePhone(String value) {
    final phone = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10) {
      throw const TarjetaComercialException(
        'El número celular debe ser de 10 digitos',
      );
    }
    if (!phone.startsWith('3')) {
      throw const TarjetaComercialException(
        'El número celular debe de iniciar con 3',
      );
    }
    return phone;
  }

  String _buildWhatsappMessage() {
    final messengerName = _firstName(appInformation.displayName);
    final serviceCenter = appInformation.idCentroServicio.trim();
    final buffer = StringBuffer()
      ..writeln('*INTER RAPIDÍSIMO!!*')
      ..writeln(' *EN TUS MANOS*')
      ..writeln(
        'Soy *$messengerName* del punto de atención Móvil *$serviceCenter* y estoy para servirte:',
      )
      ..writeln();

    for (final item in items) {
      final title = item.messageTitle.trim();
      final detail = item.messageDetail.trim();
      if (title.isNotEmpty) buffer.writeln(title);
      if (detail.isNotEmpty) {
        buffer
          ..writeln(detail)
          ..writeln();
      }
    }

    buffer
      ..writeln(
        'Al recibir este mensaje autorizaste previamente el tratamiento de datos personales, para la finalidades descritas del tratamiento de datos personales puedes consultar en el link adjunto https://interrapidisimo.com/proteccion-de-datos-personales/',
      )
      ..writeln()
      ..writeln(
        'Si no deseas recibir mensajes o lo recibiste por error puedes enviar tu PQR a tratamiento.datos.personales@interrapidisimo.com',
      )
      ..writeln()
      ..write('Este mensaje es informativo y no tiene respuesta automática.');
    return buffer.toString();
  }

  String _firstName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return appInformation.idUsuario;
    return clean.split(RegExp(r'\s+')).first;
  }

  String _messageFromError(Object error, {required String fallback}) {
    if (error is TarjetaComercialException) return error.message;
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
    phoneController.dispose();
    super.dispose();
  }
}
