import 'dart:convert';

import 'package:dio/dio.dart';

import '../native/controller_native_bridge.dart';
import '../network/controller_api_config.dart';
import '../network/controller_http_client.dart';
import 'controller_crypto.dart';

class ControllerIdKeyProvider {
  ControllerIdKeyProvider({
    Dio? dio,
    ControllerNativeBridge? nativeBridge,
    ControllerCrypto? crypto,
  }) : _httpClient = ControllerHttpClient(dio: dio),
       _nativeBridge = nativeBridge ?? ControllerNativeBridge(),
       _crypto = crypto ?? ControllerCrypto();

  static const _tokenPath = 'Autenticacion/GenerarTokenTemporal';

  final ControllerHttpClient _httpClient;
  final ControllerNativeBridge _nativeBridge;
  final ControllerCrypto _crypto;

  Future<String> createIdKey(ControllerApiConfig config) async {
    final token = await _fetchTemporalToken(config);
    final keySecret = await _nativeBridge.aesKeySecret();
    final saltSecret = await _nativeBridge.aesSaltSecret();
    if (keySecret.trim().isEmpty || saltSecret.trim().isEmpty) {
      throw StateError('No se pudieron leer las llaves AES para IdKey.');
    }

    return _crypto.encryptControllerIdKey(
      token: token,
      encryptionKeyBase64: keySecret,
      saltBase64: saltSecret,
    );
  }

  Future<String> _fetchTemporalToken(ControllerApiConfig config) async {
    final response = await _httpClient
        .client(config.loginIntegrationBaseUrl)
        .post<dynamic>(_tokenPath, options: _httpClient.plainResponse);
    return _readTemporalToken(response.data);
  }

  String _readTemporalToken(dynamic data) {
    final decoded = _decode(data);
    final token = _findToken(decoded);
    return token?.trim() ?? '';
  }

  Object? _decode(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      return jsonDecode(data);
    }
    return data;
  }

  String? _findToken(Object? value) {
    if (value is Map) {
      final direct = value['Token'] ?? value['token'];
      if (direct != null) return direct.toString();
      for (final child in value.values) {
        final token = _findToken(child);
        if (token != null && token.trim().isNotEmpty) return token;
      }
    }
    if (value is List) {
      for (final child in value) {
        final token = _findToken(child);
        if (token != null && token.trim().isNotEmpty) return token;
      }
    }
    return null;
  }
}
