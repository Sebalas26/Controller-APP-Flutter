class PagoMethodIds {
  const PagoMethodIds._();

  static const cash = 1;
  static const daviplata = 2;
  static const interPay = 4;
  static const nequi = 5;
  static const linkPayment = 6;

  static const chargeable = <int>[cash, nequi, linkPayment, interPay];

  static bool isRemote(int id) => id == nequi || id == linkPayment;

  static bool isLegacyQr(int id) => id == daviplata;

  static String nameFor(int id) {
    return switch (id) {
      cash => 'Efectivo',
      daviplata => 'Daviplata',
      interPay => 'Inter Pay',
      nequi => 'Nequi',
      linkPayment => 'Tarjeta debito / credito / pse',
      _ => 'Efectivo',
    };
  }
}

enum PagoFlowType {
  admision('Admision'),
  entrega('Entrega'),
  multientrega('Multientrega');

  const PagoFlowType(this.nativeName);

  final String nativeName;
}

class PagoOption {
  const PagoOption({
    required this.id,
    required this.name,
    required this.time,
    this.percentage,
    this.discount,
    this.raw = const <String, Object?>{},
  });

  final int id;
  final String name;
  final int time;
  final String? percentage;
  final int? discount;
  final Map<String, Object?> raw;

  factory PagoOption.cash() {
    return const PagoOption(id: PagoMethodIds.cash, name: 'Efectivo', time: 0);
  }

  factory PagoOption.fromJson(Map<String, dynamic> json) {
    final id = _readInt(json, const [
      'idMedioPagoAlterno',
      'IdMedioPagoAlterno',
      'idMedioPago',
      'IdMedioPago',
    ]);
    final name = _readString(json, const [
      'nombreVisualizacion',
      'NombreVisualizacion',
      'nombreMedioPago',
      'NombreMedioPago',
      'descripcion',
      'Descripcion',
    ]);
    return PagoOption(
      id: id,
      name: name.trim().isEmpty ? PagoMethodIds.nameFor(id) : name,
      time: _readInt(json, const ['tiempoPago', 'TiempoPago', 'tiempo']),
      percentage: _readNullableString(json, const [
        'percentage',
        'porcentaje',
        'Porcentaje',
      ]),
      discount: _readNullableInt(json, const ['discount', 'descuento']),
      raw: json,
    );
  }
}

class PagoNotificationRequest {
  const PagoNotificationRequest({
    required this.flow,
    required this.methodId,
    required this.amount,
    required this.phone,
    required this.email,
    required this.guides,
    required this.preInvoiceId,
    required this.serviceCenterId,
    required this.userId,
    required this.identifier,
    this.signalRToken = '',
    this.channel = 'WHATSAPP',
  });

  final PagoFlowType flow;
  final int methodId;
  final int amount;
  final String phone;
  final String email;
  final List<String> guides;
  final String preInvoiceId;
  final String serviceCenterId;
  final String userId;
  final String identifier;
  final String signalRToken;
  final String channel;
}

class PagoQrGuide {
  const PagoQrGuide({required this.guideNumber, required this.value});

  final String guideNumber;
  final int value;

  Map<String, Object> toJson() {
    return {
      'numeroGuia': int.tryParse(guideNumber) ?? guideNumber,
      'valorGuia': value,
    };
  }
}

class PagoQrRequest {
  const PagoQrRequest({
    required this.paymentMethodId,
    required this.preInvoiceId,
    required this.total,
    required this.guides,
    required this.userId,
    required this.serviceCenterId,
  });

  final int paymentMethodId;
  final int preInvoiceId;
  final int total;
  final List<PagoQrGuide> guides;
  final String userId;
  final String serviceCenterId;

  Map<String, Object> toJson() {
    return {
      'idMediosPago': paymentMethodId,
      'idPreFactura': preInvoiceId,
      'totalPago': total,
      'listaGuias': guides.map((guide) => guide.toJson()).toList(),
      'usuario': int.tryParse(userId) ?? userId,
      'centrodeServicio': serviceCenterId,
    };
  }
}

class PagoOperationResult {
  const PagoOperationResult({
    required this.success,
    required this.message,
    this.transactionId = 0,
    this.status = '',
    this.code = '',
    this.raw = const <String, Object?>{},
  });

  final bool success;
  final String message;
  final int transactionId;
  final String status;
  final String code;
  final Map<String, Object?> raw;

  bool get hasTransaction => transactionId > 0;

  bool get isApproved {
    final normalized = status.trim().toLowerCase();
    return success &&
        (normalized.contains('aprob') ||
            normalized.contains('pagad') ||
            normalized.contains('realiz') ||
            normalized.contains('acept') ||
            normalized == 'success' ||
            normalized == 'ok');
  }

  bool get isPending {
    if (isApproved) return false;
    final normalized = status.trim().toLowerCase();
    return hasTransaction ||
        normalized.contains('pend') ||
        normalized.contains('proceso') ||
        normalized.contains('espera');
  }

  String get displayStatus {
    if (status.trim().isNotEmpty) return status.trim();
    if (isPending) return 'Pendiente';
    return success ? 'Procesado' : 'No responde';
  }

  factory PagoOperationResult.fromJson(
    Map<String, dynamic> json, {
    int fallbackTransactionId = 0,
  }) {
    final values = _readMap(json, const ['valores', 'Valores', 'valor']);
    final transactionId =
        _readInt(values, const ['idSolicitud', 'idSolicitudPago', 'valor']) != 0
        ? _readInt(values, const ['idSolicitud', 'idSolicitudPago', 'valor'])
        : _readInt(json, const [
            'valor',
            'valores',
            'idSolicitud',
            'idSolicitudPago',
            'idGeneracionCodigoQR',
          ]);
    return PagoOperationResult(
      success: _readBool(json, const [
        'respuestaEstado',
        'RespuestaEstado',
        'success',
        'Success',
      ]),
      message: _coalesce([
        _readString(json, const ['mensaje', 'Mensaje', 'message', 'Message']),
        _readString(values, const ['mensaje', 'Mensaje']),
      ]),
      transactionId: transactionId > 0 ? transactionId : fallbackTransactionId,
      status: _coalesce([
        _readString(values, const ['estado', 'Estado']),
        _readString(json, const ['estado', 'Estado']),
      ]),
      code: _readString(json, const ['codigoEstado', 'code', 'Code']),
      raw: json,
    );
  }
}

class PagosException implements Exception {
  const PagosException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  return value?.toString() ?? '';
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _readString(json, keys).trim();
  return value.isEmpty ? null : value;
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

int? _readNullableInt(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

bool _readBool(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'si';
}

Object? _readValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
    final lower = key.toLowerCase();
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
  }
  return null;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _coalesce(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
