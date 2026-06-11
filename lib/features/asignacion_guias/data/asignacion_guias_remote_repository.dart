import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_id_key_provider.dart';
import '../../login/login.dart';
import '../models/asignacion_guias_models.dart';

class AsignacionGuiasRemoteRepository {
  AsignacionGuiasRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
  }) : _dio = dio ?? Dio(),
       _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  final Dio _dio;
  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<AsignacionGuideState> getEstadoGuia({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String numeroGuia,
  }) async {
    try {
      final client = await _controllerPublicClient(config, appInformation);
      final response = await client.get<dynamic>(
        'AdmisionMensajeria/ObtenerGuiaEstado',
        queryParameters: {
          'NumeroGuia': numeroGuia.trim(),
          'IdCentroServicio': appInformation.idCentroServicio,
          'IdCiudad': appInformation.idCiudad,
        },
      );
      final json = _asMap(response.data);
      if (_readBool(json, 'error', fallbackKeys: ['Error'])) {
        throw AsignacionGuiasException(
          _readString(json, 'mensaje', fallbackKeys: ['Mensaje']).trim().isEmpty
              ? 'Falla consulta'
              : _readString(json, 'mensaje', fallbackKeys: ['Mensaje']),
        );
      }
      final result = asignacionAsMap(json['resultado'] ?? json['Resultado']);
      if (result.isEmpty) {
        throw const AsignacionGuiasException('Falla consulta');
      }
      return AsignacionGuideState.fromJson(result);
    } on DioException catch (error) {
      throw AsignacionGuiasException(_messageFromDio(error, 'Falla consulta'));
    }
  }

  Future<List<AsignacionMessenger>> getMensajerosData({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required AsignacionAccessTokens tokens,
  }) async {
    try {
      final response = await _plainClient(
        config.apoyosBaseUrl,
        headers: _tokenHeaders(tokens),
      ).get<dynamic>('MisMensajeros/ObtenerMensajerosPorCentroServicio');
      final currentDocument = appInformation.identificacionUsuario.trim();
      final messengers = asignacionAsMapList(response.data)
          .map(AsignacionMessenger.fromJson)
          .where((item) => item.usuarioActivo)
          .where((item) => item.identificacion.trim() != currentDocument)
          .toList();
      messengers.sort(
        (left, right) =>
            left.nombre.toLowerCase().compareTo(right.nombre.toLowerCase()),
      );
      return messengers;
    } on DioException catch (error) {
      throw AsignacionGuiasException(_messageFromDio(error, 'Falla consulta'));
    }
  }

  Future<ReassignGuidesResult> reAsignarGuias({
    required ControllerApiConfig config,
    required AsignacionAccessTokens tokens,
    required String compressedRequest,
  }) async {
    try {
      final response =
          await _plainClient(
            config.asignacionGuiasBaseUrl,
            headers: _tokenHeaders(tokens),
          ).post<dynamic>(
            'AsignacionGuias/ReasignarGuiasMensajero',
            data: {'Base64CompressedData': compressedRequest},
          );
      final json = _asMap(response.data);
      if (json.isEmpty) {
        throw const AsignacionGuiasException(
          'Fallo el servicio, intenta de nuevo.',
        );
      }
      return ReassignGuidesResult.fromJson(json);
    } on DioException catch (error) {
      throw AsignacionGuiasException(
        _messageFromDio(error, 'Fallo el servicio, intenta de nuevo.'),
      );
    }
  }

  Future<PreviousSheets> getHistoricoGuiasApoyo({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required int idMensajero,
  }) async {
    try {
      final client = await _controllerPublicClient(config, appInformation);
      final response = await client.get<dynamic>(
        'AdmisionMensajeria/ObtenerGuiasMensajeroEnZona',
        queryParameters: {'IdMensajero': idMensajero},
      );
      final json = _asMap(response.data);
      if (_readBool(json, 'error', fallbackKeys: ['Error'])) {
        throw AsignacionGuiasException(
          _readString(json, 'mensaje', fallbackKeys: ['Mensaje']).trim().isEmpty
              ? 'Falla consulta'
              : _readString(json, 'mensaje', fallbackKeys: ['Mensaje']),
        );
      }
      final encoded = _readString(
        json,
        'resultado',
        fallbackKeys: ['Resultado'],
      );
      if (encoded.trim().isEmpty) return PreviousSheets.empty();
      return PreviousSheets.fromJson(_decompressBase64Json(encoded));
    } on DioException catch (error) {
      throw AsignacionGuiasException(_messageFromDio(error, 'Falla consulta'));
    }
  }

  String compressReassignmentBody({
    required String idCiudad,
    required String nombreCiudad,
    required int idMensajero,
    required int idTipoMensajero,
    required String nombreMensajero,
    required List<int> listaGuias,
  }) {
    final body = {
      'Observacion': 'Asignacion desde APP',
      'IdCiudadAplicacion': idCiudad,
      'NombreCiudadAplicacion': nombreCiudad,
      'Latitud': '',
      'Longitud': '',
      'IdMensajero': idMensajero,
      'IdTipoMensajero': idTipoMensajero,
      'NombreCompletoMensajero': nombreMensajero,
      'ListaGuias': listaGuias,
    };
    final compressed = GZipCodec().encode(utf8.encode(jsonEncode(body)));
    return base64Encode(compressed);
  }

  Future<Dio> _controllerPublicClient(
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

  Dio _plainClient(String baseUrl, {required Map<String, String> headers}) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final client = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/json',
          ...headers,
        },
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  Map<String, String> _tokenHeaders(AsignacionAccessTokens tokens) {
    return {
      'HeaderToken': tokens.token,
      'UserName': tokens.userName.replaceAll('\n', ''),
      'Authorization': 'Bearer ${tokens.tokenRefresh}',
    };
  }

  Map<String, dynamic> _decompressBase64Json(String value) {
    final unquoted = value.trim().startsWith('"')
        ? jsonDecode(value.trim()) as String
        : value.trim();
    final bytes = base64Decode(unquoted.replaceAll(RegExp(r'\s'), ''));
    final jsonText = utf8.decode(GZipCodec().decode(bytes));
    return asignacionAsMap(jsonDecode(jsonText));
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return asignacionAsMap(jsonDecode(value));
    }
    return asignacionAsMap(value);
  }

  String _messageFromDio(DioException error, String fallback) {
    final data = error.response?.data;
    try {
      final json = _asMap(data);
      final message = _readString(
        json,
        'message',
        fallbackKeys: ['mensaje', 'Message'],
      ).trim();
      if (message.isNotEmpty) return message;
    } on Object {
      // Continua con el mensaje por defecto, igual que el nativo.
    }
    final message = error.message?.trim();
    return message == null || message.isEmpty ? fallback : message;
  }

  String _readString(
    Map<String, dynamic> json,
    String key, {
    List<String> fallbackKeys = const [],
  }) {
    for (final current in [key, ...fallbackKeys]) {
      final value = json[current];
      if (value != null) return value.toString();
    }
    return '';
  }

  bool _readBool(
    Map<String, dynamic> json,
    String key, {
    List<String> fallbackKeys = const [],
  }) {
    for (final current in [key, ...fallbackKeys]) {
      final value = json[current];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = value?.toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return false;
  }
}
