import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_id_key_provider.dart';
import '../../login/login.dart';
import '../models/anular_guia_models.dart';

class AnularGuiaRemoteRepository {
  AnularGuiaRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
  }) : _dio = dio ?? Dio(),
       _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  final Dio _dio;
  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<AnularGuide?> consultarEstadoGuia({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String numeroGuia,
  }) async {
    try {
      final client = await _controllerPublicClient(config, appInformation);
      final response = await client.get<dynamic>(
        'LogisticaInversa/ObtenerMensajeriaUltimoEstado/$numeroGuia',
        options: _adminOptions,
      );
      final json = _asMap(response.data);
      final guideJson = anularAsMap(json['Guia']);
      if (guideJson.isEmpty) return null;
      return AnularGuide.fromJson(guideJson);
    } on DioException catch (error) {
      throw AnularGuiaException(
        _messageFromDio(error, 'La guía no existe o no pudo consultarse.'),
      );
    }
  }

  Future<List<AnulacionReason>> obtenerMotivosAnulacion({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    try {
      final client = _controllerClient(config, appInformation);
      final response = await client.get<dynamic>(
        'ControlCuentas/ObtenerMotivosAnulacion',
        options: _adminOptions,
      );
      return anularAsMapList(response.data)
          .map(AnulacionReason.fromJson)
          .where((reason) => reason.id == 1 || reason.id == 10)
          .toList(growable: false);
    } on DioException catch (error) {
      throw AnularGuiaException(
        _messageFromDio(error, 'No fue posible consultar motivos.'),
      );
    }
  }

  Future<RepresentativePhone> obtenerNumeroRepresentante({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required int idCentroServicio,
  }) async {
    try {
      final client = _controllerClient(config, appInformation);
      final response = await client.get<dynamic>(
        'CentrosServicio/ObtenerInformacionCentroServicioPorId',
        queryParameters: {'idCentroServicio': idCentroServicio},
        options: _adminOptions,
      );
      return RepresentativePhone.fromJson(anularAsMap(response.data));
    } on DioException catch (error) {
      throw AnularGuiaException(
        _messageFromDio(
          error,
          'No fue posible consultar el número registrado.',
        ),
      );
    }
  }

  Future<bool> guardarNumeroRepresentante({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String numeroGuia,
    required String numeroRegistrado,
    required String numeroEnvio,
  }) async {
    try {
      final client = _controllerClient(config, appInformation);
      final response = await client.post<dynamic>(
        'CentrosServicio/GuardarAuditoriaCambioNumeroAnulacion',
        data: {
          'NumeroGuia': numeroGuia,
          'IdUsuario': int.tryParse(appInformation.idMensajero) ?? 0,
          'IdCentroServicio':
              int.tryParse(appInformation.idCentroServicio) ?? 0,
          'Marcacion': 'APP',
          'NumeroCelularRegistrado': numeroRegistrado.trim().isEmpty
              ? '0'
              : numeroRegistrado.trim(),
          'NumeroCelularEnvio': numeroEnvio.trim(),
          'Modificado': 'true',
        },
      );
      return _readBoolResponse(response.data);
    } on DioException catch (error) {
      throw AnularGuiaException(
        _messageFromDio(error, 'El número no pudo guardarse.'),
      );
    }
  }

  Future<AnularGuideResult> anularGuia({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required AnularGuide guide,
  }) async {
    try {
      final client = await _controllerPublicClient(config, appInformation);
      final response = await client.post<dynamic>(
        'LogisticaInversa/AnularGuia',
        data: {
          'IdCodigoUsuario': appInformation.idUsuario,
          'Observaciones': 'Anulación desde APP',
          'TipoNovedad': 1,
          'NumeroGuia': guide.numeroGuia,
          'IdMotivoAnulacion': 1,
          'Descripcion': 'Anulacion',
          'TrazaGuia': {
            'Ciudad': appInformation.nombreCiudad,
            'IdCiudad': appInformation.idCiudad,
            'ReversaEstado': false,
          },
          'IdCaja': int.tryParse(appInformation.idCaja) ?? 0,
        },
      );
      return AnularGuideResult.fromJson(anularAsMap(response.data));
    } on DioException catch (error) {
      throw AnularGuiaException(
        _messageFromDio(error, 'No fue posible anular la guía.'),
      );
    }
  }

  Future<String> obtenerPlantillaCodigoSms(ControllerApiConfig config) async {
    return _getSmsText(
      config,
      'Mensajes/ObtenerMensajeSMS/SMS_TokenAnulaci%C3%B3n',
      'No fue posible generar el código de confirmación.',
    );
  }

  Future<String> obtenerPlantillaAnulacionExitosa(
    ControllerApiConfig config,
  ) async {
    return _getSmsText(
      config,
      'Mensajes/ObtenerMensajeSMS/SMS_Anulaci%C3%B3nExitosa',
      'No fue posible consultar el mensaje de anulación exitosa.',
    );
  }

  Future<bool> enviarSms({
    required ControllerApiConfig config,
    required String numeroTelefono,
    required String mensaje,
  }) async {
    final phone = numeroTelefono.trim();
    final text = mensaje.trim().replaceAll('"', '');
    if (phone.isEmpty || text.isEmpty) return false;
    try {
      final client = _smsClient(config);
      await client.post<dynamic>(
        'Mensajes/EnviarSMS/$phone/${Uri.encodeComponent(text)}',
      );
      return true;
    } on DioException {
      return false;
    }
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

  Dio _controllerClient(
    ControllerApiConfig config,
    AppInformation appInformation,
  ) {
    return _httpClient.client(
      config.controllerBaseUrl,
      headerSource: appInformation,
    );
  }

  Dio _smsClient(ControllerApiConfig config) {
    final baseUrl = config.mensajeTextoBaseUrl.endsWith('/')
        ? config.mensajeTextoBaseUrl
        : '${config.mensajeTextoBaseUrl}/';
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'text/json'},
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  Future<String> _getSmsText(
    ControllerApiConfig config,
    String path,
    String fallbackMessage,
  ) async {
    try {
      final response = await _smsClient(
        config,
      ).get<dynamic>(path, options: Options(responseType: ResponseType.plain));
      final text = _readText(response.data);
      if (text.trim().isEmpty) throw AnularGuiaException(fallbackMessage);
      return text;
    } on DioException catch (error) {
      throw AnularGuiaException(_messageFromDio(error, fallbackMessage));
    }
  }

  Options get _adminOptions {
    return Options(headers: const {'Usuario': 'admin', 'usuario': 'admin'});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    final decoded = _decode(data);
    return anularAsMap(decoded);
  }

  dynamic _decode(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  String _readText(dynamic data) {
    if (data == null) return '';
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        try {
          return jsonDecode(trimmed).toString();
        } catch (_) {
          return trimmed.replaceAll('"', '');
        }
      }
      return trimmed;
    }
    return data.toString();
  }

  bool _readBoolResponse(dynamic data) {
    if (data is bool) return data;
    final decoded = _decode(data);
    if (decoded is bool) return decoded;
    if (decoded is Map) {
      return anularReadBool(anularAsMap(decoded), 'Resultado') ||
          anularReadBool(anularAsMap(decoded), 'respuesta') ||
          anularReadBool(anularAsMap(decoded), 'Response');
    }
    final text = (decoded ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }

  String _messageFromDio(DioException error, String fallback) {
    final data = _decode(error.response?.data);
    final json = anularAsMap(data);
    for (final key in const ['Mensaje', 'mensaje', 'Message', 'message']) {
      final message = anularReadString(json, key);
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }
}
