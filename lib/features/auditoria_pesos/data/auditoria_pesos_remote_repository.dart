import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../login/login.dart';
import '../models/auditoria_pesos_models.dart';

class AuditoriaPesosRemoteRepository {
  AuditoriaPesosRemoteRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _authUser = 'user-cognitooauth2';
  static const _authPassword = 'SW50ZXIyMDIxKg==';

  Future<String> obtenerToken(ControllerApiConfig config) async {
    final response = await _post(
      config.auditoriaAuthBaseUrl,
      'autorizador',
      data: const {'Usuario': _authUser, 'Password': _authPassword},
      fallbackMessage: 'No se pudo obtener autorización de auditoría.',
    );
    final token = _readString(response.data, 'IdToken');
    if (token.isEmpty) {
      throw const AuditoriaPesosException(
        'No se pudo obtener autorización de auditoría.',
      );
    }
    return token;
  }

  Future<AuditoriaGuide> consultarGuia({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String token,
    required String numeroGuia,
  }) async {
    final response = await _post(
      config.auditoriaPesosBaseUrl,
      'cargarinfoguia',
      data: {
        'NumeroGuia': numeroGuia,
        'CreadoPorUsuario': appInformation.idUsuario,
        'idMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
        'NombreMensajero': appInformation.nombreMensajero,
        'idCentroServicioMensajero':
            int.tryParse(appInformation.idCentroServicio) ?? 0,
      },
      token: token,
      fallbackMessage: 'No se pudo completar la consulta.',
    );
    final json = _asMap(response.data);
    if (json == null) {
      throw const AuditoriaPesosException('No se pudo completar la consulta.');
    }
    return AuditoriaGuide.fromJson(json);
  }

  Future<List<AuditoriaPhotoUploadResult>> guardarFotos({
    required ControllerApiConfig config,
    required String token,
    required List<AuditoriaPhoto> fotos,
  }) async {
    final response = await _post(
      config.auditoriaPesosBaseUrl,
      'subirimagenes',
      data: fotos.map((item) => item.toJson()).toList(growable: false),
      token: token,
      fallbackMessage: 'La guía no se pudo guardar.',
    );
    return _asList(response.data)
        .map((item) => AuditoriaPhotoUploadResult.fromJson(item))
        .toList(growable: false);
  }

  Future<AuditoriaSaveResult> guardarLiquidacion({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String token,
    required AuditoriaGuide guia,
    required bool pesoVolumetricoActivo,
    required String observaciones,
    required int alto,
    required int ancho,
    required int largo,
    required int pesoBascula,
    required int diferenciaPesos,
    required int pesoVolumetricoAproximado,
  }) async {
    final response = await _post(
      config.auditoriaPesosBaseUrl,
      'guardarinfoliquidacion',
      data: {
        'NumeroGuia': guia.numeroGuia,
        'IdCiudadOrigenSistema': guia.idCiudadOrigenSistema,
        'NombreCiudadOrigenSistema': guia.nombreCiudadOrigenSistema,
        'IdCiudadDestinoSistema': guia.idCiudadDestinoSistema,
        'NombreCiudadDestinoSistema': guia.nombreCiudadDestinoSistema,
        'IdRemitente': guia.idRemitente,
        'IdDestinatario': guia.idDestinatario,
        'IdCentroServicioOrigen': guia.idCentroServicioOrigen,
        'IdEstadoGuia': guia.idEstadoGuia,
        'IdTipoEntrega': guia.idTipoEntrega,
        'IdServicio': guia.idServicio,
        'PagoEnCasa': guia.pagoEnCasa,
        'FormaPago': guia.formaPago,
        'FechaAdmisionSistema': guia.fechaAdmisionSistema,
        'ValorAdmisionSistema': guia.valorAdmisionSistema,
        'ValorComercialSistema': guia.valorComercialSistema,
        'ValorTotalSistema': guia.valorTotalSistema,
        'PesoSistema': guia.pesoSistema,
        'PesoVolumetricoSistema': guia.pesoVolumetricoSistema,
        'PesoEsVolumetricoSistema': guia.pesoEsVolumetricoSistema,
        'LargoSistema': guia.largoSistema,
        'AnchoSistema': guia.anchoSistema,
        'AltoSistema': guia.altoSistema,
        'DiferenciaPesos': diferenciaPesos.toDouble(),
        'PesoBasculaAuditoria': pesoVolumetricoActivo
            ? 0.0
            : pesoBascula.toDouble(),
        'LargoAuditoria': largo.toDouble(),
        'AnchoAuditoria': ancho.toDouble(),
        'AltoAuditoria': alto.toDouble(),
        'PesoVolumetricoAuditoria': pesoVolumetricoActivo
            ? pesoVolumetricoAproximado.toDouble()
            : 0.0,
        'PesoEsVolumetricoAuditoria': pesoVolumetricoActivo ? 1 : 0,
        'IdAuditor': int.tryParse(appInformation.idMensajero) ?? 0,
        'NombreAuditor': appInformation.nombreMensajero,
        'CreadoPor': appInformation.idUsuario,
        'IdCentroServicioMensajero':
            int.tryParse(appInformation.idCentroServicio) ?? 0,
        'Observaciones': observaciones,
        'Planillado': guia.planillado,
        'Facturada': guia.facturada,
        'IdCliente': guia.idCliente,
        'IdContrato': guia.idContrato,
        'IdAdmision': guia.idAdmision,
      },
      token: token,
      fallbackMessage: 'La guía no se pudo guardar.',
    );
    final json = _asMap(response.data);
    if (json == null) {
      throw const AuditoriaPesosException('La guía no se pudo guardar.');
    }
    return AuditoriaSaveResult.fromJson(json);
  }

  Future<AuditoriaReportSummary> consultarReporte({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String token,
    required String fechaInicial,
    required String fechaFinal,
  }) async {
    final response = await _post(
      config.auditoriaPesosBaseUrl,
      'consultarauditoriapesos',
      data: _reportRequest(
        appInformation,
        fechaInicial,
        fechaFinal,
        detailed: false,
      ),
      token: token,
      fallbackMessage: 'Información no disponible.',
    );
    final json = _asMap(response.data);
    if (json == null) {
      throw const AuditoriaPesosException('Información no disponible.');
    }
    return AuditoriaReportSummary.fromJson(
      json,
    ).copyWith(fechaInicial: fechaInicial, fechaFinal: fechaFinal);
  }

  Future<List<AuditoriaReportDetail>> consultarReporteDetallado({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String token,
    required String fechaInicial,
    required String fechaFinal,
  }) async {
    final response = await _post(
      config.auditoriaPesosBaseUrl,
      'consultarauditoriapesos',
      data: _reportRequest(
        appInformation,
        fechaInicial,
        fechaFinal,
        detailed: true,
      ),
      token: token,
      fallbackMessage: 'Información no disponible.',
    );
    return _asList(response.data)
        .map((item) => AuditoriaReportDetail.fromJson(item))
        .toList(growable: false);
  }

  Map<String, dynamic> _reportRequest(
    AppInformation appInformation,
    String fechaInicial,
    String fechaFinal, {
    required bool detailed,
  }) {
    return {
      'IdCentroServicioMensajero':
          int.tryParse(appInformation.idCentroServicio) ?? 0,
      'idMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
      'FechaInicioReporte': fechaInicial,
      'FechaFinalReporte': fechaFinal,
      'InformeDetallado': detailed ? 2 : 1,
    };
  }

  Future<Response<dynamic>> _post(
    String baseUrl,
    String path, {
    required Object data,
    String? token,
    required String fallbackMessage,
  }) async {
    final client = _client(baseUrl);
    final response = await client.post<dynamic>(
      path,
      data: data,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.trim().isNotEmpty) 'Token': token,
        },
      ),
    );
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return response;
    }
    throw AuditoriaPesosException(
      _readErrorMessage(response.data) ?? fallbackMessage,
    );
  }

  Dio _client(String baseUrl) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final client = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        validateStatus: (_) => true,
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }
}

Map<String, dynamic>? _asMap(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  if (data is String && data.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      return _asMap(decoded);
    } on Object {
      return null;
    }
  }
  return null;
}

List<Map<String, dynamic>> _asList(Object? data) {
  if (data is List) {
    return data
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
  if (data is String && data.trim().isNotEmpty) {
    try {
      return _asList(jsonDecode(data));
    } on Object {
      return const [];
    }
  }
  return const [];
}

String _readString(Object? data, String key) {
  final json = _asMap(data);
  return json?[key]?.toString().trim() ?? '';
}

String? _readErrorMessage(Object? data) {
  final json = _asMap(data);
  final message =
      json?['Mensaje']?.toString().trim() ??
      json?['Message']?.toString().trim() ??
      json?['message']?.toString().trim();
  return message == null || message.isEmpty ? null : message;
}
