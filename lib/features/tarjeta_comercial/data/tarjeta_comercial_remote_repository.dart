import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../login/login.dart';
import '../models/tarjeta_comercial_models.dart';

class TarjetaComercialRemoteRepository {
  TarjetaComercialRemoteRepository({Dio? dio, ControllerHttpClient? httpClient})
    : _httpClient = httpClient ?? ControllerHttpClient(dio: dio);

  final ControllerHttpClient _httpClient;

  Future<void> registerPresentation({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String phone,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    try {
      final client = _httpClient.client(
        config.controllerBaseUrl,
        headerSource: appInformation,
      );
      final response = await client.get<dynamic>(
        'Mensajero/InsertarPresentacion/${Uri.encodeComponent(cleanPhone)}',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw const TarjetaComercialException(
          'No fue posible registrar la presentación comercial.',
        );
      }
    } on DioException catch (error) {
      throw TarjetaComercialException(
        _messageFromDio(
          error,
          'No fue posible registrar la presentación comercial.',
        ),
      );
    }
  }

  String _messageFromDio(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in ['Message', 'message', 'Mensaje', 'mensaje']) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    final text = data?.toString().trim();
    if (text != null && text.isNotEmpty && text.length < 180) return text;
    return fallback;
  }
}
