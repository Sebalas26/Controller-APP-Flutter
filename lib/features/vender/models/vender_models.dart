import 'dart:convert';

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
    final source = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json['Data'] is Map
        ? Map<String, dynamic>.from(json['Data'] as Map)
        : json;
    return VenderGeoAddress(
      id: _readString(source, const [
        'idDireccionGeneral',
        'IdDireccionGeneral',
      ]),
      normalizedAddress: _readString(source, const [
        'direccionNormalizada',
        'DireccionNormalizada',
      ]),
      address: _readString(source, const ['direccion', 'Direccion']),
      neighborhood: _readString(source, const ['barrio', 'Barrio']),
      macroZone: _readString(source, const [
        'zona3',
        'Zona3',
        'macroZona',
        'MacroZona',
      ]),
      microZone: _readString(source, const [
        'zona2',
        'Zona2',
        'microZona',
        'MicroZona',
      ]),
      latitude: _readString(source, const ['latitude', 'Latitude']),
      longitude: _readString(source, const ['longitude', 'Longitude']),
      cityId: _readString(source, const ['idCiudad', 'IdCiudad']),
      localityId: _readString(source, const ['idLocalidad', 'IdLocalidad']),
      addressType: _readString(source, const [
        'tipoDireccion',
        'TipoDireccion',
      ]),
      wrongAddress: _readBool(source, const [
        'direccionErrada',
        'DireccionErrada',
      ]),
      raw: json,
    );
  }
}

class VenderDifficultAccessCenter {
  const VenderDifficultAccessCenter({
    required this.id,
    required this.name,
    required this.address,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String name;
  final String address;
  final Map<String, Object?> raw;

  String get displayName => name.trim().isEmpty ? address.trim() : name.trim();

  factory VenderDifficultAccessCenter.fromJson(Map<String, dynamic> json) {
    return VenderDifficultAccessCenter(
      id: _readString(json, const ['IdCentroServicio', 'idCentroServicio']),
      name: _readString(json, const ['NombreCS', 'nombreCS']),
      address: _readString(json, const ['DireccionPunto', 'direccionPunto']),
      raw: json,
    );
  }
}

class VenderRestrictiveListDebt {
  const VenderRestrictiveListDebt({
    required this.recipient,
    required this.restrictionDate,
    required this.guideNumber,
    required this.value,
    this.raw = const <String, Object?>{},
  });

  final String recipient;
  final String restrictionDate;
  final String guideNumber;
  final double value;
  final Map<String, Object?> raw;

  DateTime? get parsedRestrictionDate {
    final normalized = restrictionDate.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized);
  }

  factory VenderRestrictiveListDebt.fromJson(Map<String, dynamic> json) {
    return VenderRestrictiveListDebt(
      recipient: _readString(json, const ['destinatario', 'Destinatario']),
      restrictionDate: _readString(json, const [
        'fechaRestriccion',
        'FechaRestriccion',
      ]),
      guideNumber: _readString(json, const ['idGuia', 'IdGuia', 'numeroGuia']),
      value:
          _readDouble(json, const [
            'valor',
            'Valor',
            'valorTotal',
          ])?.toDouble() ??
          0,
      raw: json,
    );
  }
}

class VenderRestrictiveListClient {
  const VenderRestrictiveListClient({
    required this.name,
    required this.document,
    required this.phone,
    required this.email,
    required this.address,
    required this.debts,
  });

  final String name;
  final String document;
  final String phone;
  final String email;
  final String address;
  final List<VenderRestrictiveListDebt> debts;

  bool get hasDebts => debts.isNotEmpty;

  factory VenderRestrictiveListClient.fromJson(Map<String, dynamic> json) {
    return VenderRestrictiveListClient(
      name: _readString(json, const ['nombre', 'Nombre']),
      document: _readString(json, const ['documento', 'Documento']),
      phone: _readString(json, const ['celular', 'Celular']),
      email: _readString(json, const ['email', 'Email']),
      address: _readString(json, const ['direccion', 'Direccion']),
      debts: _readList(json, const [
        'deudas',
        'Deudas',
      ]).map(VenderRestrictiveListDebt.fromJson).toList(),
    );
  }

  factory VenderRestrictiveListClient.empty() {
    return const VenderRestrictiveListClient(
      name: '',
      document: '',
      phone: '',
      email: '',
      address: '',
      debts: [],
    );
  }
}

enum VenderRestrictiveListAction { continueCollect, continueCash, cancelSale }

class VenderRestrictiveListResult {
  const VenderRestrictiveListResult({
    required this.sender,
    required this.recipient,
    required this.validRecipientDebts,
    required this.recipientWarningMinimum,
    required this.recipientWarningMaximum,
    this.raw = const <String, Object?>{},
  });

  final VenderRestrictiveListClient sender;
  final VenderRestrictiveListClient recipient;
  final List<VenderRestrictiveListDebt> validRecipientDebts;
  final int recipientWarningMinimum;
  final int recipientWarningMaximum;
  final Map<String, Object?> raw;

  bool get senderHasDebts => sender.hasDebts;

  bool get recipientHasWarning {
    final count = validRecipientDebts.length;
    return count >= recipientWarningMinimum && count <= recipientWarningMaximum;
  }

  bool get recipientHasRestriction =>
      validRecipientDebts.length > recipientWarningMaximum;

  bool get recipientHasDebts => recipientHasWarning || recipientHasRestriction;

  bool get hasAnyRestriction => senderHasDebts || recipientHasDebts;

  double get senderDebtTotal =>
      sender.debts.fold(0, (total, debt) => total + debt.value);

  factory VenderRestrictiveListResult.fromJson(
    Map<String, dynamic> json, {
    required String recipientFilter,
  }) {
    final filter = _parseRestrictiveListFilter(recipientFilter);
    final recipient = VenderRestrictiveListClient.fromJson(
      _readMap(json, const ['destinatario', 'Destinatario']),
    );
    return VenderRestrictiveListResult(
      sender: VenderRestrictiveListClient.fromJson(
        _readMap(json, const ['remitente', 'Remitente']),
      ),
      recipient: recipient,
      validRecipientDebts: _recipientDebtsInRange(
        recipient.debts,
        days: filter.days,
      ),
      recipientWarningMinimum: filter.minimum,
      recipientWarningMaximum: filter.maximum,
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

  factory VenderDraft.fromJson(Map<String, dynamic> json) {
    return VenderDraft(
      createdAt:
          DateTime.tryParse(_readString(json, const ['createdAt'])) ??
          DateTime.now(),
      status: _readString(json, const ['status']),
      guideNumber: _readString(json, const ['guideNumber']),
      origin: _readMap(json, const ['origin']),
      destination: _readMap(json, const ['destination']),
      initialData: _readMap(json, const ['initialData']),
      settlement: _readMap(json, const ['settlement']),
      sender: _readMap(json, const ['sender']),
      recipient: _readMap(json, const ['recipient']),
    );
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

class VenderOfflineAdmissionRecord {
  const VenderOfflineAdmissionRecord({
    required this.id,
    required this.guideNumber,
    required this.requestJson,
    required this.printJson,
  });

  final int id;
  final String guideNumber;
  final String requestJson;
  final String printJson;

  factory VenderOfflineAdmissionRecord.fromRow(Map<String, Object?> row) {
    final json = Map<String, dynamic>.from(row);
    return VenderOfflineAdmissionRecord(
      id: int.tryParse(_readString(json, const ['IdAdmisionOffline'])) ?? 0,
      guideNumber: _readString(json, const ['NumeroGuia']),
      requestJson: _readString(json, const ['ObjetoMensajeriaRequest']),
      printJson: _readString(json, const ['ObjetoADGuiaImpresion']),
    );
  }
}

class VenderAdmissionSyncResult {
  const VenderAdmissionSyncResult({
    required this.guideNumber,
    required this.idPickup,
    required this.idPreInvoice,
    this.message = '',
    this.raw = const <String, Object?>{},
  });

  final String guideNumber;
  final int idPickup;
  final int idPreInvoice;
  final String message;
  final Map<String, Object?> raw;

  factory VenderAdmissionSyncResult.fromResponse(
    Object? data, {
    required String fallbackGuideNumber,
  }) {
    final json = data is Map<String, dynamic>
        ? data
        : data is Map
        ? Map<String, dynamic>.from(data)
        : data is String && data.trim().isNotEmpty
        ? _decodeJsonMap(data)
        : const <String, dynamic>{};
    return VenderAdmissionSyncResult(
      guideNumber:
          _deepString(json, const [
            'NumeroGuia',
            'numeroGuia',
            'guia',
          ]).trim().isNotEmpty
          ? _deepString(json, const ['NumeroGuia', 'numeroGuia', 'guia'])
          : fallbackGuideNumber,
      idPickup: _deepInt(json, const ['IdRecogida', 'idRecogida']),
      idPreInvoice: _deepInt(json, const ['IdPreFactura', 'idPreFactura']),
      message: _deepString(json, const [
        'Mensaje',
        'mensaje',
        'Message',
        'message',
      ]),
      raw: json,
    );
  }
}

class VenderAdmissionSuccessState {
  const VenderAdmissionSuccessState({
    required this.guide,
    required this.supplyNumber,
    required this.message,
  });

  final VenderCollectionGuide guide;
  final String supplyNumber;
  final String message;
}

class VenderCollectionGuide {
  const VenderCollectionGuide({
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
    this.destinationCity = '',
    this.recipientAddress = '',
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
  final String destinationCity;
  final String recipientAddress;
  final int idPickup;
  final int idPreInvoice;

  bool get shouldChargeNow {
    return !isCollectPayment &&
        paymentMethodId != VenderPaymentMethods.credit &&
        totalValue > 0;
  }

  factory VenderCollectionGuide.fromOfflineAdmission({
    required VenderOfflineAdmissionRecord admission,
    required VenderAdmissionSyncResult syncResult,
  }) {
    final request = _decodeJsonMap(admission.requestJson);
    final printPayload = _decodeJsonMap(admission.printJson);
    final guide = _readMap(request, const ['Guia', 'guia']);
    final admissionPreenvio = _readMap(request, const [
      'admisionPreenvio',
      'AdmisionPreenvio',
    ]);
    final forms = _readList(guide, const ['FormasPago', 'formasPago']);
    final firstForm = forms.isEmpty ? const <String, dynamic>{} : forms.first;
    final sender = _readMap(
      _readMap(request, const ['RemitenteDestinatario']),
      const ['PeatonRemitente', 'peatonRemitente'],
    );
    final recipient = _readMap(
      _readMap(request, const ['RemitenteDestinatario']),
      const ['PeatonDestinatario', 'peatonDestinatario'],
    );
    final paymentMethodId =
        _readInt(admissionPreenvio, const ['idFormaPago', 'IdFormaPago']) ??
        _readInt(firstForm, const ['IdFormaPago', 'idFormaPago']) ??
        _readInt(guide, const ['IdFormaPago', 'idFormaPago']) ??
        0;
    final paymentMethodLabel =
        _readString(admissionPreenvio, const [
          'nombreFormaPago',
          'NombreFormaPago',
        ]).trim().isNotEmpty
        ? _readString(admissionPreenvio, const [
            'nombreFormaPago',
            'NombreFormaPago',
          ])
        : _readString(printPayload, const ['FormaPago', 'formaPago']);
    return VenderCollectionGuide(
      guideNumber: syncResult.guideNumber.trim().isNotEmpty
          ? syncResult.guideNumber
          : admission.guideNumber,
      paymentMethodId: paymentMethodId,
      paymentMethodLabel: paymentMethodLabel,
      isCollectPayment:
          _readBool(admissionPreenvio, const ['esAlCobro', 'EsAlCobro']) ||
          _readBool(guide, const ['EsAlCobro', 'esAlCobro']),
      totalValue:
          _readDouble(admissionPreenvio, const ['valorTotal', 'ValorTotal']) ??
          _readDouble(guide, const ['ValorTotal', 'valorTotal']) ??
          _readDouble(printPayload, const ['ValorTotal', 'valorTotal']) ??
          0,
      transportValue:
          _readDouble(admissionPreenvio, const [
            'valorAdmision',
            'ValorAdmision',
          ]) ??
          _readDouble(guide, const ['ValorAdmision', 'valorAdmision']) ??
          _readDouble(printPayload, const [
            'ValorTransporte',
            'valorTransporte',
          ]) ??
          0,
      insuranceValue:
          _readDouble(admissionPreenvio, const [
            'valorPrimaSeguro',
            'ValorPrimaSeguro',
          ]) ??
          _readDouble(guide, const ['ValorPrimaSeguro', 'valorPrimaSeguro']) ??
          _readDouble(printPayload, const ['ValorPrima', 'valorPrima']) ??
          0,
      senderName: _coalesceText([
        _readString(printPayload, const ['NombreRemitente']),
        _readString(sender, const ['nombreCompleto', 'NombreCompleto']),
        [
          _readString(sender, const ['nombre', 'Nombre']),
          _readString(sender, const ['primerApellido', 'PrimerApellido']),
          _readString(sender, const ['segundoApellido', 'SegundoApellido']),
        ].where((part) => part.trim().isNotEmpty).join(' '),
      ]),
      senderDocument: _coalesceText([
        _readString(printPayload, const ['NumeroIdentificacionRemitente']),
        _readString(sender, const ['numeroDocumento', 'NumeroDocumento']),
      ]),
      senderPhone: _coalesceText([
        _readString(printPayload, const ['TelefonoRemitente']),
        _readString(sender, const ['telefono', 'Telefono']),
      ]),
      senderEmail: _coalesceText([
        _readString(printPayload, const ['EmailRemitente']),
        _readString(sender, const ['correo', 'Correo']),
      ]),
      recipientName: _coalesceText([
        _readString(printPayload, const ['NombreDestinatario']),
        [
          _readString(recipient, const ['nombre', 'Nombre']),
          _readString(recipient, const ['primerApellido', 'PrimerApellido']),
          _readString(recipient, const ['segundoApellido', 'SegundoApellido']),
        ].where((part) => part.trim().isNotEmpty).join(' '),
      ]),
      destinationCity: _coalesceText([
        _readString(printPayload, const ['NombreCiudadDestinatario']),
        _readString(printPayload, const ['CiudadDestino']),
        _readString(printPayload, const ['NombreCiudadDestino']),
        _readString(admissionPreenvio, const [
          'nombreCiudadDestino',
          'NombreCiudadDestino',
        ]),
        _readString(guide, const ['CiudadDestino', 'NombreCiudadDestino']),
      ]),
      recipientAddress: _coalesceText([
        _readString(printPayload, const ['DireccionDestinatario']),
        _readString(recipient, const [
          'direccionNormalizada',
          'DireccionNormalizada',
        ]),
        _readString(recipient, const ['direccion', 'Direccion']),
      ]),
      idPickup: syncResult.idPickup,
      idPreInvoice: syncResult.idPreInvoice,
    );
  }
}

class VenderCollectionState {
  const VenderCollectionState({
    required this.guides,
    required this.selectedPaymentMethodId,
    this.confirmed = false,
    this.pickupExecuted = false,
    this.pickupMessage = '',
    this.invoiceNumber = '',
    this.paymentTransactionId = 0,
    this.paymentStatus = '',
    this.paymentMessage = '',
  });

  final List<VenderCollectionGuide> guides;
  final int selectedPaymentMethodId;
  final bool confirmed;
  final bool pickupExecuted;
  final String pickupMessage;
  final String invoiceNumber;
  final int paymentTransactionId;
  final String paymentStatus;
  final String paymentMessage;

  int get guideCount => guides.length;

  int get idPickup {
    for (final guide in guides) {
      if (guide.idPickup > 0) return guide.idPickup;
    }
    return 0;
  }

  int get idPreInvoice {
    for (final guide in guides) {
      if (guide.idPreInvoice > 0) return guide.idPreInvoice;
    }
    return 0;
  }

  double get totalGuidesValue {
    return guides
        .where((guide) => guide.shouldChargeNow)
        .fold(0, (total, guide) => total + guide.totalValue);
  }

  double get pickupValue => 0;

  double get packageValue => 0;

  double get totalToCharge => totalGuidesValue + pickupValue + packageValue;

  int get cashGuideCount => _countPaymentMethod(VenderPaymentMethods.cash);

  int get creditGuideCount => _countPaymentMethod(VenderPaymentMethods.credit);

  int get collectGuideCount => guides.where((guide) {
    return guide.isCollectPayment ||
        guide.paymentMethodId == VenderPaymentMethods.collect;
  }).length;

  String get selectedPaymentMethodName {
    return VenderPaymentMethods.nameFor(selectedPaymentMethodId);
  }

  bool get requiresRemotePayment {
    return totalToCharge > 0 &&
        (selectedPaymentMethodId == VenderPaymentMethods.nequi ||
            selectedPaymentMethodId == VenderPaymentMethods.linkPayment);
  }

  String get actionLabel {
    return switch (selectedPaymentMethodId) {
      VenderPaymentMethods.nequi => 'Continuar Nequi',
      VenderPaymentMethods.linkPayment => 'Continuar link de pago',
      VenderPaymentMethods.interPay => 'Continuar Inter Pay',
      _ => 'Confirmar efectivo',
    };
  }

  VenderCollectionState copyWith({
    List<VenderCollectionGuide>? guides,
    int? selectedPaymentMethodId,
    bool? confirmed,
    bool? pickupExecuted,
    String? pickupMessage,
    String? invoiceNumber,
    int? paymentTransactionId,
    String? paymentStatus,
    String? paymentMessage,
    bool clearPaymentTracking = false,
  }) {
    return VenderCollectionState(
      guides: guides ?? this.guides,
      selectedPaymentMethodId:
          selectedPaymentMethodId ?? this.selectedPaymentMethodId,
      confirmed: confirmed ?? this.confirmed,
      pickupExecuted: pickupExecuted ?? this.pickupExecuted,
      pickupMessage: pickupMessage ?? this.pickupMessage,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      paymentTransactionId: clearPaymentTracking
          ? 0
          : paymentTransactionId ?? this.paymentTransactionId,
      paymentStatus: clearPaymentTracking
          ? ''
          : paymentStatus ?? this.paymentStatus,
      paymentMessage: clearPaymentTracking
          ? ''
          : paymentMessage ?? this.paymentMessage,
    );
  }

  int _countPaymentMethod(int id) {
    return guides.where((guide) => guide.paymentMethodId == id).length;
  }
}

class VenderPickupExecutionResult {
  const VenderPickupExecutionResult({
    required this.invoiceNumber,
    required this.message,
    this.raw = const <String, Object?>{},
  });

  final String invoiceNumber;
  final String message;
  final Map<String, Object?> raw;

  factory VenderPickupExecutionResult.fromResponse(Object? data) {
    final rawText = data?.toString().trim() ?? '';
    final json = data is Map<String, dynamic>
        ? data
        : data is Map
        ? Map<String, dynamic>.from(data)
        : data is String && data.trim().startsWith('{')
        ? _decodeJsonMap(data)
        : const <String, dynamic>{};
    final invoice = _coalesceText([
      _deepString(json, const [
        'NumeroFactura',
        'numeroFactura',
        'Factura',
        'factura',
        'data',
      ]),
      rawText,
    ]);
    final message = _coalesceText([
      _deepString(json, const ['Mensaje', 'mensaje', 'Message', 'message']),
      'La recogida fue cerrada de forma exitosa.',
    ]);
    return VenderPickupExecutionResult(
      invoiceNumber: invoice,
      message: message,
      raw: json,
    );
  }
}

class _RestrictiveListFilter {
  const _RestrictiveListFilter({
    required this.days,
    required this.minimum,
    required this.maximum,
  });

  final int days;
  final int minimum;
  final int maximum;
}

_RestrictiveListFilter _parseRestrictiveListFilter(String value) {
  final parts = value
      .split(',')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
  final days = parts.isNotEmpty && parts[0] > 0 ? parts[0] : 90;
  final minimum = parts.length > 1 && parts[1] > 0 ? parts[1] : 2;
  final maximum = parts.length > 2 && parts[2] > 0 ? parts[2] : 3;
  return _RestrictiveListFilter(days: days, minimum: minimum, maximum: maximum);
}

List<VenderRestrictiveListDebt> _recipientDebtsInRange(
  List<VenderRestrictiveListDebt> debts, {
  required int days,
}) {
  final now = DateTime.now();
  final todayLimit = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final lowerLimit = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days));
  return debts.where((debt) {
    final date = debt.parsedRestrictionDate;
    if (date == null) return false;
    return !date.isBefore(lowerLimit) && !date.isAfter(todayLimit);
  }).toList();
}

class VenderPaymentMethods {
  const VenderPaymentMethods._();

  static const cash = 1;
  static const credit = 2;
  static const collect = 3;
  static const interPay = 4;
  static const nequi = 5;
  static const linkPayment = 6;

  static const chargeable = <int>[cash, nequi, linkPayment, interPay];

  static String nameFor(int id) {
    return switch (id) {
      cash => 'Efectivo',
      credit => 'Credito',
      collect => 'Al cobro',
      interPay => 'Inter Pay',
      nequi => 'Nequi',
      linkPayment => 'Link de pago',
      _ => 'Efectivo',
    };
  }
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

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _readDouble(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is double) return value;
  if (value is num) return value.toDouble();
  final text = value?.toString().replaceAll(',', '.').trim() ?? '';
  return double.tryParse(text);
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

Map<String, dynamic> _decodeJsonMap(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on Object {
    return const <String, dynamic>{};
  }
  return const <String, dynamic>{};
}

String _coalesceText(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _deepString(Object? value, List<String> keys) {
  if (value is Map<String, dynamic>) {
    for (final key in keys) {
      if (value.containsKey(key) && value[key] != null) {
        return value[key].toString();
      }
    }
    for (final child in value.values) {
      final found = _deepString(child, keys);
      if (found.trim().isNotEmpty) return found;
    }
  } else if (value is Map) {
    return _deepString(Map<String, dynamic>.from(value), keys);
  } else if (value is List) {
    for (final child in value) {
      final found = _deepString(child, keys);
      if (found.trim().isNotEmpty) return found;
    }
  }
  return '';
}

int _deepInt(Object? value, List<String> keys) {
  final text = _deepString(value, keys);
  return int.tryParse(text.trim()) ?? 0;
}
