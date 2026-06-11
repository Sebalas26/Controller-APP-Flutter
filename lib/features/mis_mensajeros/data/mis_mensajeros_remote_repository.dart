import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../models/mis_mensajeros_models.dart';

class MisMensajerosRemoteRepository {
  MisMensajerosRemoteRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<MisMensajero>> getApoyos({
    required ControllerApiConfig config,
    required MisMensajerosTokens tokens,
    required String identificacionUsuario,
  }) async {
    try {
      final response = await _client(
        config,
        tokens,
      ).get<dynamic>('MisMensajeros/ObtenerMensajerosPorCentroServicio');
      final current = identificacionUsuario.trim();
      final supports = misMensajerosAsMapList(response.data)
          .map(MisMensajero.fromJson)
          .where((item) => item.identificacion.trim() != current)
          .toList(growable: false);
      return _sortSupports(supports);
    } on DioException catch (error) {
      throw MisMensajerosException(
        _messageFromDio(error, 'Hubo una falla al consultar los apoyos'),
      );
    }
  }

  Future<GenerateOtpResult> generateOtpCode({
    required ControllerApiConfig config,
    required MisMensajerosTokens tokens,
    required int centroServicio,
    required String numeroTelefono,
    required int idRolApp,
  }) async {
    try {
      final response = await _client(config, tokens).post<dynamic>(
        'MisMensajeros/GenerarOtpCreacionApoyo',
        data: {
          'centroServicio': centroServicio,
          'numeroTelefono': numeroTelefono,
          'IdRolApoyo': tokens.idRolApoyo,
          'idRolApp': idRolApp,
        },
      );
      final result = GenerateOtpResult.fromData(response.data);
      if (!result.success) {
        throw MisMensajerosException(
          result.mensajeValidacion.trim().isEmpty
              ? 'No fue posible generar el código OTP.'
              : result.mensajeValidacion,
        );
      }
      return result;
    } on DioException catch (error) {
      throw MisMensajerosException(
        _messageFromDio(error, 'No fue posible generar el código OTP.'),
      );
    }
  }

  Future<bool> updateSupportState({
    required ControllerApiConfig config,
    required MisMensajerosTokens tokens,
    required String identificacionApoyo,
    required String identificacionResponsable,
    required bool active,
  }) async {
    try {
      final response = await _client(config, tokens).post<dynamic>(
        'MisMensajeros/ActualizarEstadoUsuarioApoyo',
        data: {
          'Identificacion': identificacionApoyo,
          'IdUsuResponsableCambio': identificacionResponsable,
          'EsActivo': active,
        },
      );
      if (_readBoolResponse(response.data)) return true;
      throw const MisMensajerosException('Falla consulta');
    } on DioException catch (error) {
      throw MisMensajerosException(_messageFromDio(error, 'Falla consulta'));
    }
  }

  Future<String> sendPushNotification({
    required String title,
    required String body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 'Notificación Push enviada';
  }

  Dio _client(ControllerApiConfig config, MisMensajerosTokens tokens) {
    final baseUrl = config.apoyosBaseUrl.endsWith('/')
        ? config.apoyosBaseUrl
        : '${config.apoyosBaseUrl}/';
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/json',
          'HeaderToken': tokens.token,
          'UserName': tokens.userName.replaceAll('\n', ''),
          'Authorization': 'Bearer ${tokens.tokenRefresh}',
          'IdRolApoyo': tokens.idRolApoyo.toString(),
        },
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  List<MisMensajero> _sortSupports(List<MisMensajero> supports) {
    final ordered = [...supports];
    ordered.sort((left, right) {
      if (left.usuarioActivo != right.usuarioActivo) {
        return left.usuarioActivo ? -1 : 1;
      }
      return left.nombre.toLowerCase().compareTo(right.nombre.toLowerCase());
    });
    return ordered;
  }

  bool _readBoolResponse(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
      try {
        return _readBoolResponse(jsonDecode(value));
      } on Object {
        return false;
      }
    }
    final json = misMensajerosAsMap(value);
    if (json.isNotEmpty) {
      return _readBoolResponse(
        json['resultado'] ?? json['Resultado'] ?? json['success'],
      );
    }
    return false;
  }

  String _messageFromDio(DioException error, String fallback) {
    final data = error.response?.data;
    try {
      final json = misMensajerosAsMap(data);
      final message =
          [
                json['message'],
                json['mensaje'],
                json['Message'],
                json['Mensaje'],
                json['mensajeValidacion'],
              ]
              .whereType<Object?>()
              .map((item) => item?.toString().trim() ?? '')
              .firstWhere((item) => item.isNotEmpty, orElse: () => '');
      if (message.isNotEmpty) return message;
    } on Object {
      // Mantiene fallback como en el nativo cuando no parsea el error.
    }
    final message = error.message?.trim();
    return message == null || message.isEmpty ? fallback : message;
  }
}
