class CatalogOption {
  const CatalogOption({
    required this.id,
    required this.label,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String label;
  final Map<String, Object?> raw;

  bool get hasValue => id.trim().isNotEmpty || label.trim().isNotEmpty;

  Map<String, Object?> toJson() {
    return {'id': id, 'label': label, 'raw': raw};
  }
}

class VenderCatalogs {
  const VenderCatalogs({
    required this.destinationCities,
    required this.deliveryTypes,
    required this.paymentMethods,
    required this.shippingTypes,
    required this.services,
    required this.addressTypes,
    required this.propertyTypes,
    required this.identificationTypes,
    required this.packages,
    required this.parameters,
    required this.availableSupplies,
    required this.usedSupplies,
    required this.pendingOfflineAdmissions,
  });

  final List<CatalogOption> destinationCities;
  final List<CatalogOption> deliveryTypes;
  final List<CatalogOption> paymentMethods;
  final List<CatalogOption> shippingTypes;
  final List<CatalogOption> services;
  final List<CatalogOption> addressTypes;
  final List<CatalogOption> propertyTypes;
  final List<CatalogOption> identificationTypes;
  final List<CatalogOption> packages;
  final Map<String, String> parameters;
  final int availableSupplies;
  final int usedSupplies;
  final int pendingOfflineAdmissions;

  int get totalSupplies => availableSupplies + usedSupplies;

  double get usedSuppliesPercent {
    final total = totalSupplies;
    if (total == 0) return 0;
    return (usedSupplies / total) * 100;
  }

  bool get hasAdmissionCatalogs {
    return destinationCities.isNotEmpty &&
        deliveryTypes.isNotEmpty &&
        paymentMethods.isNotEmpty;
  }
}

class VenderValueRange {
  const VenderValueRange({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;

  bool accepts(double value) {
    final lowerOk = minimum <= 0 || value >= minimum;
    final upperOk = maximum <= 0 || value <= maximum;
    return lowerOk && upperOk;
  }
}

class VenderServiceQuote {
  const VenderServiceQuote({
    required this.id,
    required this.name,
    required this.baseValue,
    required this.insuranceValue,
    required this.totalValue,
    this.deliveryDays = 0,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String name;
  final double baseValue;
  final double insuranceValue;
  final double totalValue;
  final int deliveryDays;
  final Map<String, Object?> raw;

  CatalogOption get asOption => CatalogOption(id: id, label: name, raw: raw);
}

class VenderSupply {
  const VenderSupply({
    required this.guideNumber,
    required this.expirationDate,
    this.raw = const <String, Object?>{},
  });

  final String guideNumber;
  final String expirationDate;
  final Map<String, Object?> raw;

  factory VenderSupply.fromJson(Map<String, dynamic> json) {
    return VenderSupply(
      guideNumber: _readString(json, const [
        'NoSuministro',
        'NumeroGuia',
        'numeroGuia',
        'guia',
      ]),
      expirationDate: _readString(json, const [
        'FechaVencimiento',
        'fechaVencimiento',
      ]),
      raw: json,
    );
  }
}

class VenderPersonRemoteData {
  const VenderPersonRemoteData({
    required this.requiresConfirmation,
    required this.message,
    required this.principal,
    required this.conflicts,
  });

  final bool requiresConfirmation;
  final String message;
  final VenderCustomer principal;
  final List<VenderCustomer> conflicts;

  factory VenderPersonRemoteData.fromJson(Map<String, dynamic> json) {
    return VenderPersonRemoteData(
      requiresConfirmation: _readBool(json, const ['requiereConfirmacion']),
      message: _readString(json, const ['mensaje', 'Message']),
      principal: VenderCustomer.fromJson(
        _readMap(json, const ['clientePrincipal']),
      ),
      conflicts: _readList(json, const [
        'clientesEnConflicto',
      ]).map(VenderCustomer.fromJson).toList(),
    );
  }
}

class VenderCustomer {
  const VenderCustomer({
    required this.id,
    required this.identificationType,
    required this.document,
    required this.names,
    required this.firstLastName,
    required this.secondLastName,
    required this.phone,
    required this.email,
    required this.paymentAtHome,
    required this.addresses,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String identificationType;
  final String document;
  final String names;
  final String firstLastName;
  final String secondLastName;
  final String phone;
  final String email;
  final bool paymentAtHome;
  final List<VenderGeoAddress> addresses;
  final Map<String, Object?> raw;

  bool get hasIdentity => document.trim().isNotEmpty;

  factory VenderCustomer.empty() {
    return const VenderCustomer(
      id: '',
      identificationType: '',
      document: '',
      names: '',
      firstLastName: '',
      secondLastName: '',
      phone: '',
      email: '',
      paymentAtHome: false,
      addresses: [],
    );
  }

  factory VenderCustomer.fromJson(Map<String, dynamic> json) {
    return VenderCustomer(
      id: _readString(json, const ['idClienteContado', 'IdClienteContado']),
      identificationType: _readString(json, const [
        'idTipoIdentificacion',
        'IdTipoIdentificacion',
      ]),
      document: _readString(json, const ['identificacion', 'Identificacion']),
      names: _readString(json, const ['nombres', 'Nombres']),
      firstLastName: _readString(json, const [
        'primerApellido',
        'PrimerApellido',
      ]),
      secondLastName: _readString(json, const [
        'segundoApellido',
        'SegundoApellido',
      ]),
      phone: _readString(json, const ['telefono', 'Telefono']),
      email: _readString(json, const ['email', 'Email']),
      paymentAtHome: _readBool(json, const ['esPagoEnCasa', 'EsPagoEnCasa']),
      addresses: _readList(json, const [
        'direcciones',
        'Direcciones',
      ]).map(VenderGeoAddress.fromJson).toList(),
      raw: json,
    );
  }
}

class VenderGeoAddress {
  const VenderGeoAddress({
    required this.id,
    required this.normalizedAddress,
    required this.address,
    required this.neighborhood,
    required this.macroZone,
    required this.microZone,
    required this.latitude,
    required this.longitude,
    required this.cityId,
    required this.localityId,
    required this.addressType,
    required this.wrongAddress,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String normalizedAddress;
  final String address;
  final String neighborhood;
  final String macroZone;
  final String microZone;
  final String latitude;
  final String longitude;
  final String cityId;
  final String localityId;
  final String addressType;
  final bool wrongAddress;
  final Map<String, Object?> raw;

  bool get isValid {
    return !wrongAddress &&
        macroZone.trim().isNotEmpty &&
        microZone.trim().isNotEmpty;
  }

  String get displayAddress {
    if (normalizedAddress.trim().isNotEmpty) return normalizedAddress.trim();
    return address.trim();
  }

  factory VenderGeoAddress.fromJson(Map<String, dynamic> json) {
    return VenderGeoAddress(
      id: _readString(json, const ['idDireccionGeneral', 'IdDireccionGeneral']),
      normalizedAddress: _readString(json, const [
        'direccionNormalizada',
        'DireccionNormalizada',
      ]),
      address: _readString(json, const ['direccion', 'Direccion']),
      neighborhood: _readString(json, const ['barrio', 'Barrio']),
      macroZone: _readString(json, const ['macroZona', 'MacroZona']),
      microZone: _readString(json, const ['microZona', 'MicroZona']),
      latitude: _readString(json, const ['latitude', 'Latitude']),
      longitude: _readString(json, const ['longitude', 'Longitude']),
      cityId: _readString(json, const ['idCiudad', 'IdCiudad']),
      localityId: _readString(json, const ['idLocalidad', 'IdLocalidad']),
      addressType: _readString(json, const ['tipoDireccion', 'TipoDireccion']),
      wrongAddress: _readBool(json, const [
        'direccionErrada',
        'DireccionErrada',
      ]),
      raw: json,
    );
  }
}

class VenderDraft {
  const VenderDraft({
    required this.createdAt,
    required this.status,
    required this.guideNumber,
    required this.origin,
    required this.destination,
    required this.initialData,
    required this.settlement,
    required this.sender,
    required this.recipient,
  });

  final DateTime createdAt;
  final String status;
  final String guideNumber;
  final Map<String, Object?> origin;
  final Map<String, Object?> destination;
  final Map<String, Object?> initialData;
  final Map<String, Object?> settlement;
  final Map<String, Object?> sender;
  final Map<String, Object?> recipient;

  VenderDraft copyWith({String? status, String? guideNumber}) {
    return VenderDraft(
      createdAt: createdAt,
      status: status ?? this.status,
      guideNumber: guideNumber ?? this.guideNumber,
      origin: origin,
      destination: destination,
      initialData: initialData,
      settlement: settlement,
      sender: sender,
      recipient: recipient,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'guideNumber': guideNumber,
      'origin': origin,
      'destination': destination,
      'initialData': initialData,
      'settlement': settlement,
      'sender': sender,
      'recipient': recipient,
    };
  }
}

class VenderSaveResult {
  const VenderSaveResult({
    required this.id,
    required this.guideNumber,
    required this.status,
  });

  final int id;
  final String guideNumber;
  final String status;
}

class VenderLocalException implements Exception {
  const VenderLocalException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VenderRemoteException implements Exception {
  const VenderRemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key].toString();
  }
  return '';
}

bool _readBool(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'si' || text == 'sí';
}

Object? _readValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _readList(
  Map<String, dynamic> json,
  List<String> keys,
) {
  final value = _readValue(json, keys);
  if (value is! List) return const [];
  return value
      .whereType<Object?>()
      .map(
        (item) => item is Map<String, dynamic>
            ? item
            : item is Map
            ? Map<String, dynamic>.from(item)
            : null,
      )
      .whereType<Map<String, dynamic>>()
      .toList();
}
