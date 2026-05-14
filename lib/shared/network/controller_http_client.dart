import 'package:dio/dio.dart';

abstract class ControllerHeaderSource {
  String get idUsuario;
  String get idCentroServicio;
  String get nombreCentroServicio;
  String get identificacionUsuario;
}

class ControllerHttpClient {
  ControllerHttpClient({Dio? dio}) : _dio = dio ?? Dio();

  static const appName = 'Controller APP';
  static const appOrigin = '9';

  final Dio _dio;

  Options get plainResponse => Options(responseType: ResponseType.plain);

  Dio client(
    String baseUrl, {
    ControllerHeaderSource? headerSource,
    String idKey = '',
  }) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final client = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: _headers(headerSource, idKey),
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  Map<String, String> _headers(ControllerHeaderSource? source, String idKey) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'text/json',
      'IdAplicativoOrigen': appOrigin,
      if (idKey.trim().isNotEmpty) 'IdKey': idKey,
      if (source != null) ...{
        'Usuario': source.idUsuario,
        'IdUsuario': source.idUsuario,
        'IdCentroServicio': source.idCentroServicio,
        'NombreCentroServicio': _cleanHeader(source.nombreCentroServicio),
        'Identificacion': source.identificacionUsuario,
      },
    };
  }

  String _cleanHeader(String value) {
    return value.runes
        .where((code) => (code > 31 || code == 9) && code < 127)
        .map(String.fromCharCode)
        .join();
  }
}
