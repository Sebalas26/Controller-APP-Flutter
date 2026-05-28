import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/native/controller_native_bridge.dart';
import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_crypto.dart';
import '../../../shared/security/controller_id_key_provider.dart';
import '../../login/login.dart';
import '../models/bloques_models.dart';

class BloquesRemoteRepository {
  BloquesRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
    ControllerNativeBridge? nativeBridge,
    ControllerCrypto? crypto,
  }) : _dio = dio ?? Dio(),
       _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio),
       _nativeBridge = nativeBridge ?? ControllerNativeBridge(),
       _crypto = crypto ?? ControllerCrypto();

  final Dio _dio;
  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;
  final ControllerNativeBridge _nativeBridge;
  final ControllerCrypto _crypto;
  YaapToken? _token;
  String? _integrationToken;

  static const _integrationUser =
      '9PG4iMLN2pRb4rOUA6I9BuImv44U1QrUsxOmzjRYPDPU27rw+CuowP9fem8Xoe1jjIuQqbVCgxMg4TdEU3Ts4g==';
  static const _integrationPassword =
      'HkdqzsVRIzK+7i5Hb62Wlt+cj3Py+fML4ULt7tyUvCUisJhzh/V8kU/TVpzRxL8G';

  Future<YaapQrIdentity> identityFromQr(String qrCodeData) async {
    final decrypted = await _decryptControllerPayload(qrCodeData);
    final payload = _decodeJwtPayload(decrypted);
    final data = yaapAsMap(payload['data']) ?? payload;
    final id = (data['id'] ?? '').toString();
    final parts = id.split('-');
    if (parts.length != 2 ||
        parts.first.trim().isEmpty ||
        parts.last.trim().isEmpty) {
      throw const YaapException('El QR no tiene la estructura esperada.');
    }
    return YaapQrIdentity(document: parts.first.trim(), otp: parts.last.trim());
  }

  Future<YaapCourier> identifyCourier({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String document,
    required String otp,
  }) async {
    final client = _plainClient(config.yaapBaseUrl);
    final response = await client.post<dynamic>(
      'check-courier-identity-by-yaap-customer',
      data: {'documentoMensajero': document, 'OTP': otp},
      options: await _yaapOptions(config, appInformation),
    );
    final json = _asMap(response.data);
    final encrypted = _readAnyString(json, const ['response', 'Response']);
    final message = _readAnyString(json, const ['mensaje', 'message']);
    if (encrypted.isEmpty) {
      throw YaapException(
        message.isEmpty ? 'No fue posible validar el mensajero.' : message,
      );
    }
    final decrypted = await _decryptControllerPayload(encrypted);
    final payload = _decodeJwtPayload(decrypted);
    return YaapCourier.fromJson(payload, otp: otp);
  }

  Future<bool> updateRoute({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required YaapCourier courier,
  }) async {
    final idRoute =
        int.tryParse(courier.routeId.trim()) ??
        double.tryParse(courier.routeId.trim().replaceAll(',', '.'))?.round();
    if (idRoute == null || idRoute <= 0) {
      throw const YaapException('El mensajero no tiene ruta para actualizar.');
    }
    final guides = courier.guideNumbers
        .map((guide) => int.tryParse(guide))
        .whereType<int>()
        .toList(growable: false);
    if (guides.isEmpty) {
      throw const YaapException('El mensajero no tiene guias para actualizar.');
    }
    final client = await _serviciosAgilesClient(config, appInformation);
    final response = await client.post<dynamic>(
      'GestionGuias/ActualizarRutaGuias',
      data: {'idRuta': idRoute, 'guias': guides},
    );
    return _readGeneralBool(
      response.data,
      fallbackMessage: 'No fue posible actualizar la ruta.',
    );
  }

  Future<bool> notifyCourierAvailability({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required YaapCourier courier,
    required bool enabled,
  }) async {
    final client = _plainClient(config.yaapBaseUrl);
    await client.patch<dynamic>(
      'notify-courier-availability-to-receive-service',
      data: {
        'documentoMensajero': courier.document,
        'habilitadoParaRecibirServicio': enabled,
        'OTP': courier.otp,
      },
      options: await _yaapOptions(config, appInformation),
    );
    return true;
  }

  Future<List<YaapDelivery>> fetchDeliveries({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required List<String> guideNumbers,
  }) async {
    if (guideNumbers.isEmpty) return const [];
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.controllerBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.post<dynamic>(
      'CentrosServicio/ObtenerPuertaEstibaGuia',
      data: guideNumbers,
    );
    return _readResponseList(
      response.data,
    ).map(YaapDelivery.fromJson).toList(growable: false);
  }

  Future<List<YaapRejectionReason>> fetchRejectionReasons({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final client = await _serviciosAgilesClient(config, appInformation);
    final response = await client.get<dynamic>(
      'GestionGuiasAPP/ObtenerCausalesRechazo',
    );
    _throwIfGeneralError(
      response.data,
      fallbackMessage: 'No fue posible consultar causales de rechazo.',
    );
    return _readResponseList(response.data)
        .map(YaapRejectionReason.fromJson)
        .where((reason) => reason.id > 0 && reason.description.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> markRejectionGuides({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required int reasonId,
    required List<YaapDelivery> deliveries,
  }) async {
    if (deliveries.isEmpty) {
      throw const YaapException('Selecciona al menos una guia para rechazar.');
    }
    final client = await _serviciosAgilesClient(config, appInformation);
    final idCenter = int.tryParse(appInformation.idCentroServicio) ?? 0;
    final response = await client.post<dynamic>(
      'GestionGuiasAPP/MarcarCausalRechazoGuia',
      data: deliveries
          .map(
            (delivery) => {
              'idAdmisionMensajeria': delivery.admissionId,
              'numeroGuia':
                  int.tryParse(delivery.guideNumber) ?? delivery.guideNumber,
              'idCentroServicio': idCenter,
              'idEstadoServiciosAgiles': 12,
              'nombreArchivo': '',
              'idCausalRechazo': reasonId,
            },
          )
          .toList(growable: false),
    );
    return _readGeneralBool(
      response.data,
      fallbackMessage: 'No fue posible rechazar las guias seleccionadas.',
    );
  }

  Future<List<YaapPendingBlock>> fetchPendingBlocks({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.entregaBloqueBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.get<dynamic>(
      'BloquesEntrega/ObtenerBloquesEnGestion',
      queryParameters: {'IdCentroDeServicio': appInformation.idCentroServicio},
    );
    final json = _asMap(response.data);
    final result = yaapAsMap(json['resultado']) ?? json;
    return yaapReadMapList(
      result['bloquesPendientes'],
    ).map(YaapPendingBlock.fromJson).toList(growable: false);
  }

  Future<String> validateMotherGuide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String guideNumber,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.armadoBloquesBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.get<dynamic>(
      'OperacionUrbanaController/ValidarGuiaPerteneceABloque',
      queryParameters: {'numeroGuia': guideNumber},
    );
    return _readMotherGuideNumber(response.data);
  }

  Future<bool> assignSheet({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required YaapCourier courier,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.controllerBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.post<dynamic>(
      'OperacionUrbanaController/AsignacionPlanillaYaap',
      data: {
        'ListaGuias': courier.guideNumbers
            .map((guide) => int.tryParse(guide) ?? guide)
            .toList(),
        'IdentificacionMensajeroYaap': courier.document,
        'NombreMensajeroYaap': courier.name,
        'IdCentroServicio': int.tryParse(appInformation.idCentroServicio) ?? 0,
        'IdMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
      },
    );
    return response.data == true || response.data?.toString() == 'true';
  }

  Future<YaapRouteState?> validateRouteState({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String routeId,
  }) async {
    if (routeId.trim().isEmpty) return null;
    final client = await _serviciosAgilesClient(config, appInformation);
    final response = await client.get<dynamic>(
      'GestionGuias/ObtenerGuiasEstadoRuta',
      queryParameters: {'idRuta': routeId},
    );
    final json = _asMap(response.data);
    final result = json['resultado'];
    final stateJson = result is String
        ? _asMap(result)
        : yaapAsMap(result) ?? json;
    return YaapRouteState.fromJson(stateJson);
  }

  Future<bool> verifyBlockGuides({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String motherGuideNumber,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.entregaBloqueBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.get<dynamic>(
      'BloquesEntrega/ValidarVerificacionYaap',
      queryParameters: {
        'Id': int.tryParse(motherGuideNumber) ?? motherGuideNumber,
      },
    );
    return _readBoolLike(response.data);
  }

  Future<bool> deliverBlock({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String motherGuideNumber,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.entregaBloqueBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.patch<dynamic>(
      'BloquesEntrega/EntregarBloque',
      data: {
        'numeroGuiaMadre': int.tryParse(motherGuideNumber) ?? 0,
        'modificadoPor': _currentUserName(appInformation),
      },
    );
    final json = yaapAsMap(response.data);
    if (json != null &&
        (json.containsKey('operacionExitosa') || json.containsKey('success'))) {
      return _readAnyBool(json, const ['operacionExitosa', 'success']);
    }
    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<bool> closeMotherGuide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String motherGuideNumber,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.armadoBloquesBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.post<dynamic>(
      'AdmisionMensajeria/CerrarGuiaMadreBloque',
      queryParameters: {'numeroGuiaMadre': motherGuideNumber},
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<bool> assignBlock({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required YaapPendingBlock block,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.entregaBloqueBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.post<dynamic>(
      'BloquesEntrega/AsignarUsuarioGestionBloque',
      data: {
        'NumeroGuia': int.tryParse(block.motherGuideNumber) ?? 0,
        'Usuario': _currentUserName(appInformation),
        'DocumentoMensajero': int.tryParse(block.courierDocument) ?? 0,
      },
    );
    final json = yaapAsMap(response.data);
    if (json != null &&
        (json.containsKey('operacionExitosa') || json.containsKey('success'))) {
      return _readAnyBool(json, const ['operacionExitosa', 'success']);
    }
    return response.statusCode == 200;
  }

  Future<bool> validateBlockManagement({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required YaapPendingBlock block,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.entregaBloqueBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.get<dynamic>(
      'BloquesEntrega/ValidarGestionAsignacionBloque',
      queryParameters: {
        'NumeroGuia': block.motherGuideNumber,
        'Usuario': block.assignedUser.trim().isNotEmpty
            ? block.assignedUser.trim()
            : _currentUserName(appInformation),
      },
    );
    final json = yaapAsMap(response.data);
    return _readAnyBool(json ?? const {}, const [
      'operacionExitosa',
      'resultado',
    ]);
  }

  Future<Options> _yaapOptions(
    ControllerApiConfig config,
    AppInformation appInformation,
  ) async {
    final token = await _tokenFor(config);
    return Options(
      headers: {
        'Authorization': token.accessToken,
        'x-id-token': token.idToken,
        'x-refresh-token': token.refreshToken,
        'x-id-center': int.tryParse(appInformation.idCentroServicio) ?? 0,
      },
    );
  }

  Future<Dio> _serviciosAgilesClient(
    ControllerApiConfig config,
    AppInformation appInformation,
  ) async {
    final token = await _integrationTokenFor(config);
    final client = _httpClient.client(
      config.serviciosAgilesBaseUrl,
      headerSource: appInformation,
    );
    client.options.headers['IdToken'] = token;
    return client;
  }

  Future<String> _integrationTokenFor(ControllerApiConfig config) async {
    final current = _integrationToken;
    if (current != null && current.trim().isNotEmpty) return current;
    final client = _plainClient(config.loginIntegrationBaseUrl);
    final response = await client.post<dynamic>(
      'Autenticacion/Login',
      data: {'UserName': _integrationUser, 'Password': _integrationPassword},
    );
    final token = _findString(response.data, const [
      'Token',
      'token',
      'IdToken',
      'idToken',
    ]);
    if (token.trim().isEmpty) {
      throw const YaapException(
        'No fue posible autenticar contra LoginIntegracion.',
      );
    }
    _integrationToken = token;
    return token;
  }

  Future<YaapToken> _tokenFor(ControllerApiConfig config) async {
    final current = _token;
    if (current != null && current.isValid) return current;
    final user = await _nativeBridge.yaapUser();
    final password = await _passwordFor(config);
    if (user.trim().isEmpty || password.trim().isEmpty) {
      throw const YaapException('No se encontraron credenciales del servicio.');
    }
    final client = _plainClient(config.yaapBaseUrl);
    final response = await client.post<dynamic>(
      'sign-in',
      data: {'email': user, 'password': password},
    );
    final token = YaapToken.fromJson(_asMap(response.data));
    if (!token.isValid) {
      throw const YaapException(
        'No fue posible autenticar contra el servicio.',
      );
    }
    _token = token;
    return token;
  }

  Future<String> _passwordFor(ControllerApiConfig config) {
    final label = config.label.toLowerCase();
    if (label.contains('produccion')) {
      return _nativeBridge.yaapPasswordProduccion();
    }
    if (label.contains('qa')) return _nativeBridge.yaapPasswordQa();
    return _nativeBridge.yaapPasswordPruebas();
  }

  Future<String> _decryptControllerPayload(String value) async {
    final keySecret = await _nativeBridge.aesKeySecret();
    final saltSecret = await _nativeBridge.aesSaltSecret();
    if (keySecret.trim().isEmpty || saltSecret.trim().isEmpty) {
      throw const YaapException('No se pudieron leer las llaves AES.');
    }
    return _crypto.decryptControllerAes(
      encryptionKeyBase64: keySecret,
      saltBase64: saltSecret,
      cipherText: value,
    );
  }

  Dio _plainClient(String baseUrl) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final client = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const YaapException(
        'La respuesta del servicio no tiene formato valido.',
      );
    }
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return _asMap(jsonDecode(payload));
  }

  List<Map<String, dynamic>> _readResponseList(Object? data) {
    if (data is List) {
      return data
          .map(yaapAsMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    final json = yaapAsMap(data);
    return yaapReadMapList(
      json == null ? null : json['resultado'] ?? json['data'],
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    return yaapAsMap(value) ?? const {};
  }

  String _readAnyString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  bool _readAnyBool(Map<String, dynamic> json, List<String> keys) {
    final value = _readAnyString(json, keys).toLowerCase();
    return value == 'true' || value == '1' || value == 'si';
  }

  String _findString(Object? value, List<String> keys) {
    if (value is String && value.trim().isNotEmpty) {
      try {
        return _findString(jsonDecode(value), keys);
      } on Object {
        return '';
      }
    }
    if (value is Map) {
      for (final key in keys) {
        final direct = value[key];
        if (direct != null && direct.toString().trim().isNotEmpty) {
          return direct.toString().trim();
        }
      }
      for (final child in value.values) {
        final nested = _findString(child, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
    if (value is List) {
      for (final child in value) {
        final nested = _findString(child, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
    return '';
  }

  bool _readGeneralBool(Object? data, {required String fallbackMessage}) {
    final json = _tryAsMap(data);
    if (json != null) {
      _throwIfGeneralError(data, fallbackMessage: fallbackMessage);
      final result =
          json['resultado'] ??
          json['Resultado'] ??
          json['result'] ??
          json['success'] ??
          json['operacionExitosa'];
      if (result == null) return false;
      return _readBoolLike(result);
    }
    return _readBoolLike(data);
  }

  void _throwIfGeneralError(Object? data, {required String fallbackMessage}) {
    final json = _tryAsMap(data);
    if (json == null) return;
    final hasError = json.containsKey('error') || json.containsKey('Error');
    final errorValue = json['error'] ?? json['Error'];
    if (hasError && _readBoolLike(errorValue)) {
      final message = _readAnyString(json, const ['mensaje', 'message']);
      throw YaapException(message.isEmpty ? fallbackMessage : message);
    }
  }

  bool _readBoolLike(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'si';
  }

  String _readMotherGuideNumber(Object? data) {
    final json = _tryAsMap(data);
    if (json != null) {
      final direct = _readAnyString(json, const [
        'numeroGuiaMadre',
        'NumeroGuiaMadre',
        'guiaMadre',
        'GuiaMadre',
        'resultado',
        'data',
        'valor',
      ]);
      if (direct.isNotEmpty) return _cleanGuideValue(direct);
    }
    return _cleanGuideValue(data?.toString() ?? '');
  }

  Map<String, dynamic>? _tryAsMap(Object? value) {
    try {
      return yaapAsMap(value);
    } on Object {
      return null;
    }
  }

  String _cleanGuideValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return '';
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _currentUserName(AppInformation appInformation) {
    if (appInformation.nombreUsuario.trim().isNotEmpty) {
      return appInformation.nombreUsuario.trim();
    }
    if (appInformation.idUsuario.trim().isNotEmpty) {
      return appInformation.idUsuario.trim();
    }
    return appInformation.identificacionUsuario.trim();
  }
}
