import 'dart:convert';

class VenderPrintException implements Exception {
  const VenderPrintException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VenderPrintRouteStop {
  const VenderPrintRouteStop({
    required this.shortCity,
    required this.locker,
    required this.door,
  });

  final String shortCity;
  final String locker;
  final String door;

  bool get hasData =>
      shortCity.trim().isNotEmpty ||
      locker.trim().isNotEmpty ||
      door.trim().isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'NombreCiudadCorto': shortCity,
      'Casillero': locker,
      'Puerta': door,
    };
  }

  factory VenderPrintRouteStop.fromJson(Map<String, dynamic> json) {
    return VenderPrintRouteStop(
      shortCity: _read(json, const [
        'NombreCiudadCorto',
        'nombreCiudadCorto',
        'LOC_NombreCorto',
        'locNombreCorto',
      ]),
      locker: _read(json, const [
        'Casillero',
        'casillero',
        'NumeroCasillero',
        'numeroCasillero',
      ]),
      door: _read(json, const [
        'Puerta',
        'puerta',
        'NumeroPuerta',
        'numeroPuerta',
      ]),
    );
  }
}

class VenderPrintGeoGrid {
  const VenderPrintGeoGrid({
    required this.node,
    required this.zone,
    required this.block,
    required this.satelliteDay,
    required this.satellite24h,
    required this.satelliteNode,
  });

  const VenderPrintGeoGrid.empty()
    : node = '0',
      zone = '0',
      block = '0',
      satelliteDay = '0',
      satellite24h = '0-0.0',
      satelliteNode = '0-0.0';

  final String node;
  final String zone;
  final String block;
  final String satelliteDay;
  final String satellite24h;
  final String satelliteNode;

  Map<String, Object?> toJson() {
    return {
      'nodoTexto': node,
      'zonaTexto': zone,
      'manzanaTexto': block,
      'sateliteDiaTexto': satelliteDay,
      'satelite24HTexto': satellite24h,
      'satNodoTexto': satelliteNode,
    };
  }

  factory VenderPrintGeoGrid.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const VenderPrintGeoGrid.empty();
    final directNode = _read(json, const ['nodoTexto', 'node']);
    final directZone = _read(json, const ['zonaTexto', 'zone']);
    final directBlock = _read(json, const ['manzanaTexto', 'block']);
    final directSatelliteDay = _read(json, const [
      'sateliteDiaTexto',
      'satelliteDay',
    ]);
    final directSatellite24h = _read(json, const [
      'satelite24HTexto',
      'satellite24h',
    ]);
    final directSatelliteNode = _read(json, const [
      'satNodoTexto',
      'satelliteNode',
    ]);
    if (directNode.isNotEmpty ||
        directZone.isNotEmpty ||
        directBlock.isNotEmpty ||
        directSatelliteDay.isNotEmpty ||
        directSatellite24h.isNotEmpty ||
        directSatelliteNode.isNotEmpty) {
      return VenderPrintGeoGrid(
        node: directNode.isEmpty ? '0' : directNode,
        zone: directZone.isEmpty ? '0' : directZone,
        block: directBlock.isEmpty ? '0' : directBlock,
        satelliteDay: directSatelliteDay.isEmpty ? '0' : directSatelliteDay,
        satellite24h: directSatellite24h.isEmpty ? '0-0.0' : directSatellite24h,
        satelliteNode: directSatelliteNode.isEmpty
            ? '0-0.0'
            : directSatelliteNode,
      );
    }
    final node = _intText(json, const ['nodo', 'Nodo']);
    final nodeKm = _intText(json, const ['nodoDistancia', 'nodoKM', 'NodoKM']);
    final nodeZone = _intText(json, const ['nodoZona', 'NodoZona']);
    final satelliteDay = _intText(json, const [
      'sateliteDia',
      'satelite',
      'Satelite',
    ]);
    final satelliteDayKm = _intText(json, const [
      'sateliteDiaKM',
      'sateliteDistancia',
      'sateliteKM',
      'SateliteKM',
    ]);
    final satelliteDayZone = _intText(json, const [
      'sateliteZonaDia',
      'SateliteZonaDia',
    ]);
    final satellite24h = _intText(json, const [
      'satelite24H',
      'sat24H',
      'Sat24H',
    ]);
    final satellite24hKm = _intText(json, const [
      'satelite24HKM',
      'sat24HKM',
      'Sat24HKM',
    ]);
    final satellite24hZone = _intText(json, const [
      'sateliteZona24H',
      'SatZona24H',
    ]);
    final zone = _firstNotEmpty([
      _read(json, const ['zonaPami', 'ZonaPami']),
      _read(json, const ['zona', 'Zona']),
    ]);
    final block = _firstNotEmpty([
      _read(json, const ['manzana', 'Manzana']),
      '0',
    ]);
    return VenderPrintGeoGrid(
      node: nodeKm == '0' ? node : '$node/${nodeKm}km',
      zone: zone.isEmpty ? '0' : zone,
      block: block,
      satelliteDay: satelliteDayKm == '0'
          ? satelliteDay
          : '$satelliteDay-$satelliteDayKm.$satelliteDayZone',
      satellite24h: '$satellite24h-$satellite24hKm.$satellite24hZone',
      satelliteNode: '$node-$nodeKm.$nodeZone',
    );
  }
}

class VenderPrintLabel {
  const VenderPrintLabel({
    required this.guideNumber,
    required this.senderName,
    required this.senderDocument,
    required this.senderPhone,
    required this.senderAddress,
    required this.senderCity,
    required this.senderPostalCode,
    required this.recipientName,
    required this.recipientDocument,
    required this.recipientPhone,
    required this.recipientAddress,
    required this.recipientCity,
    required this.serviceName,
    required this.timeWindow,
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
    required this.otherValue,
    required this.totalValue,
    required this.commercialValue,
    required this.cashOnDeliveryValue,
    required this.admissionDate,
    required this.estimatedDeliveryDate,
    required this.estimatedDeliveryDateNew,
    required this.destinationPostalCode,
    required this.observation,
    required this.macroZone,
    required this.microZone,
    required this.saleCenterCode,
    required this.routeStops,
    required this.geoGrid,
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
  final String senderPostalCode;
  final String recipientName;
  final String recipientDocument;
  final String recipientPhone;
  final String recipientAddress;
  final String recipientCity;
  final String serviceName;
  final String timeWindow;
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
  final String otherValue;
  final String totalValue;
  final String commercialValue;
  final String cashOnDeliveryValue;
  final String admissionDate;
  final String estimatedDeliveryDate;
  final String estimatedDeliveryDateNew;
  final String destinationPostalCode;
  final String observation;
  final String macroZone;
  final String microZone;
  final String saleCenterCode;
  final List<VenderPrintRouteStop> routeStops;
  final VenderPrintGeoGrid geoGrid;
  final bool fromReprint;
  final bool offline;
  final Map<String, Object?> raw;

  String get displayGuide => guideNumber.trim().isEmpty ? '-' : guideNumber;

  String get zoneLabel {
    if (macroZone.trim().isEmpty || microZone.trim().isEmpty) return '';
    return '${macroZone.trim()}/${microZone.trim()}';
  }

  bool get hasRetirementWindow {
    final base = _dateOnly(estimatedDeliveryDate);
    final next = _dateOnly(estimatedDeliveryDateNew);
    return base.isNotEmpty && next.isNotEmpty && base != next;
  }

  String get chargeValue {
    final payment = paymentMethod.toLowerCase().trim();
    final cod = _amount(cashOnDeliveryValue);
    final transport = _amount(transportValue);
    final insurance = _amount(insuranceValue);
    final others = _amount(otherValue);
    final total = _amount(totalValue);
    if (cod == 0 && payment == 'contado') return '0';
    if (cod > 0 && payment == 'contado') return _amountText(cod);
    if (cod > 0 && payment == 'al cobro') {
      return _amountText(cod + transport + insurance + others);
    }
    if (cod == 0 && payment == 'al cobro') return _amountText(total);
    return _amountText(total);
  }

  String get commercialDisplayValue {
    final value = commercialValue.trim().isNotEmpty
        ? commercialValue
        : declaredValue;
    return _amountText(_amount(value));
  }

  Map<String, Object?> toJson() {
    return {
      ...raw,
      'NumeroGuia': guideNumber,
      'NombreRemitente': senderName,
      'NumeroIdentificacionRemitente': senderDocument,
      'TelefonoRemitente': senderPhone,
      'DireccionRemitente': senderAddress,
      'NombreCiudadRemitente': senderCity,
      'CodigoPostalRemitente': senderPostalCode,
      'NombreDestinatario': recipientName,
      'NumeroIdentificacionDestinatario': recipientDocument,
      'TelefonoDestinatario': recipientPhone,
      'DireccionDestinatario': recipientAddress,
      'NombreCiudadDestinatario': recipientCity,
      'NombreServicio': serviceName,
      'FranjaServicio': timeWindow,
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
      'ValorOtros': otherValue,
      'ValorTotal': totalValue,
      'ValorComercial': commercialValue,
      'ValorContraPago': cashOnDeliveryValue,
      'FechaPreenvio': admissionDate,
      'FechaEstimadaEntrega': estimatedDeliveryDate,
      'FechaEstimadaEntregaNew': estimatedDeliveryDateNew,
      'CodigoPostalDestino': destinationPostalCode,
      'observacion': observation,
      'macroZona': macroZone,
      'microZona': microZone,
      'idCentroServicioOrigen': saleCenterCode,
      'puertasYCasilleros': routeStops.map((item) => item.toJson()).toList(),
      'geoGrid': geoGrid.toJson(),
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
    final routeStops = _mapList(
      json,
      const ['puertasYCasilleros', 'PuertasYCasilleros'],
    ).map(VenderPrintRouteStop.fromJson).where((item) => item.hasData).toList();
    final geoGrid = _geoGrid(json);
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
      senderPostalCode: _firstNotEmpty([
        _read(json, const ['CodigoPostalRemitente', 'codigoPostalRemitente']),
        _read(json, const ['CodigoCiudadRemitente', 'codigoCiudadRemitente']),
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
      timeWindow: _read(json, const [
        'FranjaServicio',
        'franjaServicio',
        'FranjaHoraria',
        'franjaHoraria',
      ]),
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
      otherValue: _read(json, const ['ValorOtros', 'valorOtros']),
      totalValue: _read(json, const ['ValorTotal', 'valorTotal']),
      commercialValue: _read(json, const ['ValorComercial', 'valorComercial']),
      cashOnDeliveryValue: _read(json, const [
        'ValorContraPago',
        'valorContraPago',
      ]),
      admissionDate: _read(json, const [
        'FechaPreenvio',
        'FechaAdmision',
        'fechaAdmision',
      ]),
      estimatedDeliveryDate: _firstNotEmpty([
        _read(json, const ['FechaEstimadaEntrega', 'fechaEstimadaEntrega']),
        _read(json, const [
          'FechaEstimadaEntregaNew',
          'fechaEstimadaEntregaNew',
        ]),
      ]),
      estimatedDeliveryDateNew: _read(json, const [
        'FechaEstimadaEntregaNew',
        'fechaEstimadaEntregaNew',
      ]),
      destinationPostalCode: _firstNotEmpty([
        _read(json, const ['CodigoPostalDestino', 'codigoPostalDestino']),
        _read(destinationGeo, const ['zonaPostal', 'ZonaPostal']),
        _geoPostalCode(json),
      ]),
      observation: _read(json, const [
        'observacion',
        'Observacion',
        'Observaciones',
        'observaciones',
      ]),
      macroZone: _read(json, const ['macroZona', 'MacroZona']),
      microZone: _read(json, const ['microZona', 'MicroZona']),
      saleCenterCode: _read(json, const [
        'idCentroServicioOrigen',
        'IdCentroServicioOrigen',
      ]),
      routeStops: routeStops,
      geoGrid: geoGrid,
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
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, val) => MapEntry('$key', val));
      }
    } on Object {
      return const <String, dynamic>{};
    }
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

List<Map<String, dynamic>> _mapList(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) {
      return value
          .map(printJsonMap)
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map(printJsonMap)
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      } on Object {
        return const <Map<String, dynamic>>[];
      }
    }
  }
  return const <Map<String, dynamic>>[];
}

VenderPrintGeoGrid _geoGrid(Map<String, dynamic> json) {
  final direct = _map(json, const ['geoGrid', 'GeoGrid']);
  if (direct.isNotEmpty) return VenderPrintGeoGrid.fromJson(direct);
  final response = _map(json, const [
    'torreDirGeoDireccionResponse',
    'TorreDirGeoDireccionResponse',
  ]);
  final result = _mapList(response, const ['resultado', 'Resultado']);
  if (result.isNotEmpty) return VenderPrintGeoGrid.fromJson(result.first);
  return const VenderPrintGeoGrid.empty();
}

String _geoPostalCode(Map<String, dynamic> json) {
  final response = _map(json, const [
    'torreDirGeoDireccionResponse',
    'TorreDirGeoDireccionResponse',
  ]);
  final result = _mapList(response, const ['resultado', 'Resultado']);
  if (result.isEmpty) return '';
  return _read(result.first, const [
    'codigoPostalExtendido',
    'CodigoPostalExtendido',
  ]);
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

String _intText(Map<String, dynamic> json, List<String> keys) {
  final text = _read(json, keys);
  if (text.isEmpty) return '0';
  return '${int.tryParse(text) ?? (double.tryParse(text)?.round() ?? 0)}';
}

String _dateOnly(String value) {
  return value.trim().replaceFirst('T', ' ').split(' ').first.trim();
}

double _amount(String value) {
  final clean = value.replaceAll(r'$', '').replaceAll(' ', '').trim();
  if (clean.isEmpty) return 0;
  final commaIndex = clean.lastIndexOf(',');
  final dotIndex = clean.lastIndexOf('.');
  var normalized = clean;
  if (commaIndex >= 0 && dotIndex >= 0) {
    normalized = commaIndex > dotIndex
        ? clean.replaceAll('.', '').replaceAll(',', '.')
        : clean.replaceAll(',', '');
  } else if (commaIndex >= 0) {
    final decimals = clean.length - commaIndex - 1;
    normalized = decimals == 3
        ? clean.replaceAll(',', '')
        : clean.replaceAll(',', '.');
  } else if (dotIndex >= 0) {
    final decimals = clean.length - dotIndex - 1;
    normalized = decimals == 3 ? clean.replaceAll('.', '') : clean;
  }
  normalized = normalized.replaceAll(RegExp(r'[^0-9\.-]'), '');
  return double.tryParse(normalized) ?? 0;
}

String _amountText(double value) {
  if (value <= 0) return '0';
  final fixed = value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index += 1) {
    final fromEnd = whole.length - index;
    buffer.write(whole[index]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
  }
  if (parts.length > 1) buffer.write(',${parts[1]}');
  return buffer.toString();
}
