import 'dart:convert';

class VenderPrintException implements Exception {
  const VenderPrintException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VenderPrintLabel {
  const VenderPrintLabel({
    required this.guideNumber,
    required this.senderName,
    required this.senderDocument,
    required this.senderPhone,
    required this.senderAddress,
    required this.senderCity,
    required this.recipientName,
    required this.recipientDocument,
    required this.recipientPhone,
    required this.recipientAddress,
    required this.recipientCity,
    required this.serviceName,
    required this.deliveryType,
    required this.packageType,
    required this.pieces,
    required this.weight,
    required this.content,
    required this.securityBag,
    required this.paymentMethod,
    required this.declaredValue,
    required this.transportValue,
    required this.insuranceValue,
    required this.totalValue,
    required this.admissionDate,
    required this.estimatedDeliveryDate,
    required this.destinationPostalCode,
    required this.observation,
    required this.fromReprint,
    required this.offline,
    this.raw = const <String, Object?>{},
  });

  final String guideNumber;
  final String senderName;
  final String senderDocument;
  final String senderPhone;
  final String senderAddress;
  final String senderCity;
  final String recipientName;
  final String recipientDocument;
  final String recipientPhone;
  final String recipientAddress;
  final String recipientCity;
  final String serviceName;
  final String deliveryType;
  final String packageType;
  final String pieces;
  final String weight;
  final String content;
  final String securityBag;
  final String paymentMethod;
  final String declaredValue;
  final String transportValue;
  final String insuranceValue;
  final String totalValue;
  final String admissionDate;
  final String estimatedDeliveryDate;
  final String destinationPostalCode;
  final String observation;
  final bool fromReprint;
  final bool offline;
  final Map<String, Object?> raw;

  String get displayGuide => guideNumber.trim().isEmpty ? '-' : guideNumber;

  Map<String, Object?> toJson() {
    return {
      ...raw,
      'NumeroGuia': guideNumber,
      'NombreRemitente': senderName,
      'NumeroIdentificacionRemitente': senderDocument,
      'TelefonoRemitente': senderPhone,
      'DireccionRemitente': senderAddress,
      'NombreCiudadRemitente': senderCity,
      'NombreDestinatario': recipientName,
      'NumeroIdentificacionDestinatario': recipientDocument,
      'TelefonoDestinatario': recipientPhone,
      'DireccionDestinatario': recipientAddress,
      'NombreCiudadDestinatario': recipientCity,
      'NombreServicio': serviceName,
      'TipoEntrega': deliveryType,
      'TipoEmpaque': packageType,
      'NumeroPiezas': pieces,
      'Peso': weight,
      'DiceContener': content,
      'BolsaSeguridad': securityBag,
      'FormaPago': paymentMethod,
      'ValorDeclarado': declaredValue,
      'ValorTransporte': transportValue,
      'ValorPrima': insuranceValue,
      'ValorTotal': totalValue,
      'FechaPreenvio': admissionDate,
      'FechaEstimadaEntrega': estimatedDeliveryDate,
      'CodigoPostalDestino': destinationPostalCode,
      'observacion': observation,
      'fromReimpresion': fromReprint,
      'offline': offline,
    };
  }

  factory VenderPrintLabel.fromJson(Map<String, dynamic> json) {
    final sender = _map(json, const ['Remitente', 'remitente']);
    final recipient = _map(json, const ['Destinatario', 'destinatario']);
    final destinationGeo = _map(recipient, const [
      'DatosGeoCliente',
      'datosGeoCliente',
    ]);
    return VenderPrintLabel(
      guideNumber: _read(json, const [
        'NumeroGuia',
        'numeroGuia',
        'numeroPreenvio',
      ]),
      senderName: _firstNotEmpty([
        _read(json, const ['NombreRemitente', 'nombreRemitente']),
        _personName(sender),
      ]),
      senderDocument: _firstNotEmpty([
        _read(json, const [
          'NumeroIdentificacionRemitente',
          'identificacionRemitente',
        ]),
        _read(sender, const ['Identificacion', 'identificacion']),
      ]),
      senderPhone: _firstNotEmpty([
        _read(json, const ['TelefonoRemitente', 'telefonoRemitente']),
        _read(sender, const ['Telefono', 'telefono']),
      ]),
      senderAddress: _firstNotEmpty([
        _read(json, const ['DireccionRemitente', 'direccionRemitente']),
        _read(sender, const ['Direccion', 'direccion']),
      ]),
      senderCity: _read(json, const [
        'NombreCiudadRemitente',
        'nombreCiudadOrigen',
        'NombreCiudadOrigen',
      ]),
      recipientName: _firstNotEmpty([
        _read(json, const ['NombreDestinatario', 'nombreDestinatario']),
        _personName(recipient),
      ]),
      recipientDocument: _firstNotEmpty([
        _read(json, const [
          'NumeroIdentificacionDestinatario',
          'identificacionDestinatario',
        ]),
        _read(recipient, const ['Identificacion', 'identificacion']),
      ]),
      recipientPhone: _firstNotEmpty([
        _read(json, const ['TelefonoDestinatario', 'telefonoDestinatario']),
        _read(recipient, const ['Telefono', 'telefono']),
      ]),
      recipientAddress: _firstNotEmpty([
        _read(json, const ['DireccionDestinatario', 'direccionDestinatario']),
        _read(recipient, const ['Direccion', 'direccion']),
      ]),
      recipientCity: _read(json, const [
        'NombreCiudadDestinatario',
        'nombreCiudadDestino',
        'NombreCiudadDestino',
      ]),
      serviceName: _read(json, const ['NombreServicio', 'nombreServicio']),
      deliveryType: _firstNotEmpty([
        _read(json, const [
          'tipoEntrega',
          'TipoEntrega',
          'DescripcionTipoEntrega',
          'descripcionTipoEntrega',
        ]),
        _read(json, const ['IdTipoEntrega', 'idTipoEntrega']),
      ]),
      packageType: _read(json, const [
        'TipoEmpaque',
        'nombreTipoEnvio',
        'NombreTipoEnvio',
      ]),
      pieces: _read(json, const [
        'NumeroPiezas',
        'numeroPiezas',
        'NumeroPieza',
        'TotalPiezas',
      ]),
      weight: _read(json, const ['Peso', 'peso']),
      content: _read(json, const ['DiceContener', 'diceContener']),
      securityBag: _read(json, const [
        'BolsaSeguridad',
        'NumeroBolsaSeguridad',
        'numeroBolsaSeguridad',
      ]),
      paymentMethod: _read(json, const [
        'FormaPago',
        'formasPagoDescripcion',
        'FormasPagoDescripcion',
      ]),
      declaredValue: _read(json, const ['ValorDeclarado', 'valorDeclarado']),
      transportValue: _read(json, const [
        'ValorTransporte',
        'ValorAdmision',
        'valorAdmision',
      ]),
      insuranceValue: _read(json, const [
        'ValorPrima',
        'ValorPrimaSeguro',
        'valorPrimaSeguro',
      ]),
      totalValue: _read(json, const ['ValorTotal', 'valorTotal']),
      admissionDate: _read(json, const [
        'FechaPreenvio',
        'FechaAdmision',
        'fechaAdmision',
      ]),
      estimatedDeliveryDate: _firstNotEmpty([
        _read(json, const [
          'FechaEstimadaEntregaNew',
          'fechaEstimadaEntregaNew',
        ]),
        _read(json, const ['FechaEstimadaEntrega', 'fechaEstimadaEntrega']),
      ]),
      destinationPostalCode: _firstNotEmpty([
        _read(json, const ['CodigoPostalDestino', 'codigoPostalDestino']),
        _read(destinationGeo, const ['zonaPostal', 'ZonaPostal']),
      ]),
      observation: _read(json, const [
        'observacion',
        'Observacion',
        'Observaciones',
        'observaciones',
      ]),
      fromReprint: _bool(json, const ['fromReimpresion', 'isFromReimpresion']),
      offline: _bool(json, const ['offline', 'isOffline']),
      raw: Map<String, Object?>.from(json),
    );
  }

  factory VenderPrintLabel.fromJsonString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const VenderPrintException('La etiqueta no tiene formato valido.');
    }
    return VenderPrintLabel.fromJson(Map<String, dynamic>.from(decoded));
  }
}

Map<String, dynamic> printJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, val) => MapEntry('$key', val));
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return decoded.map((key, val) => MapEntry('$key', val));
  }
  return const <String, dynamic>{};
}

String _read(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

Map<String, dynamic> _map(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final map = printJsonMap(json[key]);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

String _personName(Map<String, dynamic> json) {
  return _firstNotEmpty([
    _read(json, const ['Nombre', 'nombre']),
    [
      _read(json, const ['Nombres', 'nombres']),
      _read(json, const ['PrimerApellido', 'primerApellido']),
      _read(json, const ['SegundoApellido', 'segundoApellido']),
    ].where((item) => item.isNotEmpty).join(' '),
  ]);
}

String _firstNotEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

bool _bool(Map<String, dynamic> json, List<String> keys) {
  final value = _read(json, keys).toLowerCase();
  return value == 'true' || value == '1' || value == 'si';
}
