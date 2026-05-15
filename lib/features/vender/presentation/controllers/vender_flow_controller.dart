import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../data/vender_local_repository.dart';
import '../../data/vender_remote_repository.dart';
import '../../models/vender_models.dart';

enum VenderPersonKind { sender, recipient }

class VenderFlowController extends ChangeNotifier {
  VenderFlowController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    VenderLocalRepository? localRepository,
    VenderRemoteRepository? remoteRepository,
  }) : localRepository = localRepository ?? VenderLocalRepository(),
       remoteRepository = remoteRepository ?? VenderRemoteRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final VenderLocalRepository localRepository;
  final VenderRemoteRepository remoteRepository;

  final preGuide = TextEditingController();
  final pieces = TextEditingController(text: '1');
  final weightScale = TextEditingController();
  final weightVolume = TextEditingController();
  final length = TextEditingController();
  final width = TextEditingController();
  final height = TextEditingController();
  final declaredValue = TextEditingController();
  final securityBag = TextEditingController();
  final content = TextEditingController();
  final observations = TextEditingController();

  final senderDocument = TextEditingController();
  final senderPhone = TextEditingController();
  final senderName = TextEditingController();
  final senderFirstLastName = TextEditingController();
  final senderSecondLastName = TextEditingController();
  final senderStreet = TextEditingController();
  final senderNumber = TextEditingController();
  final senderComplement = TextEditingController();
  final senderNeighborhood = TextEditingController();
  final senderAddress = TextEditingController();
  final senderEmail = TextEditingController();

  final recipientDocument = TextEditingController();
  final recipientPhone = TextEditingController();
  final recipientName = TextEditingController();
  final recipientFirstLastName = TextEditingController();
  final recipientSecondLastName = TextEditingController();
  final recipientStreet = TextEditingController();
  final recipientNumber = TextEditingController();
  final recipientComplement = TextEditingController();
  final recipientNeighborhood = TextEditingController();
  final recipientAddress = TextEditingController();
  final recipientEmail = TextEditingController();

  VenderCatalogs? catalogs;
  List<CatalogOption> deliveryTypes = const [];
  List<CatalogOption> shippingTypes = const [];
  List<VenderServiceQuote> serviceQuotes = const [];
  VenderValueRange valueRange = const VenderValueRange(minimum: 0, maximum: 0);

  CatalogOption? destinationCity;
  CatalogOption? deliveryType;
  CatalogOption? paymentMethod;
  CatalogOption? shippingType;
  VenderServiceQuote? selectedQuote;
  CatalogOption? senderIdentificationType;
  CatalogOption? senderAddressType;
  CatalogOption? senderPropertyType;
  CatalogOption? recipientIdentificationType;
  CatalogOption? recipientAddressType;
  CatalogOption? recipientPropertyType;
  CatalogOption? selectedPackage;

  VenderGeoAddress? senderGeoAddress;
  VenderGeoAddress? recipientGeoAddress;
  Map<String, dynamic>? preenvioData;
  Map<String, dynamic>? guideData;

  int currentStep = 0;
  int highestStep = 0;
  int priceListId = 0;
  bool loading = true;
  bool saving = false;
  bool busyRemote = false;
  bool paymentAtHome = false;
  bool contentChecked = false;
  bool senderSouth = false;
  bool recipientSouth = false;
  bool senderNotification = true;
  bool recipientNotification = true;
  String? statusMessage;
  String? errorMessage;

  double get finalWeight {
    return math.max(
      _readDouble(weightScale.text),
      _readDouble(weightVolume.text),
    );
  }

  double get commercialValue => _readDouble(declaredValue.text);

  bool get hasCatalogs => catalogs?.hasAdmissionCatalogs ?? false;

  bool get hasAvailableSupplies => (catalogs?.availableSupplies ?? 0) > 0;

  Future<void> initialize() async {
    try {
      await _guard(() async {
        loading = true;
        notifyListeners();

        final loadedCatalogs = await localRepository.loadCatalogs(
          appInformation,
        );
        catalogs = loadedCatalogs;
        priceListId = await localRepository.currentPriceListId();
        deliveryTypes = priceListId > 0
            ? await localRepository.loadDeliveryTypesForPriceList(priceListId)
            : loadedCatalogs.deliveryTypes;
        shippingTypes = loadedCatalogs.shippingTypes;
        _applyDefaults(loadedCatalogs);
        statusMessage = 'Catalogos de Vender cargados.';
        if (loadedCatalogs.availableSupplies <= 0) {
          statusMessage =
              'No hay suministros disponibles. Sin suministros no se puede iniciar una venta.';
        }
      });
    } on Object {
      // The controller keeps errorMessage for the UI.
    }
    loading = false;
    notifyListeners();
  }

  void setStep(int value) {
    if (value > highestStep) return;
    currentStep = value;
    notifyListeners();
  }

  void previousStep() {
    if (currentStep <= 0) return;
    currentStep -= 1;
    notifyListeners();
  }

  Future<void> nextStep() async {
    switch (currentStep) {
      case 0:
        _requireSuppliesAvailable();
        await prepareSettlement();
        _advanceTo(1);
        return;
      case 1:
        _require(selectedQuote != null, 'Selecciona un servicio liquidado.');
        _advanceTo(2);
        return;
      case 2:
        _validatePerson(VenderPersonKind.sender);
        _advanceTo(3);
        return;
      case 3:
        _validatePerson(VenderPersonKind.recipient);
        _advanceTo(4);
        return;
      default:
        await saveDraft(reserveSupply: true);
    }
  }

  Future<void> verifyPreguide() async {
    final guide = preGuide.text.trim();
    _require(guide.isNotEmpty, 'Ingresa el numero de pregua/preenvio.');
    await _remoteGuard(() async {
      final preenvio = await remoteRepository.fetchPreenvio(apiConfig, guide);
      final guideInfo = await remoteRepository.fetchGuideByPreguide(
        config: apiConfig,
        appInformation: appInformation,
        preguideNumber: guide,
      );
      preenvioData = preenvio;
      guideData = guideInfo;
      statusMessage = preenvio == null && guideInfo == null
          ? 'No se encontro informacion remota para el preenvio.'
          : 'Preenvio verificado contra servicios remotos.';
    });
  }

  Future<void> prepareSettlement() async {
    _validateInitial();
    _requireSuppliesAvailable();
    await _guard(() async {
      final weight = finalWeight;
      valueRange = await localRepository.declaredValueRange(weight);
      if (!valueRange.accepts(commercialValue)) {
        throw VenderLocalException(
          'El valor comercial debe estar entre ${_money(valueRange.minimum)} '
          'y ${_money(valueRange.maximum)}.',
        );
      }
      shippingTypes = await localRepository.loadShippingTypesForWeight(weight);
      if (shippingTypes.isNotEmpty &&
          !shippingTypes.any((item) => item.id == shippingType?.id)) {
        shippingType = shippingTypes.first;
      }
      await quoteServices();
    });
  }

  Future<void> quoteServices() async {
    _validateInitial(requireShippingType: false);
    _requireSuppliesAvailable();
    await _guard(() async {
      final quotes = await localRepository.quoteServices(
        appInformation: appInformation,
        destinationCity: destinationCity!,
        deliveryType: deliveryType!,
        paymentMethod: paymentMethod ?? const CatalogOption(id: '', label: ''),
        shippingType: shippingType ?? const CatalogOption(id: '', label: ''),
        weight: finalWeight,
        declaredValue: commercialValue,
      );
      serviceQuotes = quotes;
      selectedQuote = quotes.isNotEmpty ? quotes.first : null;
      statusMessage = quotes.isEmpty
          ? 'No hay servicios habilitados para los datos ingresados.'
          : 'Liquidacion calculada con tarifas locales.';
    });
  }

  Future<void> lookupPerson(VenderPersonKind kind) async {
    _validatePersonIdentity(kind);
    final type = _identificationType(kind)!;
    await _remoteGuard(() async {
      final result = await remoteRepository.lookupCustomerKey(
        config: apiConfig,
        appInformation: appInformation,
        localityId: kind == VenderPersonKind.sender
            ? appInformation.idCiudad
            : destinationCity?.id ?? '',
        identificationType: type.id,
        document: _document(kind).text.trim(),
        phone: _phone(kind).text.trim(),
      );
      if (result.principal.hasIdentity && !result.requiresConfirmation) {
        _fillPerson(kind, result.principal);
      }
      statusMessage = result.message.trim().isNotEmpty
          ? result.message
          : result.requiresConfirmation
          ? 'El cliente requiere confirmacion antes de usar sus datos.'
          : 'Cliente consultado en Torre Direcciones.';
    });
  }

  Future<void> geocodePerson(VenderPersonKind kind) async {
    _validateAddress(kind);
    final cityId = kind == VenderPersonKind.sender
        ? appInformation.idCiudad
        : destinationCity?.id ?? '';
    await _remoteGuard(() async {
      final cityHasGeo = await localRepository.cityHasGeoReference(cityId);
      final specialCity = await localRepository.isSpecialCity(cityId);
      final cardinality = await localRepository.cityHasCardinality(cityId);
      final address = await remoteRepository.geocodeAddress(
        config: apiConfig,
        appInformation: appInformation,
        cityId: cityId,
        addressType: _addressType(kind)!,
        propertyType: _propertyType(kind)!,
        number: _number(kind).text.trim(),
        street: _street(kind).text.trim(),
        neighborhood: _neighborhood(kind).text.trim(),
        south: cardinality && _south(kind),
        cityHasGeoReference: cityHasGeo,
        specialCity: specialCity,
      );
      if (kind == VenderPersonKind.sender) {
        senderGeoAddress = address;
        senderAddress.text = address.displayAddress;
        if (address.neighborhood.trim().isNotEmpty) {
          senderNeighborhood.text = address.neighborhood;
        }
      } else {
        recipientGeoAddress = address;
        recipientAddress.text = address.displayAddress;
        if (address.neighborhood.trim().isNotEmpty) {
          recipientNeighborhood.text = address.neighborhood;
        }
      }
      statusMessage = 'Direccion georreferenciada correctamente.';
    });
  }

  Future<void> refreshSupplies({int? targetAvailable}) async {
    final target = targetAvailable ?? _configuredSupplyTarget();
    final current = catalogs?.availableSupplies ?? 0;
    final amount = math.max(0, target - current);
    if (amount == 0) {
      statusMessage = 'El mensajero ya tiene suficientes suministros locales.';
      notifyListeners();
      return;
    }
    await _remoteGuard(() async {
      final supplies = await remoteRepository.refreshSupplies(
        config: apiConfig,
        appInformation: appInformation,
        amount: amount,
      );
      await localRepository.insertSupplies(supplies);
      catalogs = await localRepository.loadCatalogs(appInformation);
      statusMessage = 'Suministros recargados: ${supplies.length}.';
    });
  }

  Future<void> synchronizeOfflineAdmissions() async {
    await _remoteGuard(() async {
      final admissions = await localRepository.pendingOfflineAdmissions();
      if (admissions.isEmpty) {
        statusMessage = 'No hay admisiones offline para sincronizar.';
        return;
      }
      var synchronized = 0;
      final failedGuides = <String>[];
      for (final admission in admissions) {
        try {
          await remoteRepository.synchronizeOfflineAdmission(
            config: apiConfig,
            appInformation: appInformation,
            admission: admission,
          );
          await localRepository.markOfflineAdmissionSynchronized(admission);
          synchronized += 1;
        } on Object {
          failedGuides.add(admission.guideNumber);
        }
      }
      catalogs = await localRepository.loadCatalogs(appInformation);
      if (failedGuides.isNotEmpty) {
        throw VenderRemoteException(
          'Se sincronizaron $synchronized de ${admissions.length} admisiones. '
          'Pendientes: ${failedGuides.take(3).join(', ')}.',
        );
      }
      statusMessage = 'Sincronizacion exitosa de $synchronized admisiones.';
    });
  }

  int _configuredSupplyTarget() {
    final parameters = catalogs?.parameters ?? const <String, String>{};
    for (final key in const ['CantidadSuministros', 'MaximoGuiasOffLine']) {
      final value = int.tryParse((parameters[key] ?? '').trim()) ?? 0;
      if (value > 0) return value;
    }
    return 200;
  }

  Future<void> saveDraft({required bool reserveSupply}) async {
    _validateInitial();
    _require(selectedQuote != null, 'Selecciona un servicio liquidado.');
    _validatePerson(VenderPersonKind.sender);
    _validatePerson(VenderPersonKind.recipient);

    saving = true;
    notifyListeners();
    try {
      await _guard(() async {
        final result = await localRepository.saveDraft(
          draft: _buildDraft(),
          appInformation: appInformation,
          reserveSupply: reserveSupply,
        );
        var finalMessage =
            'Admision guardada localmente (${result.status}) con guia ${result.guideNumber}.';
        if (reserveSupply && !offline) {
          final synchronized = await _trySynchronizeSavedAdmission(
            result.guideNumber,
          );
          finalMessage = synchronized
              ? 'Admision registrada y sincronizada con guia ${result.guideNumber}.'
              : 'Admision guardada offline con guia ${result.guideNumber}; queda pendiente para sincronizar.';
        }
        catalogs = await localRepository.loadCatalogs(appInformation);
        statusMessage = finalMessage;
      });
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> _trySynchronizeSavedAdmission(String guideNumber) async {
    final admission = await localRepository.pendingOfflineAdmissionByGuide(
      guideNumber,
    );
    if (admission == null) return false;
    try {
      await remoteRepository.synchronizeOfflineAdmission(
        config: apiConfig,
        appInformation: appInformation,
        admission: admission,
      );
      await localRepository.markOfflineAdmissionSynchronized(admission);
      return true;
    } on Object {
      return false;
    }
  }

  void calculateVolumeWeight() {
    final volumetric =
        (_readDouble(length.text) *
            _readDouble(width.text) *
            _readDouble(height.text)) /
        6000;
    if (volumetric <= 0) return;
    weightVolume.text = volumetric.toStringAsFixed(2);
    notifyListeners();
  }

  void selectDestination(CatalogOption? value) {
    destinationCity = value;
    selectedQuote = null;
    serviceQuotes = const [];
    notifyListeners();
  }

  void selectDeliveryType(CatalogOption? value) {
    deliveryType = value;
    selectedQuote = null;
    serviceQuotes = const [];
    notifyListeners();
  }

  void selectPaymentMethod(CatalogOption? value) {
    paymentMethod = value;
    notifyListeners();
  }

  void selectShippingType(CatalogOption? value) {
    shippingType = value;
    notifyListeners();
  }

  void selectQuote(VenderServiceQuote value) {
    selectedQuote = value;
    notifyListeners();
  }

  void setSelectedPackage(CatalogOption? value) {
    selectedPackage = value;
    notifyListeners();
  }

  void setIdentificationType(VenderPersonKind kind, CatalogOption? value) {
    if (kind == VenderPersonKind.sender) {
      senderIdentificationType = value;
    } else {
      recipientIdentificationType = value;
    }
    notifyListeners();
  }

  void setAddressType(VenderPersonKind kind, CatalogOption? value) {
    if (kind == VenderPersonKind.sender) {
      senderAddressType = value;
    } else {
      recipientAddressType = value;
    }
    notifyListeners();
  }

  void setPropertyType(VenderPersonKind kind, CatalogOption? value) {
    if (kind == VenderPersonKind.sender) {
      senderPropertyType = value;
    } else {
      recipientPropertyType = value;
    }
    notifyListeners();
  }

  void setPaymentAtHome(bool value) {
    paymentAtHome = value;
    notifyListeners();
  }

  void setContentChecked(bool value) {
    contentChecked = value;
    notifyListeners();
  }

  void setSouth(VenderPersonKind kind, bool value) {
    if (kind == VenderPersonKind.sender) {
      senderSouth = value;
    } else {
      recipientSouth = value;
    }
    notifyListeners();
  }

  void setNotification(VenderPersonKind kind, bool value) {
    if (kind == VenderPersonKind.sender) {
      senderNotification = value;
    } else {
      recipientNotification = value;
    }
    notifyListeners();
  }

  void copySenderToRecipient() {
    recipientName.text = senderName.text;
    recipientFirstLastName.text = senderFirstLastName.text;
    recipientSecondLastName.text = senderSecondLastName.text;
    recipientPhone.text = senderPhone.text;
    recipientEmail.text = senderEmail.text;
    recipientAddressType = senderAddressType;
    recipientPropertyType = senderPropertyType;
    recipientStreet.text = senderStreet.text;
    recipientNumber.text = senderNumber.text;
    recipientComplement.text = senderComplement.text;
    recipientNeighborhood.text = senderNeighborhood.text;
    recipientAddress.text = senderAddress.text;
    recipientSouth = senderSouth;
    notifyListeners();
  }

  VenderDraft _buildDraft() {
    return VenderDraft(
      createdAt: DateTime.now(),
      status: 'draft',
      guideNumber: preGuide.text.trim(),
      origin: {
        'cityId': appInformation.idCiudad,
        'cityLabel': appInformation.nombreCiudad,
        'serviceCenterId': appInformation.idCentroServicio,
        'serviceCenterLabel': appInformation.nombreCentroServicio,
      },
      destination: {
        'cityId': destinationCity?.id,
        'cityLabel': destinationCity?.label,
        'cityRaw': destinationCity?.raw,
        'deliveryTypeId': deliveryType?.id,
        'deliveryTypeLabel': deliveryType?.label,
      },
      initialData: {
        'preGuide': preGuide.text.trim(),
        'pieces': pieces.text.trim(),
        'weightScale': weightScale.text.trim(),
        'weightVolume': weightVolume.text.trim(),
        'length': length.text.trim(),
        'width': width.text.trim(),
        'height': height.text.trim(),
        'finalWeight': finalWeight,
        'declaredValue': commercialValue,
        'paymentMethodId': paymentMethod?.id,
        'paymentMethodLabel': paymentMethod?.label,
        'paymentAtHome': paymentAtHome,
        'preenvio': preenvioData,
        'guide': guideData,
      },
      settlement: {
        'shippingTypeId': shippingType?.id,
        'shippingTypeLabel': shippingType?.label,
        'serviceId': selectedQuote?.id,
        'serviceLabel': selectedQuote?.name,
        'deliveryDays': selectedQuote?.deliveryDays,
        'baseValue': selectedQuote?.baseValue,
        'insuranceValue': selectedQuote?.insuranceValue,
        'totalValue': selectedQuote?.totalValue,
        'securityBag': securityBag.text.trim(),
        'content': content.text.trim(),
        'observations': observations.text.trim(),
        'contentChecked': contentChecked,
        'packageId': selectedPackage?.id,
        'packageLabel': selectedPackage?.label,
      },
      sender: _personPayload(VenderPersonKind.sender),
      recipient: _personPayload(VenderPersonKind.recipient),
    );
  }

  Map<String, Object?> _personPayload(VenderPersonKind kind) {
    final geo = kind == VenderPersonKind.sender
        ? senderGeoAddress
        : recipientGeoAddress;
    return {
      'identificationTypeId': _identificationType(kind)?.id,
      'identificationTypeLabel': _identificationType(kind)?.label,
      'document': _document(kind).text.trim(),
      'phone': _phone(kind).text.trim(),
      'name': _name(kind).text.trim(),
      'firstLastName': _firstLastName(kind).text.trim(),
      'secondLastName': _secondLastName(kind).text.trim(),
      'addressTypeId': _addressType(kind)?.id,
      'addressTypeLabel': _addressType(kind)?.label,
      'street': _street(kind).text.trim(),
      'number': _number(kind).text.trim(),
      'south': _south(kind),
      'propertyTypeId': _propertyType(kind)?.id,
      'propertyTypeLabel': _propertyType(kind)?.label,
      'complement': _complement(kind).text.trim(),
      'neighborhood': _neighborhood(kind).text.trim(),
      'address': _address(kind).text.trim(),
      'email': _email(kind).text.trim(),
      'notification': kind == VenderPersonKind.sender
          ? senderNotification
          : recipientNotification,
      'geo': geo?.raw,
    };
  }

  void _applyDefaults(VenderCatalogs loadedCatalogs) {
    destinationCity ??= _firstOrNull(loadedCatalogs.destinationCities);
    deliveryType ??= _firstOrNull(deliveryTypes);
    paymentMethod ??= _firstOrNull(loadedCatalogs.paymentMethods);
    shippingType ??= _firstOrNull(shippingTypes);
    senderIdentificationType ??= _firstOrNull(
      loadedCatalogs.identificationTypes,
    );
    senderAddressType ??= _firstOrNull(loadedCatalogs.addressTypes);
    senderPropertyType ??= _firstOrNull(loadedCatalogs.propertyTypes);
    recipientIdentificationType ??= _firstOrNull(
      loadedCatalogs.identificationTypes,
    );
    recipientAddressType ??= _firstOrNull(loadedCatalogs.addressTypes);
    recipientPropertyType ??= _firstOrNull(loadedCatalogs.propertyTypes);
    selectedPackage ??= _firstOrNull(loadedCatalogs.packages);
  }

  void _advanceTo(int step) {
    currentStep = step;
    highestStep = math.max(highestStep, step);
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() action) async {
    errorMessage = null;
    try {
      await action();
    } on Object catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _remoteGuard(Future<void> Function() action) async {
    busyRemote = true;
    notifyListeners();
    try {
      await _guard(action);
    } finally {
      busyRemote = false;
      notifyListeners();
    }
  }

  void _validateInitial({bool requireShippingType = true}) {
    _require(destinationCity != null, 'Selecciona ciudad de destino.');
    _require(deliveryType != null, 'Selecciona tipo de entrega.');
    _require(paymentMethod != null, 'Selecciona forma de pago.');
    _require(finalWeight > 0, 'Ingresa peso de bascula o volumetrico.');
    _require(commercialValue > 0, 'Ingresa valor comercial.');
    if (requireShippingType && shippingTypes.isNotEmpty) {
      _require(shippingType != null, 'Selecciona tipo de envio.');
    }
  }

  void _requireSuppliesAvailable() {
    if (hasAvailableSupplies) return;
    throw const VenderLocalException(
      'No hay suministros disponibles. Recarga suministros antes de iniciar una venta.',
    );
  }

  void _validatePerson(VenderPersonKind kind) {
    _validatePersonIdentity(kind);
    _validateAddress(kind);
    _require(_name(kind).text.trim().isNotEmpty, 'Ingresa nombres.');
    _require(_firstLastName(kind).text.trim().isNotEmpty, 'Ingresa apellido.');
  }

  void _validatePersonIdentity(VenderPersonKind kind) {
    _require(_identificationType(kind) != null, 'Selecciona tipo documento.');
    _require(_document(kind).text.trim().isNotEmpty, 'Ingresa documento.');
    _require(_phone(kind).text.trim().isNotEmpty, 'Ingresa celular.');
  }

  void _validateAddress(VenderPersonKind kind) {
    _require(_addressType(kind) != null, 'Selecciona tipo direccion.');
    _require(_propertyType(kind) != null, 'Selecciona tipo inmueble.');
    _require(_street(kind).text.trim().isNotEmpty, 'Ingresa via/calle.');
    _require(_number(kind).text.trim().isNotEmpty, 'Ingresa numero.');
  }

  void _fillPerson(VenderPersonKind kind, VenderCustomer customer) {
    _document(kind).text = customer.document;
    _phone(kind).text = customer.phone;
    _name(kind).text = customer.names;
    _firstLastName(kind).text = customer.firstLastName;
    _secondLastName(kind).text = customer.secondLastName;
    _email(kind).text = customer.email;
    if (kind == VenderPersonKind.sender) {
      paymentAtHome = customer.paymentAtHome;
    }
    if (customer.addresses.isNotEmpty) {
      final address = customer.addresses.first;
      _address(kind).text = address.displayAddress;
      _neighborhood(kind).text = address.neighborhood;
      if (kind == VenderPersonKind.sender) {
        senderGeoAddress = address;
      } else {
        recipientGeoAddress = address;
      }
    }
  }

  TextEditingController _document(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderDocument : recipientDocument;
  TextEditingController _phone(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderPhone : recipientPhone;
  TextEditingController _name(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderName : recipientName;
  TextEditingController _firstLastName(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender
      ? senderFirstLastName
      : recipientFirstLastName;
  TextEditingController _secondLastName(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender
      ? senderSecondLastName
      : recipientSecondLastName;
  TextEditingController _street(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderStreet : recipientStreet;
  TextEditingController _number(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderNumber : recipientNumber;
  TextEditingController _complement(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderComplement : recipientComplement;
  TextEditingController _neighborhood(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender
      ? senderNeighborhood
      : recipientNeighborhood;
  TextEditingController _address(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderAddress : recipientAddress;
  TextEditingController _email(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderEmail : recipientEmail;

  CatalogOption? _identificationType(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender
      ? senderIdentificationType
      : recipientIdentificationType;
  CatalogOption? _addressType(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender
      ? senderAddressType
      : recipientAddressType;
  CatalogOption? _propertyType(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender
      ? senderPropertyType
      : recipientPropertyType;
  bool _south(VenderPersonKind kind) =>
      kind == VenderPersonKind.sender ? senderSouth : recipientSouth;

  T? _firstOrNull<T>(List<T> items) => items.isEmpty ? null : items.first;

  double _readDouble(String value) {
    final text = value.replaceAll(r'$', '').replaceAll(',', '.').trim();
    return double.tryParse(text) ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(0);

  void _require(bool condition, String message) {
    if (!condition) throw VenderLocalException(message);
  }

  @override
  void dispose() {
    for (final controller in [
      preGuide,
      pieces,
      weightScale,
      weightVolume,
      length,
      width,
      height,
      declaredValue,
      securityBag,
      content,
      observations,
      senderDocument,
      senderPhone,
      senderName,
      senderFirstLastName,
      senderSecondLastName,
      senderStreet,
      senderNumber,
      senderComplement,
      senderNeighborhood,
      senderAddress,
      senderEmail,
      recipientDocument,
      recipientPhone,
      recipientName,
      recipientFirstLastName,
      recipientSecondLastName,
      recipientStreet,
      recipientNumber,
      recipientComplement,
      recipientNeighborhood,
      recipientAddress,
      recipientEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
