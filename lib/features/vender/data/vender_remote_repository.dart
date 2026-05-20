import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_id_key_provider.dart';
import '../../login/login.dart';
import '../models/vender_models.dart';

class VenderRemoteRepository {
  VenderRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
  }) : _dio = dio ?? Dio(),
       _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  static const _geoUser = 'user-cognitooauth2';
  static const _geoPassword = 'SW50ZXIyMDIxKg==';
  static const _geoHeaderSecurity = '53Bw898tB4U2CkgQb3x2d9NWRf8d92';
  static const _integrationUser =
      '9PG4iMLN2pRb4rOUA6I9BuImv44U1QrUsxOmzjRYPDPU27rw+CuowP9fem8Xoe1jjIuQqbVCgxMg4TdEU3Ts4g==';
  static const _integrationPassword =
      'HkdqzsVRIzK+7i5Hb62Wlt+cj3Py+fML4ULt7tyUvCUisJhzh/V8kU/TVpzRxL8G';

  final Dio _dio;
  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<Map<String, dynamic>?> fetchPreenvio(
    ControllerApiConfig config,
    String guideNumber,
  ) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty) return null;
    final client = _plainClient(config.preenvioBaseUrl);
    final response = await client.get<dynamic>(
      'Admision/PreEnvioNumero',
      queryParameters: {'PreEnvio': guide},
    );
    return _asMapOrNull(response.data);
  }

  Future<Map<String, dynamic>?> fetchGuideByPreguide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String preguideNumber,
  }) async {
    final guide = preguideNumber.trim();
    if (guide.isEmpty) return null;
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.serviciosInterBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.get<dynamic>(
      'AdmisionMensajeria/ObtenerGuiaNumeroGuia/${Uri.encodeComponent(guide)}',
    );
    return _asMapOrNull(response.data);
  }

  Future<VenderPersonRemoteData> lookupCustomerKey({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String localityId,
    required String identificationType,
    required String document,
    required String phone,
  }) async {
    final token = await fetchGeoToken(config);
    final client = _plainClient(config.geoDireccionBaseUrl);
    final response = await client.get<dynamic>(
      'ClienteContado/ValidarClienteContadoPorTelefono',
      queryParameters: {
        'tipoDocumento': identificationType,
        'numeroDocumento': document,
        'ClienteTelefono': phone,
        'idLocalidad': localityId,
      },
      options: Options(
        headers: _torreHeaders(
          idToken: token,
          encodedUser: _encodedUser(appInformation),
        ),
      ),
    );
    final json = _asMap(response.data);
    return VenderPersonRemoteData.fromJson(json);
  }

  Future<VenderGeoAddress> geocodeAddress({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String cityId,
    required CatalogOption addressType,
    required CatalogOption propertyType,
    required String number,
    required String street,
    required String neighborhood,
    required bool south,
    required bool cityHasGeoReference,
    required bool specialCity,
  }) async {
    final token = await fetchGeoToken(config);
    final client = _plainClient(config.geoDireccionBaseUrl);
    final addressText = _addressText(
      addressType: addressType,
      street: street,
      number: number,
      south: south,
    );
    final response = await client.post<dynamic>(
      'GeoDireccion/ObtenerGeoPorDireccionCiudad',
      data: {
        'direccion': addressText,
        'idCiudad': cityId,
        'idTipoDireccion': int.tryParse(addressType.id) ?? 0,
        'tipoDireccion': addressType.label,
        'numeroDireccion': number,
        'ciudadGeoReferencia': cityHasGeoReference,
        'idCardinalidad': south ? 1 : 0,
        'idTipoVivienda': int.tryParse(propertyType.id) ?? 0,
        'barrioCliente': specialCity ? neighborhood : '',
      },
      options: Options(
        headers: _torreHeaders(
          idToken: token,
          encodedUser: _encodedUser(appInformation),
        ),
      ),
    );
    final address = VenderGeoAddress.fromJson(_asMap(response.data));
    if (!address.isValid) {
      throw const VenderRemoteException(
        'La direccion no pudo ser georreferenciada por Torre Direcciones.',
      );
    }
    return address;
  }

  Future<List<VenderSupply>> refreshSupplies({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required int amount,
  }) async {
    if (amount <= 0) return const [];
    final auth = await _loginIntegration(config);
    final client = _plainClient(config.admisionOfflineBaseUrl);
    final response = await client.post<dynamic>(
      'suministros',
      data: {
        'idDispositivo': appInformation.idDispositivo,
        'idMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
        'cantidadSuministros': amount,
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: _admissionOfflineHeaders(auth, appInformation),
      ),
    );
    final decoded = _decodePossiblyGzip(response.data);
    final json = jsonDecode(decoded);
    final list = _findList(json);
    if (list == null) return const [];
    final supplies = list
        .whereType<Object?>()
        .map(_asMapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(VenderSupply.fromJson)
        .where((supply) => supply.guideNumber.trim().isNotEmpty)
        .toList();
    if (supplies.length != amount) {
      throw const VenderRemoteException(
        'La cantidad de suministros recibida no coincide con la solicitada.',
      );
    }
    return supplies;
  }

  Future<VenderAdmissionSyncResult> synchronizeOfflineAdmission({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required VenderOfflineAdmissionRecord admission,
  }) async {
    final auth = await _loginIntegration(config);
    await _markSupplyUsed(
      config: config,
      auth: auth,
      appInformation: appInformation,
      guideNumber: admission.guideNumber,
    );
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.preenvioBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.post<dynamic>(
      'Admision/CrearAdmisionRecogida/',
      data: _decodeRequestBody(admission.requestJson),
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      return VenderAdmissionSyncResult.fromResponse(
        response.data,
        fallbackGuideNumber: admission.guideNumber,
      );
    }
    if (statusCode == 409 || statusCode == 412) {
      throw VenderRemoteException(
        'La guia ${admission.guideNumber} esta duplicada en la base remota.',
      );
    }
    throw VenderRemoteException(
      'No fue posible sincronizar la guia ${admission.guideNumber}. Codigo HTTP $statusCode.',
    );
  }

  Future<VenderPickupExecutionResult> executePickup({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required VenderCollectionState collection,
  }) async {
    if (collection.idPickup <= 0) {
      throw const VenderRemoteException(
        'La recogida no tiene id remoto para facturar.',
      );
    }
    if (collection.idPreInvoice <= 0) {
      throw const VenderRemoteException(
        'La recogida no tiene prefactura remota para facturar.',
      );
    }
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.controllerBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.post<dynamic>(
      'Recogidas/EjecutarRecogida',
      data: _executePickupBody(
        appInformation: appInformation,
        collection: collection,
      ),
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300 && response.data != null) {
      return VenderPickupExecutionResult.fromResponse(response.data);
    }
    throw VenderRemoteException(
      'No fue posible ejecutar la recogida. Codigo HTTP $statusCode.',
    );
  }

  Future<void> _markSupplyUsed({
    required ControllerApiConfig config,
    required _IntegrationAuth auth,
    required AppInformation appInformation,
    required String guideNumber,
  }) async {
    final supply = int.tryParse(guideNumber.replaceAll(RegExp(r'[^0-9]'), ''));
    if (supply == null || supply <= 0) {
      throw VenderRemoteException(
        'El suministro $guideNumber no es valido para sincronizar.',
      );
    }
    final client = _plainClient(config.admisionOfflineBaseUrl);
    final response = await client.post<dynamic>(
      'suministros/usado',
      data: {'idSuministro': supply},
      options: Options(
        headers: _admissionOfflineHeaders(auth, appInformation),
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) return;
    throw VenderRemoteException(
      'No fue posible marcar el suministro $guideNumber como usado. Codigo HTTP $statusCode.',
    );
  }

  Future<String> fetchGeoToken(ControllerApiConfig config) async {
    final client = _plainClient(config.geoRefTokenBaseUrl);
    final response = await client.post<dynamic>(
      'autorizador',
      data: {'Usuario': _geoUser, 'Password': _geoPassword},
      options: Options(headers: {'HeaderSecurity': _geoHeaderSecurity}),
    );
    final token = _findString(_asMap(response.data), const [
      'IdToken',
      'idToken',
      'token',
      'Token',
    ]);
    if (token.trim().isEmpty) {
      throw const VenderRemoteException(
        'No fue posible obtener token de Torre Direcciones.',
      );
    }
    return token;
  }

  Future<_IntegrationAuth> _loginIntegration(ControllerApiConfig config) async {
    final client = _plainClient(config.loginIntegrationBaseUrl);
    final response = await client.post<dynamic>(
      'Autenticacion/Login',
      data: {'UserName': _integrationUser, 'Password': _integrationPassword},
    );
    final json = _asMap(response.data);
    final token = _findString(json, const ['Token', 'token']);
    final userName = _findString(json, const ['UserName', 'userName']);
    if (token.trim().isEmpty || userName.trim().isEmpty) {
      throw const VenderRemoteException(
        'No fue posible autenticar LoginIntegracion para suministros.',
      );
    }
    return _IntegrationAuth(token: token, userName: userName);
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

  Map<String, Object> _torreHeaders({
    required String idToken,
    required String encodedUser,
  }) {
    return {
      'Authorization': idToken,
      'usuario': encodedUser,
      'IdAplicacion': 9,
    };
  }

  Map<String, Object> _admissionOfflineHeaders(
    _IntegrationAuth auth,
    AppInformation appInformation,
  ) {
    return {
      'UserName': auth.userName,
      'Token': auth.token,
      'Usuario': appInformation.idUsuario,
      'IdUsuario': appInformation.idUsuario,
      'IdCentroServicio': appInformation.idCentroServicio,
      'NombreCentroServicio': _sanitizeHeaderValue(
        appInformation.nombreCentroServicio,
      ),
      'IdAplicativoOrigen': '9',
      'Identificacion': appInformation.identificacionUsuario,
      'Content-Type': 'application/json',
      'Accept': 'text/json',
    };
  }

  String _sanitizeHeaderValue(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final isControl = codeUnit <= 0x1f && codeUnit != 0x09;
      if (!isControl && codeUnit < 0x7f) buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  String _encodedUser(AppInformation appInformation) {
    return base64Encode(utf8.encode(appInformation.idUsuario));
  }

  String _addressText({
    required CatalogOption addressType,
    required String street,
    required String number,
    required bool south,
  }) {
    final parts = <String>[
      addressType.label,
      street,
      '#',
      number,
      if (south) 'SUR',
    ].where((value) => value.trim().isNotEmpty).join(' ');
    return parts.trim();
  }

  String _decodePossiblyGzip(dynamic data) {
    final bytes = data is List<int> ? data : utf8.encode(data.toString());
    try {
      return utf8.decode(GZipCodec().decode(bytes));
    } on Object {
      return utf8.decode(bytes);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    final map = _asMapOrNull(data);
    if (map != null) return map;
    throw const VenderRemoteException('Respuesta remota invalida en Vender.');
  }

  Object _decodeRequestBody(String requestJson) {
    final decoded = jsonDecode(requestJson);
    if (decoded is Map || decoded is List) return decoded;
    throw const VenderRemoteException(
      'La admision offline tiene un JSON invalido para sincronizar.',
    );
  }

  Map<String, dynamic>? _asMapOrNull(dynamic data) {
    final decoded = data is String && data.trim().isNotEmpty
        ? jsonDecode(data)
        : data;
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Map<String, Object?> _executePickupBody({
    required AppInformation appInformation,
    required VenderCollectionState collection,
  }) {
    return _withoutNullValues({
      'recogida': _withoutNullValues({
        'IdSolicitudRecogida': collection.idPickup,
        'NumeroPiezas': 0,
        'LocalidadCambio': appInformation.idCiudad,
        'IdCiudad': appInformation.idCiudad,
        'Longitud': '',
        'Latitud': '',
        'IdMotivo': 0,
        'DescripcionMotivo': '',
        'DocPersonaResponsable': appInformation.identificacionUsuario,
        'PlacaVehiculo': '',
        'TieneCodigoQR': false,
        'TipoRecogida': 2,
        'IdAplicacion': 9,
        'Mensajero': {'idMensajer': appInformation.idMensajero},
        'ValorTotalRecogida': collection.totalToCharge,
        'ValorRecogida': collection.pickupValue,
        'ValorPropina': 0,
        'IdPreFactura': collection.idPreInvoice,
      }),
      'idSistema': 0,
      'tipoNovedad': 0,
      'idPreFactura': collection.idPreInvoice,
    });
  }

  Map<String, Object?> _withoutNullValues(Map<String, Object?> source) {
    final result = <String, Object?>{};
    for (final entry in source.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Map<String, Object?>) {
        result[entry.key] = _withoutNullValues(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
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

  List<dynamic>? _findList(dynamic json) {
    if (json is List) return json;
    if (json is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'Data',
        'suministros',
        'Suministros',
        'result',
        'Result',
        'response',
        'Response',
      ]) {
        final value = json[key];
        final list = _findList(value);
        if (list != null) return list;
      }
      for (final value in json.values) {
        final list = _findList(value);
        if (list != null) return list;
      }
    } else if (json is Map) {
      return _findList(Map<String, dynamic>.from(json));
    }
    return null;
  }
}

class _IntegrationAuth {
  const _IntegrationAuth({required this.token, required this.userName});

  final String token;
  final String userName;
}
