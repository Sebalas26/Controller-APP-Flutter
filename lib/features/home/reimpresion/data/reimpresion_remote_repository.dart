import 'package:dio/dio.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../../shared/network/controller_http_client.dart';
import '../../../../shared/security/controller_id_key_provider.dart';
import '../../../login/login.dart';
import '../../../vender/impresion/impresion.dart';

class ReimpresionRemoteRepository {
  ReimpresionRemoteRepository({
    Dio? dio,
    ControllerHttpClient? httpClient,
    ControllerIdKeyProvider? idKeyProvider,
  }) : _httpClient = httpClient ?? ControllerHttpClient(dio: dio),
       _idKeyProvider = idKeyProvider ?? ControllerIdKeyProvider(dio: dio);

  final ControllerHttpClient _httpClient;
  final ControllerIdKeyProvider _idKeyProvider;

  Future<VenderPrintLabel> fetchLabelByGuide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String guideNumber,
  }) async {
    final guide = guideNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (guide.isEmpty) {
      throw const VenderPrintException('Ingresa el numero de guia.');
    }
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.serviciosInterBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    final response = await client.get<dynamic>(
      'AdmisionMensajeria/ObtenerGuiaNumeroGuia/${Uri.encodeComponent(guide)}',
    );
    final payload = printJsonMap(response.data);
    if (payload.isEmpty) {
      throw const VenderPrintException('No se encontro informacion de guia.');
    }
    return VenderPrintLabel.fromJson({
      ...payload,
      'NumeroGuia': guide,
      'fromReimpresion': true,
      'offline': false,
    });
  }

  Future<void> auditReprint({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String guideNumber,
  }) async {
    final guide = int.tryParse(guideNumber.replaceAll(RegExp(r'[^0-9]'), ''));
    if (guide == null) return;
    final idKey = await _idKeyProvider.createIdKey(config);
    final client = _httpClient.client(
      config.controllerBaseUrl,
      headerSource: appInformation,
      idKey: idKey,
    );
    await client.post<dynamic>(
      'ParametrosFramework/InsertarLogImpresion',
      data: {
        'ImpresoPor': appInformation.nombreMensajero,
        'NumeroGuia': guide,
        'IdTipoImpresion': 1,
      },
    );
  }
}
