import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_id_key_provider.dart';
import '../../login/login.dart';
import '../models/entregas_models.dart';

class EntregasRemoteRepository {
  EntregasRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
  }) : _dio = dio ?? Dio(),
       _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  static const _proofUser = 'usr-prueba-entrega';
  static const _proofPassword = 'SW50ZXIyMDIxKw==';

  final Dio _dio;
  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<List<EntregaGuide>> fetchInZone({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final messengerId = appInformation.idMensajero.trim();
    if (messengerId.isEmpty) {
      throw const EntregaException(
        'No hay id de mensajero para consultar en zona.',
      );
    }
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'OperacionUrbanaController/ObtenerGuiasMensajeroEnZona/${Uri.encodeComponent(messengerId)}',
    );
    return _guideList(response.data).where(_isPendingDelivery).toList();
  }

  Future<List<EntregaGuide>> fetchDelivered({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required List<String> guideNumbers,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.post<dynamic>(
      'OperacionUrbanaController/ObtenerGuiasEntregadasMensajeroApp',
      data: _guideRequest(appInformation, guideNumbers),
    );
    return _guideList(response.data);
  }

  Future<List<EntregaGuide>> fetchReturned({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required List<String> guideNumbers,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.post<dynamic>(
      'OperacionUrbanaController/ObtenerGuiasDevolucionesMensajeroApp',
      data: _guideRequest(appInformation, guideNumbers),
    );
    return _guideList(response.data);
  }

  Future<EntregaGuide?> searchGuide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String guideNumber,
  }) async {
    final guide = guideNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (guide.isEmpty) return null;
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'OperacionUrbanaController/ObtenerGuiaPamiPorNumeroGuia/${Uri.encodeComponent(guide)}',
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status == 404 || response.data == null) return null;
    final map = _firstMap(response.data);
    return map == null ? null : EntregaGuide.fromJson(map);
  }

  Future<List<EntregaReason>> fetchReturnReasons({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    String type = 'DevolucionWPFMensajero',
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'LogisticaInversa/ObtenerMotivosGuias',
      queryParameters: {'tipoMotivo': type},
    );
    final list = _findList(response.data) ?? const [];
    return list
        .map(_firstMap)
        .whereType<Map<String, dynamic>>()
        .map(EntregaReason.fromJson)
        .where((reason) => reason.id != 0)
        .toList();
  }

  Future<EntregaSyncResult> synchronizeDownload({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required EntregaPendingDownload download,
  }) async {
    if (download.type == EntregaDownloadType.devolucionMensajero) {
      return _syncReturn(
        config: config,
        appInformation: appInformation,
        download: download,
      );
    }

    try {
      return await _syncDeliveryProof(
        config: config,
        appInformation: appInformation,
        download: download,
      );
    } on Object {
      return _syncControllerDelivery(
        config: config,
        appInformation: appInformation,
        download: download,
      );
    }
  }

  Future<EntregaSyncResult> _syncReturn({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required EntregaPendingDownload download,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.post<dynamic>(
      'LogisticaInversa/DevolucionMensajeroControllerApp',
      data: download.payload,
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    return _syncResult(response, 'No fue posible sincronizar la devolucion.');
  }

  Future<EntregaSyncResult> _syncControllerDelivery({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required EntregaPendingDownload download,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.post<dynamic>(
      'LogisticaInversa/EntregaCorrectaMensajeroControllerApp',
      data: download.payload,
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    return _syncResult(response, 'No fue posible sincronizar la entrega.');
  }

  Future<EntregaSyncResult> _syncDeliveryProof({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required EntregaPendingDownload download,
  }) async {
    final token = await _deliveryProofToken(config);
    final client = _plainClient(config.deliveryProofBaseUrl);
    final response = await client.post<dynamic>(
      'descarguemensajeroapp',
      data: download.payload,
      options: Options(
        validateStatus: (status) => status != null && status < 600,
        headers: _proofHeaders(token, appInformation),
        preserveHeaderCase: true,
      ),
    );
    return _syncResult(response, 'No fue posible registrar prueba de entrega.');
  }

  Future<String> _deliveryProofToken(ControllerApiConfig config) async {
    final client = _plainClient(
      config.deliveryProofTokenBaseUrl,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'text/json',
      },
    );
    final response = await client.post<dynamic>(
      'Autorizador',
      data: {'Usuario': _proofUser, 'Password': _proofPassword},
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final token = _findString(_asMap(response.data), const [
      'IdToken',
      'idToken',
      'Token',
      'token',
    ]);
    if (token.trim().isEmpty) {
      throw const EntregaException(
        'No fue posible obtener token de prueba de entrega.',
      );
    }
    return token;
  }

  Future<Dio> _controllerClient(
    ControllerApiConfig config,
    AppInformation appInformation,
  ) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    return _httpClient.client(
      config.controllerBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
  }

  Dio _plainClient(String baseUrl, {Map<String, Object>? headers}) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final client = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: headers,
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  Map<String, Object> _proofHeaders(
    String token,
    AppInformation appInformation,
  ) {
    return {
      'Usuario': appInformation.idUsuario,
      'Identificacion': appInformation.identificacionUsuario,
      'NombreMensajero': appInformation.nombreMensajero,
      'Accept': 'text/json',
      'IdUsuario': appInformation.idUsuario,
      'IdCentroServicio': appInformation.idCentroServicio,
      'NombreCentroServicio': _sanitizeHeaderValue(
        appInformation.nombreCentroServicio,
      ),
      'Token': token,
      'IdAplicativoOrigen': '9',
      'Content-Type': 'application/json',
    };
  }

  Map<String, Object> _guideRequest(
    AppInformation appInformation,
    List<String> guideNumbers,
  ) {
    return {
      'idMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
      'lstGuiasConsultaMensajero': guideNumbers
          .map((guide) => int.tryParse(guide) ?? guide)
          .map((guide) => {'numeroGuia': guide})
          .toList(),
    };
  }

  EntregaSyncResult _syncResult(
    Response<dynamic> response,
    String fallbackMessage,
  ) {
    final status = response.statusCode ?? 0;
    final result = EntregaSyncResult.fromResponse(
      response.data,
      httpStatus: status,
    );
    if (status >= 200 && status < 300 && result.success) return result;
    final message = result.message.trim().isNotEmpty
        ? result.message
        : '$fallbackMessage HTTP $status.';
    throw EntregaException(message);
  }

  List<EntregaGuide> _guideList(Object? data) {
    final list = _findList(data) ?? const [];
    return list
        .map(_firstMap)
        .whereType<Map<String, dynamic>>()
        .map(EntregaGuide.fromJson)
        .where((guide) => guide.guideNumber.trim().isNotEmpty)
        .toList();
  }

  List<dynamic>? _findList(Object? data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in const ['data', 'Data', 'resultado', 'Resultado']) {
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

  Map<String, dynamic>? _firstMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) return _firstMap(data.first);
    if (data is String && data.trim().isNotEmpty) {
      return _firstMap(jsonDecode(data));
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? data) {
    final map = _firstMap(data);
    return map ?? <String, dynamic>{};
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

  String _sanitizeHeaderValue(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final isControl = codeUnit <= 0x1f && codeUnit != 0x09;
      if (!isControl && codeUnit < 0x7f) buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  bool _isPendingDelivery(EntregaGuide guide) => guide.isPendingDelivery;
}
