part of '../login_data.dart';

class ControllerApiClient {
  ControllerApiClient({Dio? dio, ControllerIdKeyProvider? idKeyProvider})
    : _httpClient = ControllerHttpClient(dio: dio),
      _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  static const appName = ControllerHttpClient.appName;
  static const _authPath = 'Seguridad/AuthenticaUsuarioControllerApp';
  static const _versionPath =
      'ParametrosFramework/ConsultarParametrosFramework/VPStoreAppControl';
  static const _userInfoPath =
      'OperacionUrbanaController/ObtenerInformacionUsuarioControllerApp';
  static const _devicePath =
      'NotificacionesController/RegistrarDispositivoMovil';
  static const _schemaPath = 'SincronizadorDatos/ObtenerEsquema/true';
  static const _productSchemaPath =
      'SincronizadorDatos/ObtenerEsquemaProducto/Producto_PRD';
  static const _torreTokenPath = 'autorizador';
  static const _torreSchemaPath = 'Sincronizacion/ObtenerTablas';
  static const _torreTokenUser = 'user-cognitooauth2';
  static const _torreTokenPassword = 'SW50ZXIyMDIxKg==';
  static const _torreHeaderSecurity = '53Bw898tB4U2CkgQb3x2d9NWRf8d92';

  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<String> fetchLatestAppVersion(ControllerApiConfig config) async {
    final response = await _client(
      config.controllerBaseUrl,
    ).get<dynamic>(_versionPath, options: _plainResponse);
    return _responseText(response.data);
  }

  Future<LoginCredential> authenticate({
    required ControllerApiConfig config,
    required CredentialRequest request,
  }) async {
    final response = await _client(
      config.authenticationBaseUrl,
    ).post<dynamic>(_authPath, data: request.toJson(), options: _plainResponse);

    return LoginCredential.fromCompressedResponse(_responseText(response.data));
  }

  Future<UserInfo> getUserInfo({
    required ControllerApiConfig config,
    required String identification,
    required AppInformation appInformation,
  }) async {
    final client = await _publicClient(config, appInformation: appInformation);
    final response = await client.get<dynamic>(
      '$_userInfoPath/${Uri.encodeComponent(identification)}',
    );
    final json = _asMap(response.data);
    if (json == null) {
      throw LoginException('No fue posible leer la informacion del usuario.');
    }
    return UserInfo.fromJson(json);
  }

  Future<String> registerMobileDevice({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String androidId,
    String firebaseToken = '',
  }) async {
    final response =
        await _client(
          config.controllerBaseUrl,
          appInformation: appInformation,
        ).post<dynamic>(
          _devicePath,
          data: {
            'IdDispositivo': 0,
            'SistemaOperativo': 'Android',
            'TokenDispositivo': firebaseToken,
            'TipoDispositivo': 'DEM',
            'IdCiudad': appInformation.idCiudad,
            'NumeroImei': androidId,
          },
          options: _plainResponse,
        );
    return _responseText(response.data);
  }

  Future<List<SyncSchema>> fetchSyncSchemas({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final client = await _publicClient(config, appInformation: appInformation);
    final response = await client.get<dynamic>(_schemaPath);
    return _readSchemaList(response.data);
  }

  Future<List<SyncSchema>> fetchProductSchemas({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final response = await _client(
      config.controllerBaseUrl,
      appInformation: appInformation,
    ).get<dynamic>(_productSchemaPath);
    return _readSchemaList(response.data);
  }

  Future<SyncBatchRecord> fetchTableBatch({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String tableName,
    required int batchSize,
    required String filter,
    required String anchor,
    required int currentBatch,
    required int totalBatch,
  }) async {
    final endpoint = [
      'SincronizadorDatos',
      'ObtenerDatosTablaString',
      tableName,
      batchSize.toString(),
      filter.isEmpty ? '_' : filter,
      anchor.isEmpty ? '_' : anchor,
      currentBatch.toString(),
      totalBatch.toString(),
    ].map(Uri.encodeComponent).join('/');

    final client = await _publicClient(config, appInformation: appInformation);
    final response = await client.get<dynamic>(endpoint);
    final json = _asMap(response.data);
    if (json == null) {
      throw LoginException('Respuesta de sincronizacion invalida.');
    }
    return SyncBatchRecord.fromJson(json);
  }

  Future<String> fetchTorreDireccionesToken(ControllerApiConfig config) async {
    final response = await _client(config.geoRefTokenBaseUrl).post<dynamic>(
      _torreTokenPath,
      data: {'Usuario': _torreTokenUser, 'Password': _torreTokenPassword},
      options: Options(headers: {'HeaderSecurity': _torreHeaderSecurity}),
    );
    final json = _asMap(response.data);
    final token = _findString(json, const [
      'IdToken',
      'idToken',
      'Token',
      'token',
    ]);
    if (token.trim().isEmpty) {
      throw const LoginException(
        'No fue posible obtener token de Torre Direcciones.',
      );
    }
    return token;
  }

  Future<List<TorreDirectionSchema>> fetchTorreDirectionSchemas({
    required ControllerApiConfig config,
    required String idToken,
  }) async {
    final response = await _client(config.geoDireccionBaseUrl).get<dynamic>(
      _torreSchemaPath,
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );
    final list = response.data is List
        ? response.data as List
        : jsonDecode(_responseText(response.data)) as List;
    return list
        .whereType<Object?>()
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(TorreDirectionSchema.fromJson)
        .where((schema) => schema.tableName.trim().isNotEmpty)
        .toList();
  }

  Dio _client(
    String baseUrl, {
    AppInformation? appInformation,
    String idKey = '',
  }) {
    return _httpClient.client(
      baseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
  }

  Future<Dio> _publicClient(
    ControllerApiConfig config, {
    AppInformation? appInformation,
  }) async {
    final idKey = await _idKeyProvider.createIdKey(config);
    return _client(
      config.controllerBaseUrl,
      appInformation: appInformation,
      idKey: idKey,
    );
  }

  List<SyncSchema> _readSchemaList(dynamic data) {
    final list = data is List ? data : jsonDecode(_responseText(data)) as List;
    return list
        .whereType<Object?>()
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(SyncSchema.fromJson)
        .toList();
  }

  String _findString(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return '';
    for (final key in keys) {
      final value =
          json[key] ?? json[_lowerFirst(key)] ?? json[key.toLowerCase()];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
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

  Options get _plainResponse => _httpClient.plainResponse;
}
