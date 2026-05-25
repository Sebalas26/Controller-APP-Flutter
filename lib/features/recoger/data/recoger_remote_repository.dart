import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_id_key_provider.dart';
import '../../login/login.dart';
import '../../vender/models/vender_models.dart';
import '../models/recoger_models.dart';

class RecogerRemoteRepository {
  RecogerRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
  }) : _dio = dio ?? Dio(),
       _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  final Dio _dio;
  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<List<RecogidaItem>> fetchAvailable({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'Recogidas/ObtenerRecogidasDisponibles/${Uri.encodeComponent(appInformation.idCiudad)}',
      queryParameters: {
        'identificacionMensajero': appInformation.identificacionUsuario,
      },
    );
    return _pickupList(response.data);
  }

  Future<List<RecogidaItem>> fetchReserved({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final client = await _recogidasClient(config, appInformation);
    final response = await client.get<dynamic>(
      'Recogidas/ObtenerRecogidasReservadasMensajero/${Uri.encodeComponent(appInformation.identificacionUsuario)}',
      options: Options(validateStatus: (status) => status != null && status < 600),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw RecogidaException(
        'No fue posible consultar recogidas reservadas. HTTP $status.',
      );
    }
    return _pickupList(response.data);
  }

  Future<List<RecogidaItem>> fetchEffective({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'Recogidas/ObtenerRecogidasEfectivasMensajero/${Uri.encodeComponent(appInformation.identificacionUsuario)}',
    );
    return _pickupList(response.data)
        .map((item) => RecogidaItem.fromJson({...item.raw, 'icon': 'sincronized'}))
        .toList();
  }

  Future<List<RecogidaMotivo>> fetchCancelMotives({
    required ControllerApiConfig config,
    required AppInformation appInformation,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'Recogidas/ObtenerMotivoEstadoSolRecogidaXActor/2',
    );
    return (_findList(response.data) ?? const [])
        .map(_mapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(RecogidaMotivo.fromJson)
        .toList();
  }

  Future<void> assignPickup({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required RecogidaItem pickup,
    String latitude = '',
    String longitude = '',
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.post<dynamic>(
      'Recogidas/AsignarRecogida',
      data: {
        'IdSolicitudRecogida': int.tryParse(pickup.id) ?? pickup.id,
        'LocalidadCambio': appInformation.idCiudad,
        'DocPersonaResponsable': appInformation.identificacionUsuario,
        'EstadoRecogida': 1,
        'PlacaVehiculo': '',
        'Latitud': latitude,
        'Longitud': longitude,
      },
      options: Options(validateStatus: (status) => status != null && status < 600),
    );
    final status = response.statusCode ?? 0;
    final body = response.data?.toString().trim().toLowerCase() ?? '';
    if (status >= 200 && status < 300) return;
    if (status == 200 && body == 'true') return;
    throw RecogidaException('Error asignando Recogida. HTTP $status.');
  }

  Future<List<RecogidaPreenvio>> fetchPreguides({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String pickupId,
  }) async {
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'Admision/PreEnviosYAdmisionesRecogidas',
      queryParameters: {'idRecogida': pickupId},
    );
    return (_findList(response.data) ?? const [])
        .map(_mapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(RecogidaPreenvio.fromJson)
        .toList();
  }

  Future<RecogidaPreenvio?> searchPreguide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String preguideNumber,
  }) async {
    final guide = preguideNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (guide.isEmpty) return null;
    final client = await _controllerClient(config, appInformation);
    final response = await client.get<dynamic>(
      'Admision/PreEnvioNumero',
      queryParameters: {'PreEnvio': guide},
      options: Options(validateStatus: (status) => status != null && status < 600),
    );
    if ((response.statusCode ?? 0) == 404 || response.data == null) return null;
    final json = _mapOrNull(response.data);
    return json == null ? null : RecogidaPreenvio.fromJson(json);
  }

  Future<VenderPickupExecutionResult> executePickup({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required List<RecogidaPreenvio> preguides,
    required String pickupId,
    required int preInvoiceId,
    int selectedPaymentMethodId = VenderPaymentMethods.cash,
  }) async {
    final state = VenderCollectionState(
      guides: preguides
          .map(
            (preguide) => VenderCollectionGuide(
              guideNumber: preguide.guideNumber,
              paymentMethodId: preguide.paymentMethodId,
              paymentMethodLabel: preguide.paymentMethod,
              isCollectPayment:
                  preguide.paymentMethodId == VenderPaymentMethods.collect,
              totalValue: preguide.value,
              transportValue: preguide.value,
              insuranceValue: 0,
              senderName: preguide.sender,
              senderDocument: '',
              senderPhone: '',
              senderEmail: '',
              recipientName: preguide.recipient,
              idPickup: int.tryParse(pickupId) ?? 0,
              idPreInvoice: preInvoiceId,
            ),
          )
          .toList(),
      selectedPaymentMethodId: selectedPaymentMethodId,
      confirmed: true,
    );
    return _executePickupState(
      config: config,
      appInformation: appInformation,
      collection: state,
    );
  }

  Future<VenderPickupExecutionResult> _executePickupState({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required VenderCollectionState collection,
  }) async {
    if (collection.idPickup <= 0) {
      throw const RecogidaException('La recogida no tiene id remoto.');
    }
    if (collection.idPreInvoice <= 0) {
      throw const RecogidaException('La recogida no tiene prefactura remota.');
    }
    final client = await _controllerClient(config, appInformation);
    final response = await client.post<dynamic>(
      'Recogidas/EjecutarRecogida',
      data: {
        'recogida': {
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
        },
        'idSistema': 0,
        'tipoNovedad': 0,
        'idPreFactura': collection.idPreInvoice,
      },
      options: Options(validateStatus: (status) => status != null && status < 600),
    );
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300 && response.data != null) {
      return VenderPickupExecutionResult.fromResponse(response.data);
    }
    throw RecogidaException(
      'No fue posible ejecutar la recogida. Codigo HTTP $status.',
    );
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

  Future<Dio> _recogidasClient(
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

  List<RecogidaItem> _pickupList(Object? data) {
    return (_findList(data) ?? const [])
        .map(_mapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(RecogidaItem.fromJson)
        .where((item) => item.id.trim().isNotEmpty)
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
    } else if (data is String && data.trim().isNotEmpty) {
      return _findList(jsonDecode(data));
    }
    return null;
  }

  Map<String, dynamic>? _mapOrNull(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) return _mapOrNull(data.first);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }
}
