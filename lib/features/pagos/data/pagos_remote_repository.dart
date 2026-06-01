import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../models/pagos_models.dart';

class PagosRemoteRepository {
  PagosRemoteRepository({Dio? dio}) : _dio = dio ?? Dio();

  static const _paymentAuthUser = 'user-cognitooauth2';
  static const _paymentAuthPassword = 'SW50ZXIyMDIxKg==';

  final Dio _dio;

  Future<List<PagoOption>> fetchPaymentOptions(
    ControllerApiConfig config,
  ) async {
    final client = _plainClient(config.mediosPagoOnPremiseBaseUrl);
    final response = await client.get<dynamic>(
      'ObtenerMediosPagosAPP',
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) return [PagoOption.cash()];

    final list = _findList(response.data);
    if (list == null || list.isEmpty) return [PagoOption.cash()];

    final options = <int, PagoOption>{PagoMethodIds.cash: PagoOption.cash()};
    for (final item in list) {
      final map = _asMapOrNull(item);
      if (map == null) continue;
      final option = PagoOption.fromJson(map);
      if (option.id > 0) options[option.id] = option;
    }
    final sorted = options.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return sorted;
  }

  Future<PagoOperationResult> sendNequiNotification({
    required ControllerApiConfig config,
    required PagoNotificationRequest request,
  }) async {
    final token = await fetchPaymentAuthToken(config);
    final response = await _paymentClient(config).post<dynamic>(
      'PagosPush/EnviarNotificacion',
      data: _nequiPayload(request),
      options: _authOptions(token),
    );
    return _resultFromResponse(
      response,
      failurePrefix: 'No fue posible enviar la solicitud Nequi',
    );
  }

  Future<PagoOperationResult> synchronizeNequiNotification({
    required ControllerApiConfig config,
    required int transactionId,
  }) async {
    final token = await fetchPaymentAuthToken(config);
    final response = await _paymentClient(config).put<dynamic>(
      'PagosPush/SincronizarNotificacion/$transactionId',
      options: _authOptions(token),
    );
    return _resultFromResponse(
      response,
      fallbackTransactionId: transactionId,
      failurePrefix: 'No fue posible sincronizar el pago Nequi',
    );
  }

  Future<PagoOperationResult> queryNequiNotification({
    required ControllerApiConfig config,
    required int transactionId,
  }) async {
    final token = await fetchPaymentAuthToken(config);
    final response = await _paymentClient(config).get<dynamic>(
      'PagosPush/ConsultarEstadoNotificacion/$transactionId',
      options: _authOptions(token),
    );
    return _resultFromResponse(
      response,
      fallbackTransactionId: transactionId,
      failurePrefix: 'No fue posible consultar el pago Nequi',
    );
  }

  Future<PagoOperationResult> sendLinkPayment({
    required ControllerApiConfig config,
    required PagoNotificationRequest request,
  }) async {
    final token = await fetchPaymentAuthToken(config);
    final response = await _paymentClient(config).post<dynamic>(
      'PagoPayZen/PostCrearSolicitudPago',
      data: _linkPayload(request),
      options: _authOptions(token),
    );
    return _resultFromResponse(
      response,
      failurePrefix: 'No fue posible enviar el link de pago',
    );
  }

  Future<PagoOperationResult> synchronizeLinkPayment({
    required ControllerApiConfig config,
    required int transactionId,
  }) async {
    final token = await fetchPaymentAuthToken(config);
    final response = await _paymentClient(config).put<dynamic>(
      'PagoPayZen/PutSincronizaraPayZen/$transactionId',
      options: _authOptions(token),
    );
    return _resultFromResponse(
      response,
      fallbackTransactionId: transactionId,
      failurePrefix: 'No fue posible sincronizar el link de pago',
    );
  }

  Future<PagoOperationResult> queryLinkPayment({
    required ControllerApiConfig config,
    required int transactionId,
  }) async {
    final token = await fetchPaymentAuthToken(config);
    final response = await _paymentClient(config).get<dynamic>(
      'PagoPayZen/GetConsultarEstadoPayZen/$transactionId',
      options: _authOptions(token),
    );
    return _resultFromResponse(
      response,
      fallbackTransactionId: transactionId,
      failurePrefix: 'No fue posible consultar el link de pago',
    );
  }

  Future<PagoOperationResult> generateQr({
    required ControllerApiConfig config,
    required PagoQrRequest request,
  }) async {
    final auth = await _loginIntegration(config);
    final response = await _legacyPaymentClient(config).post<dynamic>(
      'MediosPago/GenerarCodigoQR',
      data: request.toJson(),
      options: Options(headers: _legacyHeaders(auth)),
    );
    return _resultFromResponse(
      response,
      failurePrefix: 'No fue posible generar el codigo QR',
    );
  }

  Future<PagoOperationResult> queryQrStatus({
    required ControllerApiConfig config,
    required int qrGenerationId,
  }) async {
    final auth = await _loginIntegration(config);
    final response = await _legacyPaymentClient(config).post<dynamic>(
      'MediosPago/ConsultaEstadoTransaccion',
      queryParameters: {'IdGeneracionCodigoQR': qrGenerationId},
      options: Options(headers: _legacyHeaders(auth)),
    );
    return _resultFromResponse(
      response,
      fallbackTransactionId: qrGenerationId,
      failurePrefix: 'No fue posible consultar el codigo QR',
    );
  }

  Future<PagoOperationResult> cancelQr({
    required ControllerApiConfig config,
    required int qrGenerationId,
    int status = 2,
  }) async {
    final auth = await _loginIntegration(config);
    final response = await _legacyPaymentClient(config).post<dynamic>(
      'MediosPago/CancelarCodigoQR',
      queryParameters: {
        'IdGeneracionCodigoQR': qrGenerationId,
        'Estado': status,
      },
      options: Options(headers: _legacyHeaders(auth)),
    );
    return _resultFromResponse(
      response,
      fallbackTransactionId: qrGenerationId,
      failurePrefix: 'No fue posible cancelar el codigo QR',
    );
  }

  Future<PagoOperationResult> sendOrSynchronize({
    required ControllerApiConfig config,
    required PagoNotificationRequest request,
    int existingTransactionId = 0,
  }) {
    if (request.methodId == PagoMethodIds.nequi) {
      if (existingTransactionId > 0) {
        return synchronizeNequiNotification(
          config: config,
          transactionId: existingTransactionId,
        );
      }
      return sendNequiNotification(config: config, request: request);
    }
    if (request.methodId == PagoMethodIds.linkPayment) {
      if (existingTransactionId > 0) {
        return synchronizeLinkPayment(
          config: config,
          transactionId: existingTransactionId,
        );
      }
      return sendLinkPayment(config: config, request: request);
    }
    throw PagosException(
      'El medio de pago ${request.methodId} no tiene flujo remoto migrado.',
    );
  }

  Future<String> fetchPaymentAuthToken(ControllerApiConfig config) async {
    final client = _plainClient(config.mediosPagoAuthBaseUrl);
    final response = await client.post<dynamic>(
      'autorizador',
      data: {'Usuario': _paymentAuthUser, 'Password': _paymentAuthPassword},
    );
    final token = _findString(_asMap(response.data), const [
      'IdToken',
      'idToken',
      'Token',
      'token',
    ]);
    if (token.trim().isEmpty) {
      throw const PagosException(
        'No fue posible obtener token de autorizacion de pagos.',
      );
    }
    return token;
  }

  Future<_IntegrationAuth> _loginIntegration(ControllerApiConfig config) async {
    final client = _plainClient(config.loginIntegrationBaseUrl);
    final response = await client.post<dynamic>(
      'Autenticacion/Login',
      data: {
        'UserName':
            '9PG4iMLN2pRb4rOUA6I9BuImv44U1QrUsxOmzjRYPDPU27rw+CuowP9fem8Xoe1jjIuQqbVCgxMg4TdEU3Ts4g==',
        'Password':
            'HkdqzsVRIzK+7i5Hb62Wlt+cj3Py+fML4ULt7tyUvCUisJhzh/V8kU/TVpzRxL8G',
      },
    );
    final json = _asMap(response.data);
    final token = _findString(json, const ['Token', 'token']);
    final userName = _findString(json, const ['UserName', 'userName']);
    if (token.trim().isEmpty || userName.trim().isEmpty) {
      throw const PagosException(
        'No fue posible autenticar LoginIntegracion para QR.',
      );
    }
    return _IntegrationAuth(token: token, userName: userName);
  }

  Dio _paymentClient(ControllerApiConfig config) {
    return _plainClient(config.mediosPagoBaseUrl);
  }

  Dio _legacyPaymentClient(ControllerApiConfig config) {
    return _plainClient(config.mediosPagoLegacyBaseUrl);
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

  Options _authOptions(String token) {
    return Options(
      headers: {'Authorization': 'Bearer $token'},
      validateStatus: (status) => status != null && status < 600,
    );
  }

  Map<String, Object> _nequiPayload(PagoNotificationRequest request) {
    return {
      'numeroTelefono': _digits(request.phone),
      'idOrigen': 2,
      'identificadorPosApp': request.identifier,
      'idCentroServicio': request.serviceCenterId,
      'tokenSignalR': request.signalRToken,
      'valor': request.amount,
      'usuario': request.userId,
      'idPreFactura': request.preInvoiceId,
      'numeroGuias': request.guides,
    };
  }

  Map<String, Object> _linkPayload(PagoNotificationRequest request) {
    return {
      'idOrigenPago': '2',
      'idCentroServicio': request.serviceCenterId,
      'identificadorPosApp': request.identifier,
      'idPreFactura': request.preInvoiceId,
      'idMedioPago': '2',
      'tipoMoneda': 'COP',
      'valor': request.amount,
      'tipoCanal': request.channel,
      'celular': _digits(request.phone),
      'email': request.email,
      'usuario': request.userId,
      'NumeroGuia': request.guides.join(','),
    };
  }

  Map<String, Object> _legacyHeaders(_IntegrationAuth auth) {
    return {
      'UserName': auth.userName,
      'Token': auth.token,
      'Content-Type': 'application/json',
      'Accept': 'text/json',
    };
  }

  PagoOperationResult _resultFromResponse(
    Response<dynamic> response, {
    int fallbackTransactionId = 0,
    required String failurePrefix,
  }) {
    final status = response.statusCode ?? 0;
    final json = _normalizeResponse(response.data);
    if (status < 200 || status >= 300) {
      final message = _findString(json, const [
        'mensaje',
        'Message',
        'message',
      ]);
      throw PagosException(
        '$failurePrefix. Codigo HTTP $status${message.isEmpty ? '' : ': $message'}.',
      );
    }
    final result = PagoOperationResult.fromJson(
      json,
      fallbackTransactionId: fallbackTransactionId,
    );
    if (!result.success &&
        !result.hasTransaction &&
        result.message.isNotEmpty) {
      throw PagosException('$failurePrefix: ${result.message}.');
    }
    return result;
  }

  Map<String, dynamic> _normalizeResponse(Object? data) {
    if (data == null) return const <String, dynamic>{};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final text = data.trim();
      if (!text.startsWith('{') && !text.startsWith('[')) {
        return {'respuestaEstado': true, 'estado': text.replaceAll('"', '')};
      }
      final decoded = jsonDecode(text);
      return _normalizeResponse(decoded);
    }
    if (data is List && data.isNotEmpty) {
      return _normalizeResponse(data.first);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _asMap(Object? data) {
    final map = _asMapOrNull(data);
    if (map != null) return map;
    throw const PagosException('Respuesta remota invalida en pagos.');
  }

  Map<String, dynamic>? _asMapOrNull(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  List<dynamic>? _findList(Object? data) {
    if (data is List) return data;
    if (data is String && data.trim().isNotEmpty) {
      return _findList(jsonDecode(data));
    }
    if (data is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'Data',
        'result',
        'Result',
        'response',
        'Response',
      ]) {
        final list = _findList(data[key]);
        if (list != null) return list;
      }
      for (final value in data.values) {
        final list = _findList(value);
        if (list != null) return list;
      }
    } else if (data is Map) {
      return _findList(Map<String, dynamic>.from(data));
    }
    return null;
  }

  String _findString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key].toString();
      }
    }
    for (final value in json.values) {
      if (value is Map<String, dynamic>) {
        final found = _findString(value, keys);
        if (found.trim().isNotEmpty) return found;
      } else if (value is Map) {
        final found = _findString(Map<String, dynamic>.from(value), keys);
        if (found.trim().isNotEmpty) return found;
      }
    }
    return '';
  }

  String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}

class _IntegrationAuth {
  const _IntegrationAuth({required this.token, required this.userName});

  final String token;
  final String userName;
}
