import 'dart:convert';

class RecogidaItem {
  const RecogidaItem({
    required this.id,
    required this.type,
    required this.address,
    required this.customerName,
    required this.description,
    required this.time,
    required this.raw,
    this.pickupTypeId = 0,
    this.status = 0,
    this.preguideCount = 0,
    this.approxWeight = 0,
    this.totalValue = 0,
    this.synced = true,
  });

  final String id;
  final String type;
  final String address;
  final String customerName;
  final String description;
  final String time;
  final int pickupTypeId;
  final int status;
  final int preguideCount;
  final int approxWeight;
  final double totalValue;
  final bool synced;
  final Map<String, dynamic> raw;

  bool get isFixedPickup => pickupTypeId == 1 || pickupTypeId == 3;

  factory RecogidaItem.fromJson(Map<String, dynamic> json, {int status = 0}) {
    final id = _readString(json, const [
      'Id',
      'id',
      'ID',
      'IdSolicitud',
      'idSolicitud',
      'IdSolicitudRecogida',
      'idSolicitudRecogida',
      'R_IdSolicitudRecogida',
    ]);
    final typeId = _readInt(json, const [
      'TipoRecogida',
      'tipoRecogida',
      'IdTipoRecogida',
      'idTipoRecogida',
    ]);
    final count = _readInt(json, const [
      'CantidadPreenvios',
      'cantidadPreenvios',
      'Cantidad',
      'cantidad',
    ]);
    final weight = _readInt(json, const [
      'PesoAproximado',
      'pesoAproximado',
      'Peso',
      'peso',
    ]);
    return RecogidaItem(
      id: id,
      type: _pickupTypeLabel(
        typeId,
        _readString(json, const ['Tipo', 'tipo', 'NombreTipoRecogida']),
      ),
      address: _readString(json, const [
        'Direccion',
        'direccion',
        'DireccionRecogida',
        'direccionRecogida',
      ]),
      customerName: _coalesce([
        _readString(json, const ['PreguntarPor', 'preguntarPor']),
        _readString(json, const ['Nombre', 'nombre']),
        _readString(json, const ['NombreSucursal', 'nombreSucursal']),
      ]),
      description: _shipmentDescription(count, weight),
      time: _pickupTime(json),
      pickupTypeId: typeId,
      status: status,
      preguideCount: count,
      approxWeight: weight,
      totalValue: _readDouble(json, const ['ValorTotal', 'valorTotal']),
      synced: _readString(json, const ['icon']).toLowerCase() != 'unsincronized',
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class RecogidaPreenvio {
  const RecogidaPreenvio({
    required this.id,
    required this.guideNumber,
    required this.sender,
    required this.recipient,
    required this.value,
    required this.paymentMethodId,
    required this.paymentMethod,
    required this.verified,
    required this.cancelled,
    required this.raw,
  });

  final String id;
  final String guideNumber;
  final String sender;
  final String recipient;
  final double value;
  final int paymentMethodId;
  final String paymentMethod;
  final bool verified;
  final bool cancelled;
  final Map<String, dynamic> raw;

  factory RecogidaPreenvio.fromJson(Map<String, dynamic> json) {
    final sender = _readMap(json, const ['remitente', 'Remitente']);
    final recipient = _readMap(json, const ['destinatario', 'Destinatario']);
    return RecogidaPreenvio(
      id: _readString(json, const ['idPreEnvios', 'IdPreEnvios']),
      guideNumber: _coalesce([
        _readString(json, const ['numeroGuia', 'NumeroGuia']),
        _readString(json, const ['numeroPieza', 'NumeroPieza']),
        _readString(json, const ['idPreEnvios', 'IdPreEnvios']),
      ]),
      sender: _thirdPartyName(sender),
      recipient: _thirdPartyName(recipient),
      value: _readDouble(json, const ['valorTotal', 'ValorTotal']),
      paymentMethodId: _readInt(json, const ['idFormaPago', 'IdFormaPago']),
      paymentMethod: _readString(json, const [
        'nombreFormaPago',
        'NombreFormaPago',
      ]),
      verified: _readInt(json, const [
            'idEstadoPreEnvios',
            'IdEstadoPreEnvios',
            'idEstadoPreenvioLog',
          ]) !=
          0,
      cancelled: _readString(json, const [
        'descripcionEstado',
        'DescripcionEstado',
      ]).toLowerCase().contains('anulad'),
      raw: json,
    );
  }
}

class RecogidaBillingGuide {
  const RecogidaBillingGuide({
    required this.guideNumber,
    required this.paymentMethodId,
    required this.paymentMethodLabel,
    required this.isCollectPayment,
    required this.totalValue,
    required this.transportValue,
    required this.insuranceValue,
    required this.senderName,
    required this.senderDocument,
    required this.senderPhone,
    required this.senderEmail,
    required this.recipientName,
    required this.idPickup,
    required this.idPreInvoice,
  });

  final String guideNumber;
  final int paymentMethodId;
  final String paymentMethodLabel;
  final bool isCollectPayment;
  final double totalValue;
  final double transportValue;
  final double insuranceValue;
  final String senderName;
  final String senderDocument;
  final String senderPhone;
  final String senderEmail;
  final String recipientName;
  final int idPickup;
  final int idPreInvoice;
}

class RecogidaMotivo {
  const RecogidaMotivo({
    required this.id,
    required this.description,
    required this.raw,
  });

  final int id;
  final String description;
  final Map<String, dynamic> raw;

  factory RecogidaMotivo.fromJson(Map<String, dynamic> json) {
    return RecogidaMotivo(
      id: _readInt(json, const ['Id', 'id', 'IdMotivo']),
      description: _readString(json, const [
        'Descripcion',
        'descripcion',
        'Nombre',
        'nombre',
      ]),
      raw: json,
    );
  }
}

class RecogidaException implements Exception {
  const RecogidaException(this.message);

  final String message;

  @override
  String toString() => message;
}

String recogidaEncodeJson(Map<String, dynamic> json) => jsonEncode(json);

Map<String, dynamic> recogidaDecodeJson(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on Object {
    return const <String, dynamic>{};
  }
  return const <String, dynamic>{};
}

String _pickupTypeLabel(int id, String fallback) {
  return switch (id) {
    1 => 'CREDITO',
    2 => 'PEATON',
    3 => 'PUNTO',
    _ => fallback.trim().isNotEmpty ? fallback.trim() : 'TIPO RECOGIDA',
  };
}

String _shipmentDescription(int count, int weight) {
  final label = count == 1 ? 'Envio' : 'Envios';
  return '$count $label - ${weight}kg';
}

String _pickupTime(Map<String, dynamic> json) {
  final hour = _readString(json, const ['Hora', 'hora']);
  if (hour.trim().isNotEmpty) return hour;
  final date = _readString(json, const ['FechaRecogida', 'fechaRecogida']);
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  final h = parsed.hour.toString().padLeft(2, '0');
  final m = parsed.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _thirdPartyName(Map<String, dynamic> json) {
  return _coalesce([
    _readString(json, const ['nombreCompleto', 'NombreCompleto']),
    [
      _readString(json, const ['nombre', 'Nombre']),
      _readString(json, const ['primerApellido', 'PrimerApellido']),
      _readString(json, const ['segundoApellido', 'SegundoApellido']),
    ].where((value) => value.trim().isNotEmpty).join(' '),
    _readString(json, const ['razonSocial', 'RazonSocial']),
  ]);
}

String _coalesce(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key].toString();
  }
  return '';
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

double _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(
      value?.toString().replaceAll(',', '.').trim() ?? '',
    );
    if (parsed != null) return parsed;
  }
  return 0;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().startsWith('{')) {
      return recogidaDecodeJson(value);
    }
  }
  return const <String, dynamic>{};
}
