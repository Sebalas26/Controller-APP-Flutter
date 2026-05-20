import 'dart:convert';

enum EntregaGuideStatus {
  enZona('en_zona'),
  entregada('entregada'),
  devolucion('devolucion');

  const EntregaGuideStatus(this.value);

  final String value;
}

enum EntregaDownloadType {
  entregaCorrectaMensajero('ECM'),
  devolucionMensajero('DM');

  const EntregaDownloadType(this.code);

  final String code;
}

class EntregaGuide {
  const EntregaGuide({
    required this.raw,
    required this.guideNumber,
    required this.stateId,
    required this.stateName,
    required this.recipientName,
    required this.recipientAddress,
    required this.phone,
    required this.planSheet,
    required this.assignmentDate,
    required this.auditDate,
    required this.city,
    required this.cityId,
    required this.serviceId,
    required this.serviceName,
    required this.valueGuide,
    required this.valueContraPayment,
    required this.paid,
    required this.contraPaymentPaid,
    required this.weight,
    required this.latitude,
    required this.longitude,
    required this.deliveryAttempt,
    required this.housingTypeId,
    required this.addressGeneralId,
  });

  final Map<String, dynamic> raw;
  final String guideNumber;
  final int stateId;
  final String stateName;
  final String recipientName;
  final String recipientAddress;
  final String phone;
  final int planSheet;
  final String assignmentDate;
  final String auditDate;
  final String city;
  final String cityId;
  final int serviceId;
  final String serviceName;
  final double valueGuide;
  final double valueContraPayment;
  final bool paid;
  final bool contraPaymentPaid;
  final double weight;
  final String latitude;
  final String longitude;
  final int deliveryAttempt;
  final int housingTypeId;
  final int addressGeneralId;

  int get valueToCollect {
    var total = 0.0;
    if (!paid) total += valueGuide;
    if (!contraPaymentPaid) total += valueContraPayment;
    return total.round();
  }

  String get displayState {
    if (stateName.trim().isNotEmpty) return stateName.trim();
    if (stateId == 0) return 'Sin estado';
    return 'Estado $stateId';
  }

  factory EntregaGuide.fromJson(Map<String, dynamic> json) {
    final service = _asMap(json['Servicio']) ?? const <String, dynamic>{};
    return EntregaGuide(
      raw: Map<String, dynamic>.from(json),
      guideNumber: _readAnyString(json, const ['NumeroGuia', 'numeroGuia']),
      stateId: _readAnyInt(json, const ['IdEstadoGuia', 'idEstadoGuia']),
      stateName: _readAnyString(json, const [
        'NombreEstadoGuia',
        'nombreEstadoGuia',
      ]),
      recipientName: _readAnyString(json, const [
        'NombreDestinatario',
        'nombreDestinatario',
      ]),
      recipientAddress: _readAnyString(json, const [
        'DireccionDestinatario',
        'direccionDestinatario',
      ]),
      phone: _readAnyString(json, const ['Telefono', 'telefono']),
      planSheet: _readAnyInt(json, const ['Planilla', 'planilla']),
      assignmentDate: _readAnyString(json, const [
        'FechaAsignacion',
        'fechaAsignacion',
      ]),
      auditDate: _readAnyString(json, const [
        'FechaAuditoria',
        'fechaAuditoria',
      ]),
      city: _readAnyString(json, const ['Ciudad', 'ciudad']),
      cityId: _readAnyString(json, const ['IdCiudad', 'idCiudad']),
      serviceId:
          _readAnyInt(json, const ['IdServicio', 'idServicio']) != 0
              ? _readAnyInt(json, const ['IdServicio', 'idServicio'])
              : _readAnyInt(service, const ['IdServicio', 'idServicio']),
      serviceName: _readAnyString(json, const [
        'TipoEnvioNombre',
        'tipoEnvioNombre',
        'NombreServicio',
      ]),
      valueGuide: _readAnyDouble(json, const ['ValorGuia', 'valorGuia']),
      valueContraPayment: _readAnyDouble(json, const [
        'ValorContraPago',
        'valorContraPago',
      ]),
      paid: _readAnyBool(json, const ['EstaPagada', 'estaPagada']),
      contraPaymentPaid: _readAnyBool(json, const [
        'ContraPagoPagado',
        'contraPagoPagado',
      ]),
      weight: _readAnyDouble(json, const ['Peso', 'peso']),
      latitude: _readAnyString(json, const ['Latitude', 'latitude']),
      longitude: _readAnyString(json, const ['Longitude', 'longitude']),
      deliveryAttempt: _readAnyInt(json, const ['IntEntrega', 'intEntrega']),
      housingTypeId: _readAnyInt(json, const [
        'IdTipoVivienda',
        'UnidadHabitacional',
      ]),
      addressGeneralId: _readAnyInt(json, const ['IdDireccionGeneral']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'NumeroGuia': int.tryParse(guideNumber) ?? guideNumber,
      'IdEstadoGuia': stateId,
      'NombreEstadoGuia': stateName,
      'NombreDestinatario': recipientName,
      'DireccionDestinatario': recipientAddress,
      'Telefono': phone,
      'Planilla': planSheet,
      'FechaAsignacion': assignmentDate,
      'FechaAuditoria': auditDate,
      'Ciudad': city,
      'IdCiudad': cityId,
      'Servicio': {
        ...(_asMap(raw['Servicio']) ?? const <String, dynamic>{}),
        'IdServicio': serviceId,
      },
      'ValorGuia': valueGuide,
      'ValorContraPago': valueContraPayment,
      'EstaPagada': paid,
      'ContraPagoPagado': contraPaymentPaid,
      'Peso': weight,
      'Latitude': latitude,
      'Longitude': longitude,
      'IntEntrega': deliveryAttempt,
      'IdTipoVivienda': housingTypeId,
      'IdDireccionGeneral': addressGeneralId,
    };
  }

  EntregaGuide copyWith({
    int? stateId,
    String? stateName,
    int? housingTypeId,
  }) {
    return EntregaGuide(
      raw: raw,
      guideNumber: guideNumber,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      recipientName: recipientName,
      recipientAddress: recipientAddress,
      phone: phone,
      planSheet: planSheet,
      assignmentDate: assignmentDate,
      auditDate: auditDate,
      city: city,
      cityId: cityId,
      serviceId: serviceId,
      serviceName: serviceName,
      valueGuide: valueGuide,
      valueContraPayment: valueContraPayment,
      paid: paid,
      contraPaymentPaid: contraPaymentPaid,
      weight: weight,
      latitude: latitude,
      longitude: longitude,
      deliveryAttempt: deliveryAttempt,
      housingTypeId: housingTypeId ?? this.housingTypeId,
      addressGeneralId: addressGeneralId,
    );
  }
}

class EntregaReason {
  const EntregaReason({
    required this.id,
    required this.description,
    required this.timeAffectation,
    required this.scan,
    required this.deliveryAttempt,
    required this.raw,
  });

  final int id;
  final String description;
  final int timeAffectation;
  final bool scan;
  final bool deliveryAttempt;
  final Map<String, dynamic> raw;

  factory EntregaReason.fromJson(Map<String, dynamic> json) {
    return EntregaReason(
      id: _readAnyInt(json, const ['IdMotivoGuia', 'idMotivoGuia']),
      description: _readAnyString(json, const [
        'DescripcionAPP',
        'Descripcion',
        'descripcion',
      ]),
      timeAffectation: _readAnyInt(json, const [
        'TiempoAfectacion',
        'tiempoAfectacion',
      ]),
      scan: _readAnyBool(json, const ['EsEscaneo', 'esEscaneo']),
      deliveryAttempt: _readAnyBool(json, const [
        'IntentoEntrega',
        'intentoEntrega',
      ]),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'IdMotivoGuia': id,
      'DescripcionAPP': description,
      'TiempoAfectacion': timeAffectation,
      'EsEscaneo': scan,
      'IntentoEntrega': deliveryAttempt,
    };
  }

  Map<String, dynamic> toAwsJson() {
    return {
      'Descripcion': description,
      'EsEscaneo': scan,
      'IdMotivoGuia': id,
      'IntentoEntrega': deliveryAttempt,
      'TiempoAfectacion': timeAffectation,
    };
  }
}

class EntregaRecipientData {
  const EntregaRecipientData({
    required this.name,
    required this.document,
    required this.phone,
    required this.observations,
    required this.housingTypeId,
  });

  final String name;
  final String document;
  final String phone;
  final String observations;
  final int housingTypeId;

  String get numericDocument => document.replaceAll(RegExp(r'[^0-9]'), '');
}

class EntregaPendingDownload {
  const EntregaPendingDownload({
    required this.id,
    required this.guideNumber,
    required this.type,
    required this.guide,
    required this.payload,
    required this.synced,
    required this.createdAt,
    required this.isQr,
    required this.message,
    this.syncedAt,
  });

  final int id;
  final String guideNumber;
  final EntregaDownloadType type;
  final EntregaGuide guide;
  final Map<String, dynamic> payload;
  final bool synced;
  final DateTime createdAt;
  final bool isQr;
  final String message;
  final DateTime? syncedAt;

  factory EntregaPendingDownload.fromRow(Map<String, Object?> row) {
    final guideJson = _decodeMap(row['guide_json']);
    return EntregaPendingDownload(
      id: _intValue(row['id']),
      guideNumber: _stringValue(row['numero_guia']),
      type: _downloadTypeFromCode(_stringValue(row['tipo_descargue'])),
      guide: EntregaGuide.fromJson(guideJson),
      payload: _decodeMap(row['payload_json']),
      synced: _intValue(row['synced']) == 1,
      createdAt:
          DateTime.tryParse(_stringValue(row['created_at'])) ?? DateTime.now(),
      isQr: _intValue(row['is_qr']) == 1,
      message: _stringValue(row['mensaje']),
      syncedAt: DateTime.tryParse(_stringValue(row['synced_at'])),
    );
  }
}

class EntregaSyncResult {
  const EntregaSyncResult({
    required this.resultCode,
    required this.message,
    required this.raw,
    required this.httpStatus,
  });

  final int resultCode;
  final String message;
  final Map<String, dynamic> raw;
  final int httpStatus;

  bool get success {
    if (httpStatus >= 200 && httpStatus < 300 && resultCode == 0 && raw.isEmpty) {
      return true;
    }
    return resultCode == 1 || resultCode == 100;
  }

  factory EntregaSyncResult.fromResponse(Object? data, {int httpStatus = 0}) {
    final json = _normalizeResponse(data);
    return EntregaSyncResult(
      resultCode: _readAnyInt(json, const ['Resultado', 'resultado']),
      message: _readAnyString(json, const [
        'Mensaje',
        'mensaje',
        'Message',
        'message',
      ]),
      raw: json,
      httpStatus: httpStatus,
    );
  }
}

class EntregaException implements Exception {
  const EntregaException(this.message);

  final String message;

  @override
  String toString() => message;
}

EntregaDownloadType _downloadTypeFromCode(String code) {
  return EntregaDownloadType.values.firstWhere(
    (item) => item.code == code,
    orElse: () => EntregaDownloadType.entregaCorrectaMensajero,
  );
}

Map<String, dynamic> _normalizeResponse(Object? data) {
  if (data == null) return {};
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is List && data.isNotEmpty) {
    final first = data.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  if (data is String && data.trim().isNotEmpty) {
    final decoded = jsonDecode(data);
    return _normalizeResponse(decoded);
  }
  return {};
}

Map<String, dynamic> _decodeMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return {};
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _readAnyString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueFor(json, key);
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return '';
}

int _readAnyInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueFor(json, key);
    final parsed = _intValue(value);
    if (parsed != 0) return parsed;
  }
  return 0;
}

double _readAnyDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueFor(json, key);
    final parsed = _doubleValue(value);
    if (parsed != 0) return parsed;
  }
  return 0;
}

bool _readAnyBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueFor(json, key);
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text.isNotEmpty) {
      return text == 'true' || text == '1' || text == 'si';
    }
  }
  return false;
}

Object? _valueFor(Map<String, dynamic> json, String key) {
  if (json.containsKey(key)) return json[key];
  final lower = key.toLowerCase();
  for (final entry in json.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_stringValue(value).trim()) ?? 0;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  final text = _stringValue(value).replaceAll(r'$', '').trim();
  if (text.contains(',')) {
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }
  return double.tryParse(text) ?? double.tryParse(text.replaceAll('.', '')) ?? 0;
}

String _stringValue(Object? value) => value?.toString() ?? '';
