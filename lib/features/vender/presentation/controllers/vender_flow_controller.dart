import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../../pagos/pagos.dart';
import '../../impresion/impresion.dart';
import '../../data/vender_local_repository.dart';
import '../../data/vender_remote_repository.dart';
import '../../data/vender_whatsapp_service.dart';
import '../../models/vender_models.dart';

enum VenderPersonKind { sender, recipient }

class VenderFlowController extends ChangeNotifier {
  VenderFlowController({
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
    VenderLocalRepository? localRepository,
    VenderRemoteRepository? remoteRepository,
    VenderPrintLocalRepository? printRepository,
    VenderWhatsappService? whatsappService,
    PagosRemoteRepository? paymentsRepository,
  }) : localRepository = localRepository ?? VenderLocalRepository(),
       remoteRepository = remoteRepository ?? VenderRemoteRepository(),
       printRepository = printRepository ?? VenderPrintLocalRepository(),
       whatsappService = whatsappService ?? const VenderWhatsappService(),
       paymentsRepository = paymentsRepository ?? PagosRemoteRepository();

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;
  final VenderLocalRepository localRepository;
  final VenderRemoteRepository remoteRepository;
  final VenderPrintLocalRepository printRepository;
  final VenderWhatsappService whatsappService;
  final PagosRemoteRepository paymentsRepository;

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
  List<VenderDifficultAccessCenter> difficultAccessCenters = const [];
  VenderDifficultAccessCenter? selectedDifficultAccessCenter;
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
  VenderAdmissionSuccessState? admissionSuccessState;
  VenderCollectionState? collectionState;
  bool difficultAccessRequired = false;
  String? _lastDifficultAccessValidationKey;
  VenderRestrictiveListResult? pendingRestrictiveListResult;
  String? _lastRestrictiveListValidationKey;
  bool _restrictiveListAccepted = false;
  final Map<VenderPersonKind, String> _lastCustomerKeyLookup = {};
  final Set<VenderPersonKind> _customerKeyLookupsInProgress = {};

  double get finalWeight {
    return math.max(
      _readDouble(weightScale.text),
      _readDouble(weightVolume.text),
    );
  }

  double get commercialValue => _readDouble(declaredValue.text);

  bool get hasCatalogs => catalogs?.hasAdmissionCatalogs ?? false;

  bool get hasAvailableSupplies => (catalogs?.availableSupplies ?? 0) > 0;

  bool get shouldShowDifficultAccessSelector {
    return difficultAccessRequired &&
        selectedDifficultAccessCenter == null &&
        difficultAccessCenters.isNotEmpty;
  }

  bool get shouldShowRestrictiveListDialog =>
      pendingRestrictiveListResult?.hasAnyRestriction == true;

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
    if (highestStep >= 5 && value < 5) return;
    currentStep = value;
    notifyListeners();
  }

  void previousStep() {
    if (currentStep <= 0) return;
    if (currentStep >= 5) return;
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
        await _remoteGuard(_prepareRecipientForSummary);
        if (shouldShowDifficultAccessSelector ||
            shouldShowRestrictiveListDialog) {
          return;
        }
        _advanceTo(4);
        return;
      case 4:
        await saveDraft(reserveSupply: true);
        return;
      case 5:
        goToBillingSummary();
        return;
      case 6:
        await invoiceAdmittedGuides();
        return;
      default:
        if (collectionState?.confirmed == true) {
          await resetForNewAdmission();
        } else {
          await confirmCollection();
        }
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
    await _guard(_quoteServicesFromCurrentData);
  }

  Future<VenderPersonRemoteData?> lookupPerson(VenderPersonKind kind) {
    _validatePersonIdentity(kind);
    return lookupPersonFromFocus(kind, force: true);
  }

  Future<VenderPersonRemoteData?> lookupPersonFromFocus(
    VenderPersonKind kind, {
    bool force = false,
  }) async {
    if (offline) return null;
    final document = _cleanIdentifier(_document(kind).text);
    final phone = _digits(_phone(kind).text);
    if (document.isEmpty || phone.isEmpty) return null;
    if (preenvioData != null || guideData != null) return null;
    if (_customerKeyLookupsInProgress.contains(kind)) return null;

    final type = _effectiveIdentificationType(kind);
    final localityId = kind == VenderPersonKind.sender
        ? appInformation.idCiudad
        : destinationCity?.id ?? '';
    if (localityId.trim().isEmpty) return null;

    final lookupKey = [
      kind.name,
      type.id,
      localityId,
      document,
      phone,
    ].join('|');
    if (!force && _lastCustomerKeyLookup[kind] == lookupKey) return null;

    _customerKeyLookupsInProgress.add(kind);
    busyRemote = true;
    notifyListeners();
    try {
      return await _guardValue(() async {
        final result = await remoteRepository.lookupCustomerKey(
          config: apiConfig,
          appInformation: appInformation,
          localityId: localityId,
          identificationType: type.id,
          document: document,
          phone: phone,
        );
        _lastCustomerKeyLookup[kind] = lookupKey;
        if (result.principal.hasIdentity && !result.requiresConfirmation) {
          _fillPerson(kind, result.principal);
        }
        statusMessage = result.message.trim().isNotEmpty
            ? result.message
            : result.requiresConfirmation
            ? 'El numero ingresado requiere confirmacion.'
            : 'Cliente consultado en Torre Direcciones.';
        return result;
      });
    } finally {
      _customerKeyLookupsInProgress.remove(kind);
      busyRemote = false;
      notifyListeners();
    }
  }

  void acceptCustomerKey(VenderPersonKind kind, VenderPersonRemoteData result) {
    if (result.principal.hasIdentity) {
      _fillPerson(kind, result.principal);
      statusMessage = 'Datos del cliente aplicados a la admision.';
      notifyListeners();
    }
  }

  void cancelCustomerKey(VenderPersonKind kind) {
    _lastCustomerKeyLookup.remove(kind);
    statusMessage = 'Verifica cedula y telefono antes de continuar.';
    notifyListeners();
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
        _resetDifficultAccessState();
      }
      statusMessage = 'Direccion georreferenciada correctamente.';
    });
  }

  Future<void> confirmDifficultAccessCenter(
    VenderDifficultAccessCenter center,
  ) async {
    await _guard(() async {
      selectedDifficultAccessCenter = center;
      difficultAccessRequired = true;
      recipientAddress.text = center.displayName;
      _selectDeliveryTypeById('2');
      await _quoteServicesFromCurrentData(
        successMessage:
            'Zona de dificil acceso seleccionada. Liquidacion recalculada para reclamar en oficina.',
      );
    });
  }

  Future<void> _prepareRecipientForSummary() async {
    _validatePerson(VenderPersonKind.recipient);
    if (offline) return;
    await _validateRecipientDifficultAccess();
    if (shouldShowDifficultAccessSelector) return;
    await _validateRestrictiveListBeforeSummary();
  }

  Future<void> _validateRestrictiveListBeforeSummary() async {
    pendingRestrictiveListResult = null;
    if (!_isRestrictiveListEnabled()) return;
    if (!_isCollectPaymentSelected()) return;

    final senderType = _effectiveIdentificationType(VenderPersonKind.sender);
    final recipientType = _effectiveIdentificationType(
      VenderPersonKind.recipient,
    );
    final key = [
      senderType.id,
      _cleanIdentifier(senderDocument.text),
      _digits(senderPhone.text),
      recipientType.id,
      _cleanIdentifier(recipientDocument.text),
      _digits(recipientPhone.text),
      paymentMethod?.id ?? '',
    ].join('|');
    if (_restrictiveListAccepted && _lastRestrictiveListValidationKey == key) {
      return;
    }

    var recipientFilter =
        catalogs?.parameters['RangosDestinatarioLR']?.trim() ?? '';
    if (recipientFilter.isEmpty) {
      recipientFilter = await remoteRepository
          .fetchRestrictiveListRecipientFilter(config: apiConfig);
    }
    if (recipientFilter.trim().isEmpty) recipientFilter = '90,2,3';

    final result = await remoteRepository.validateRestrictiveList(
      config: apiConfig,
      recipientFilter: recipientFilter,
      senderIdentificationType: senderType.id,
      senderDocument: _cleanIdentifier(senderDocument.text),
      senderPhone: _digits(senderPhone.text),
      recipientIdentificationType: recipientType.id,
      recipientDocument: _cleanIdentifier(recipientDocument.text),
      recipientPhone: _digits(recipientPhone.text),
    );
    _lastRestrictiveListValidationKey = key;
    _restrictiveListAccepted = false;
    if (result.hasAnyRestriction) {
      pendingRestrictiveListResult = result;
      statusMessage = 'Cliente encontrado en lista restrictiva.';
      return;
    }
    statusMessage = 'Cliente validado sin novedad en lista restrictiva.';
  }

  Future<void> resolveRestrictiveList(
    VenderRestrictiveListAction action,
  ) async {
    final result = pendingRestrictiveListResult;
    if (result == null) return;
    switch (action) {
      case VenderRestrictiveListAction.continueCollect:
        _restrictiveListAccepted = true;
        pendingRestrictiveListResult = null;
        statusMessage = 'Continua admision al cobro.';
        notifyListeners();
        return;
      case VenderRestrictiveListAction.continueCash:
        _selectPaymentMethodAsCash();
        await _quoteServicesFromCurrentData(
          successMessage: 'Forma de pago actualizada a contado.',
        );
        _restrictiveListAccepted = true;
        pendingRestrictiveListResult = null;
        notifyListeners();
        return;
      case VenderRestrictiveListAction.cancelSale:
        _clearRecipientData();
        pendingRestrictiveListResult = null;
        _restrictiveListAccepted = false;
        currentStep = 3;
        highestStep = math.max(highestStep, 3);
        statusMessage = 'Venta cancelada para este destinatario.';
        notifyListeners();
        return;
    }
  }

  Future<void> _validateRecipientDifficultAccess() async {
    if (selectedDifficultAccessCenter != null && difficultAccessRequired) {
      return;
    }

    final localityId = destinationCity?.id.trim() ?? '';
    if (localityId.isEmpty) return;

    var geo = recipientGeoAddress;
    if (geo == null || _difficultAccessZoneDescription(geo).isEmpty) {
      geo = await _geocodeRecipientForDifficultAccess(localityId);
    }

    final zoneDescription = _difficultAccessZoneDescription(geo);
    if (zoneDescription.isEmpty) {
      _resetDifficultAccessState();
      return;
    }

    final validationKey = [
      localityId,
      zoneDescription,
      recipientStreet.text.trim(),
      recipientNumber.text.trim(),
      recipientAddress.text.trim(),
    ].join('|');
    if (_lastDifficultAccessValidationKey == validationKey &&
        difficultAccessRequired &&
        difficultAccessCenters.isNotEmpty) {
      return;
    }
    if (_lastDifficultAccessValidationKey == validationKey &&
        !difficultAccessRequired) {
      return;
    }

    final requiresDifficultAccess = await remoteRepository
        .isDifficultAccessZone(
          config: apiConfig,
          appInformation: appInformation,
          localityId: localityId,
          zoneDescription: zoneDescription,
        );
    _lastDifficultAccessValidationKey = validationKey;

    if (!requiresDifficultAccess) {
      difficultAccessRequired = false;
      difficultAccessCenters = const [];
      selectedDifficultAccessCenter = null;
      statusMessage = 'Direccion destino validada sin novedad de acceso.';
      return;
    }

    final centers = await remoteRepository.fetchDifficultAccessCenters(
      config: apiConfig,
      appInformation: appInformation,
      localityId: localityId,
      address: recipientAddress.text.trim(),
    );
    if (centers.isEmpty) {
      throw const VenderRemoteException(
        'La direccion es zona de dificil acceso, pero no se encontraron puntos cercanos.',
      );
    }

    difficultAccessRequired = true;
    difficultAccessCenters = centers;
    selectedDifficultAccessCenter = null;
    statusMessage =
        'Zona de dificil acceso detectada. Selecciona una oficina destino.';
  }

  Future<VenderGeoAddress> _geocodeRecipientForDifficultAccess(
    String cityId,
  ) async {
    final cityHasGeo = await localRepository.cityHasGeoReference(cityId);
    final specialCity = await localRepository.isSpecialCity(cityId);
    final cardinality = await localRepository.cityHasCardinality(cityId);
    final address = await remoteRepository.geocodeAddress(
      config: apiConfig,
      appInformation: appInformation,
      cityId: cityId,
      addressType: recipientAddressType!,
      propertyType: recipientPropertyType!,
      number: recipientNumber.text.trim(),
      street: recipientStreet.text.trim(),
      neighborhood: recipientNeighborhood.text.trim(),
      south: cardinality && recipientSouth,
      cityHasGeoReference: cityHasGeo,
      specialCity: specialCity,
    );
    recipientGeoAddress = address;
    recipientAddress.text = address.displayAddress;
    if (address.neighborhood.trim().isNotEmpty) {
      recipientNeighborhood.text = address.neighborhood;
    }
    return address;
  }

  String _difficultAccessZoneDescription(VenderGeoAddress geo) {
    final raw = geo.raw['data'] is Map
        ? Map<String, Object?>.from(geo.raw['data'] as Map)
        : geo.raw['Data'] is Map
        ? Map<String, Object?>.from(geo.raw['Data'] as Map)
        : geo.raw;
    final lowerIndex = {
      for (final entry in raw.entries) entry.key.toLowerCase(): entry.value,
    };
    final value =
        raw['zona2'] ??
        raw['Zona2'] ??
        raw['microZona'] ??
        raw['MicroZona'] ??
        lowerIndex['zona2'] ??
        lowerIndex['microzona'] ??
        geo.microZone;
    return value.toString().trim();
  }

  Future<void> _quoteServicesFromCurrentData({String? successMessage}) async {
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
    statusMessage =
        successMessage ??
        (quotes.isEmpty
            ? 'No hay servicios habilitados para los datos ingresados.'
            : 'Liquidacion calculada con tarifas locales.');
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
      final collectionGuides = <VenderCollectionGuide>[];
      for (final admission in admissions) {
        try {
          final syncResult = await remoteRepository.synchronizeOfflineAdmission(
            config: apiConfig,
            appInformation: appInformation,
            admission: admission,
          );
          collectionGuides.add(
            VenderCollectionGuide.fromOfflineAdmission(
              admission: admission,
              syncResult: syncResult,
            ),
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
      _openBillingSummary(
        collectionGuides,
        message:
            'Sincronizacion exitosa de $synchronized admisiones. Verifica el resumen para facturar.',
      );
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
        VenderAdmissionSuccessState? successState;
        if (reserveSupply && !offline) {
          successState = await _synchronizeSavedAdmission(result.guideNumber);
          finalMessage = successState.message.trim().isNotEmpty
              ? successState.message
              : 'Admision registrada y sincronizada con guia ${result.guideNumber}.';
        }
        catalogs = await localRepository.loadCatalogs(appInformation);
        if (successState != null) {
          _openAdmissionSuccess(
            successState,
            message: '$finalMessage Envio admitido con exito.',
          );
        } else {
          statusMessage = finalMessage;
        }
      });
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<VenderAdmissionSuccessState> _synchronizeSavedAdmission(
    String guideNumber,
  ) async {
    final admission = await localRepository.pendingOfflineAdmissionByGuide(
      guideNumber,
    );
    if (admission == null) {
      throw VenderLocalException(
        'No se encontro la admision local para la guia $guideNumber.',
      );
    }
    final syncResult = await remoteRepository.synchronizeOfflineAdmission(
      config: apiConfig,
      appInformation: appInformation,
      admission: admission,
    );
    await localRepository.markOfflineAdmissionSynchronized(admission);
    final collectionGuide = VenderCollectionGuide.fromOfflineAdmission(
      admission: admission,
      syncResult: syncResult,
    );
    await printRepository.saveLatestPrintPayload(
      guideNumber: collectionGuide.guideNumber,
      payloadJson: admission.printJson,
    );
    return VenderAdmissionSuccessState(
      guide: collectionGuide,
      supplyNumber: admission.guideNumber,
      message: syncResult.message,
    );
  }

  void selectCollectionPaymentMethod(int value) {
    final collection = collectionState;
    if (collection == null) return;
    collectionState = collection.copyWith(
      selectedPaymentMethodId: value,
      confirmed: false,
      clearPaymentTracking: true,
    );
    notifyListeners();
  }

  Future<void> confirmCollection() async {
    await _remoteGuard(() async {
      await _confirmCollectionPayment();
    });
  }

  Future<void> _confirmCollectionPayment() async {
    final collection = collectionState;
    if (collection == null) {
      throw const VenderLocalException('No hay cobro pendiente.');
    }
    final methodName = collection.selectedPaymentMethodName;
    final amount = _money(collection.totalToCharge);
    if (collection.totalToCharge <= 0 ||
        collection.selectedPaymentMethodId == VenderPaymentMethods.cash) {
      collectionState = collection.copyWith(
        confirmed: true,
        paymentStatus: 'Aprobado',
        paymentMessage: collection.totalToCharge <= 0
            ? 'Admision sincronizada sin valor contado por cobrar.'
            : 'Cobro en efectivo confirmado por $amount.',
      );
      statusMessage = collectionState!.paymentMessage;
      return;
    }
    if (collection.selectedPaymentMethodId == VenderPaymentMethods.interPay) {
      throw const VenderRemoteException(
        'Inter Pay requiere validacion de codigo prepago. Ese flujo aun no esta disponible en Flutter.',
      );
    }
    if (!collection.requiresRemotePayment) {
      throw VenderRemoteException(
        'El medio de pago $methodName no tiene flujo remoto disponible.',
      );
    }
    final result = await paymentsRepository.sendOrSynchronize(
      config: apiConfig,
      request: _paymentRequestFor(collection),
      existingTransactionId: collection.paymentTransactionId,
    );
    final message = _paymentMessage(
      methodName: methodName,
      amount: amount,
      result: result,
    );
    collectionState = collection.copyWith(
      confirmed: result.isApproved,
      paymentTransactionId: result.transactionId,
      paymentStatus: result.displayStatus,
      paymentMessage: message,
    );
    statusMessage = message;
    if (!result.isApproved) {
      throw VenderRemoteException(message);
    }
  }

  void goToBillingSummary() {
    final collection = collectionState;
    if (collection == null || collection.guides.isEmpty) {
      throw const VenderLocalException('No hay guias admitidas para facturar.');
    }
    statusMessage = 'Resumen de guias admitidas listo para facturar.';
    _advanceTo(6);
  }

  void backToAdmissionSuccess() {
    final collection = collectionState;
    if (collection == null || collection.guides.isEmpty) return;
    currentStep = 5;
    notifyListeners();
  }

  Future<void> invoiceAdmittedGuides() async {
    await _remoteGuard(() async {
      var collection = collectionState;
      if (collection == null || collection.guides.isEmpty) {
        throw const VenderLocalException(
          'No hay guias admitidas para facturar.',
        );
      }
      if (!collection.confirmed) {
        await _confirmCollectionPayment();
        collection = collectionState;
      }
      if (collection == null || !collection.confirmed) {
        throw const VenderRemoteException(
          'Confirma el pago antes de cerrar la recogida.',
        );
      }
      final result = await remoteRepository.executePickup(
        config: apiConfig,
        appInformation: appInformation,
        collection: collection,
      );
      collectionState = collection.copyWith(
        confirmed: true,
        pickupExecuted: true,
        pickupMessage: result.message,
        invoiceNumber: result.invoiceNumber,
      );
      statusMessage = result.message;
      _advanceTo(7);
    });
  }

  PagoNotificationRequest _paymentRequestFor(VenderCollectionState collection) {
    final chargedGuides = collection.guides
        .where((guide) => guide.shouldChargeNow)
        .toList();
    final effectiveGuides = chargedGuides.isEmpty
        ? collection.guides
        : chargedGuides;
    final firstGuide = effectiveGuides.first;
    return PagoNotificationRequest(
      flow: PagoFlowType.admision,
      methodId: collection.selectedPaymentMethodId,
      amount: collection.totalToCharge.round(),
      phone: firstGuide.senderPhone,
      email: firstGuide.senderEmail,
      guides: effectiveGuides.map((guide) => guide.guideNumber).toList(),
      preInvoiceId: collection.idPreInvoice.toString(),
      serviceCenterId: appInformation.idCentroServicio,
      userId: appInformation.idUsuario,
      identifier: appInformation.idDispositivo.trim().isNotEmpty
          ? appInformation.idDispositivo.trim()
          : appInformation.idMensajero,
    );
  }

  String _paymentMessage({
    required String methodName,
    required String amount,
    required PagoOperationResult result,
  }) {
    final transaction = result.transactionId > 0
        ? ' Solicitud ${result.transactionId}.'
        : '';
    if (result.isApproved) {
      return 'Pago $methodName aprobado por $amount.$transaction';
    }
    final remoteMessage = result.message.trim().isNotEmpty
        ? ' ${result.message.trim()}'
        : '';
    return 'Pago $methodName pendiente por $amount.$transaction Estado: ${result.displayStatus}.$remoteMessage';
  }

  Future<void> shareInvoiceByWhatsapp(String phone) async {
    await _remoteGuard(() async {
      final collection = collectionState;
      if (collection == null || !collection.pickupExecuted) {
        throw const VenderLocalException(
          'Cierra la recogida antes de compartir.',
        );
      }
      final normalizedPhone = _normalizedWhatsappPhone(phone);
      final invoiceNumber = collection.invoiceNumber.trim();
      if (invoiceNumber.isEmpty) {
        throw const VenderLocalException(
          'No se encontro el numero de comprobante para compartir.',
        );
      }
      final shortener = await _invoiceShortenerUrl();
      if (shortener.isEmpty) {
        throw const VenderRemoteException(
          'No fue posible consultar el link del comprobante.',
        );
      }
      final message = _invoiceWhatsappMessage(
        collection: collection,
        invoiceShortenerUrl: shortener,
      );
      final opened = await whatsappService.shareInvoice(
        nationalPhone: '57$normalizedPhone',
        message: message,
      );
      if (!opened) {
        throw const VenderLocalException(
          'Para enviar el comprobante, necesitas tener WhatsApp instalado y en su ultima version.',
        );
      }
      statusMessage = 'Comprobante listo para compartir por WhatsApp.';
    });
  }

  Future<void> resetForNewAdmission() async {
    _clearForm();
    await initialize();
  }

  Future<void> resetForAdditionalAdmission() async {
    final currentCollection = collectionState;
    _clearForm();
    collectionState = currentCollection;
    await initialize();
    statusMessage = 'Agrega otro envio a la misma recogida.';
    notifyListeners();
  }

  String _normalizedWhatsappPhone(String value) {
    final phone = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 10) {
      throw const VenderLocalException(
        'El numero celular debe ser de 10 digitos.',
      );
    }
    final normalized = phone.length > 10
        ? phone.substring(phone.length - 10)
        : phone;
    if (normalized.startsWith('0')) {
      throw const VenderLocalException(
        'El numero celular no debe iniciar con 0.',
      );
    }
    return normalized;
  }

  Future<String> _invoiceShortenerUrl() async {
    final parameterCode = 'ShortenerUrlFactura${apiConfig.label}';
    final localValue = catalogs?.parameters[parameterCode]?.trim() ?? '';
    if (localValue.isNotEmpty) return localValue.replaceAll('"', '').trim();
    return remoteRepository.fetchFrameworkParameter(
      config: apiConfig,
      appInformation: appInformation,
      code: parameterCode,
    );
  }

  String _invoiceWhatsappMessage({
    required VenderCollectionState collection,
    required String invoiceShortenerUrl,
  }) {
    final senderName = collection.guides.first.senderName.trim().isEmpty
        ? 'Cliente'
        : collection.guides.first.senderName.trim();
    final encodedInvoice = base64Encode(
      utf8.encode(collection.invoiceNumber.trim()),
    );
    final admissions = collection.guides
        .map((guide) {
          final city = guide.destinationCity.split('\\').first.trim();
          final destination = city.isEmpty ? 'Destino' : city;
          final payment = guide.paymentMethodLabel.trim().isEmpty
              ? 'Forma de pago'
              : guide.paymentMethodLabel.trim();
          return '${guide.guideNumber} - $payment - $destination';
        })
        .join('\n');
    return '¡Hola $senderName! 👋Estamos generando el comprobante de venta '
        'por medio del siguiente link podrás descargarlo, recuerda que la '
        'factura electrónica se te enviara al correo electrónico registrado\n\n'
        '$invoiceShortenerUrl$encodedInvoice\n'
        'Estas son tus guías admitidas:\n$admissions\n';
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
    _resetDifficultAccessState();
    notifyListeners();
  }

  void selectDeliveryType(CatalogOption? value) {
    deliveryType = value;
    selectedQuote = null;
    serviceQuotes = const [];
    _resetDifficultAccessState();
    notifyListeners();
  }

  void selectPaymentMethod(CatalogOption? value) {
    paymentMethod = value;
    pendingRestrictiveListResult = null;
    _restrictiveListAccepted = false;
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
      _resetDifficultAccessState();
    }
    notifyListeners();
  }

  void setPropertyType(VenderPersonKind kind, CatalogOption? value) {
    if (kind == VenderPersonKind.sender) {
      senderPropertyType = value;
    } else {
      recipientPropertyType = value;
      _resetDifficultAccessState();
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
      _resetDifficultAccessState();
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
    _resetDifficultAccessState();
    notifyListeners();
  }

  bool _isRestrictiveListEnabled() {
    final raw = (catalogs?.parameters['ListRestCons'] ?? '').trim();
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  bool _isCollectPaymentSelected() {
    final method = paymentMethod;
    if (method == null) return false;
    final label = method.label.toLowerCase();
    return method.id.trim() == VenderPaymentMethods.collect.toString() ||
        label.contains('cobro');
  }

  void _selectPaymentMethodAsCash() {
    final options = catalogs?.paymentMethods ?? const <CatalogOption>[];
    CatalogOption? match;
    for (final option in options) {
      final label = option.label.toLowerCase();
      if (option.id.trim() == VenderPaymentMethods.cash.toString() ||
          label.contains('contado') ||
          label.contains('efectivo')) {
        match = option;
        break;
      }
    }
    paymentMethod = match ?? const CatalogOption(id: '1', label: 'Contado');
    selectedQuote = null;
    serviceQuotes = const [];
  }

  void _clearRecipientData() {
    for (final controller in [
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
      controller.clear();
    }
    recipientGeoAddress = null;
    recipientSouth = false;
    recipientNotification = true;
    _lastCustomerKeyLookup.remove(VenderPersonKind.recipient);
    _resetDifficultAccessState();
  }

  void _selectDeliveryTypeById(String id) {
    final normalized = id.trim();
    CatalogOption? match;
    for (final option in [...deliveryTypes, ...?catalogs?.deliveryTypes]) {
      if (option.id.trim() == normalized) {
        match = option;
        break;
      }
    }
    deliveryType =
        match ?? CatalogOption(id: normalized, label: 'RECLAME EN OFICINA');
    selectedQuote = null;
    serviceQuotes = const [];
  }

  void _resetDifficultAccessState() {
    difficultAccessRequired = false;
    difficultAccessCenters = const [];
    selectedDifficultAccessCenter = null;
    _lastDifficultAccessValidationKey = null;
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
    final identificationType = _effectiveIdentificationType(kind);
    return {
      'identificationTypeId': identificationType.id,
      'identificationTypeLabel': identificationType.label,
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
      if (kind == VenderPersonKind.recipient)
        'difficultAccess': {
          'required': difficultAccessRequired,
          'selectedCenter': selectedDifficultAccessCenter?.raw,
        },
    };
  }

  void _applyDefaults(VenderCatalogs loadedCatalogs) {
    final identificationType = _defaultIdentificationType(loadedCatalogs);
    destinationCity ??= _firstOrNull(loadedCatalogs.destinationCities);
    deliveryType ??= _firstOrNull(deliveryTypes);
    paymentMethod ??= _firstOrNull(loadedCatalogs.paymentMethods);
    shippingType ??= _firstOrNull(shippingTypes);
    senderIdentificationType ??= identificationType;
    senderAddressType ??= _firstOrNull(loadedCatalogs.addressTypes);
    senderPropertyType ??= _firstOrNull(loadedCatalogs.propertyTypes);
    recipientIdentificationType ??= identificationType;
    recipientAddressType ??= _firstOrNull(loadedCatalogs.addressTypes);
    recipientPropertyType ??= _firstOrNull(loadedCatalogs.propertyTypes);
    selectedPackage ??= _firstOrNull(loadedCatalogs.packages);
  }

  void _advanceTo(int step) {
    currentStep = step;
    highestStep = math.max(highestStep, step);
    notifyListeners();
  }

  void _openAdmissionSuccess(
    VenderAdmissionSuccessState state, {
    required String message,
  }) {
    admissionSuccessState = VenderAdmissionSuccessState(
      guide: state.guide,
      supplyNumber: state.supplyNumber,
      message: message,
    );
    _openCollectionState([state.guide]);
    statusMessage = message;
    _advanceTo(5);
  }

  void _openBillingSummary(
    List<VenderCollectionGuide> guides, {
    required String message,
  }) {
    if (guides.isEmpty) {
      statusMessage = message;
      return;
    }
    admissionSuccessState = null;
    _openCollectionState(guides);
    statusMessage = message;
    _advanceTo(6);
  }

  void _openCollectionState(List<VenderCollectionGuide> guides) {
    final previous = collectionState?.guides ?? const <VenderCollectionGuide>[];
    final merged = <VenderCollectionGuide>[
      ...previous.where(
        (guide) => !guides.any((item) => item.guideNumber == guide.guideNumber),
      ),
      ...guides,
    ];
    collectionState = VenderCollectionState(
      guides: merged,
      selectedPaymentMethodId: VenderPaymentMethods.cash,
    );
  }

  void _clearForm() {
    for (final controller in [
      preGuide,
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
      controller.clear();
    }
    pieces.text = '1';
    deliveryTypes = const [];
    shippingTypes = const [];
    serviceQuotes = const [];
    valueRange = const VenderValueRange(minimum: 0, maximum: 0);
    destinationCity = null;
    deliveryType = null;
    paymentMethod = null;
    shippingType = null;
    selectedQuote = null;
    senderIdentificationType = null;
    senderAddressType = null;
    senderPropertyType = null;
    recipientIdentificationType = null;
    recipientAddressType = null;
    recipientPropertyType = null;
    selectedPackage = null;
    senderGeoAddress = null;
    recipientGeoAddress = null;
    preenvioData = null;
    guideData = null;
    currentStep = 0;
    highestStep = 0;
    paymentAtHome = false;
    contentChecked = false;
    senderSouth = false;
    recipientSouth = false;
    senderNotification = true;
    recipientNotification = true;
    admissionSuccessState = null;
    collectionState = null;
    pendingRestrictiveListResult = null;
    _lastRestrictiveListValidationKey = null;
    _restrictiveListAccepted = false;
    _lastCustomerKeyLookup.clear();
    _customerKeyLookupsInProgress.clear();
    _resetDifficultAccessState();
    errorMessage = null;
    statusMessage = null;
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

  Future<T> _guardValue<T>(Future<T> Function() action) async {
    errorMessage = null;
    try {
      return await action();
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
        _resetDifficultAccessState();
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
  CatalogOption _effectiveIdentificationType(VenderPersonKind kind) {
    return _identificationType(kind) ??
        _defaultIdentificationType(catalogs) ??
        const CatalogOption(id: 'CC', label: 'CC');
  }

  CatalogOption? _defaultIdentificationType(VenderCatalogs? source) {
    final options = source?.identificationTypes ?? const <CatalogOption>[];
    for (final option in options) {
      final id = option.id.trim().toUpperCase();
      final label = option.label.trim().toUpperCase();
      if (id == 'CC' ||
          label == 'CC' ||
          label.contains('CEDULA') ||
          label.contains('CÉDULA')) {
        return option;
      }
    }
    return _firstOrNull(options) ?? const CatalogOption(id: 'CC', label: 'CC');
  }

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

  String _cleanIdentifier(String value) {
    return value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').trim();
  }

  String _digits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

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
