import 'dart:convert';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../login/login.dart';
import '../models/vender_models.dart';

class VenderLocalRepository {
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<VenderCatalogs> loadCatalogs(AppInformation appInformation) async {
    final db = await _openDatabase();
    await _ensureDraftTable(db);
    await _ensureAdmissionOfflineTables(db);

    final destinationCities = await _loadOptions(
      db,
      tableCandidates: const ['Localidad_PAR'],
      idColumns: const ['LOC_IdLocalidad', 'IdLocalidad'],
      labelColumns: const [
        'LOC_NombreCompleto',
        'LOC_Nombre',
        'NombreCompletoLocalidad',
        'NombreLocalidad',
      ],
      limit: 5000,
    );
    final deliveryTypes = await _loadOptions(
      db,
      tableCandidates: const ['TipoEntrega_MEN'],
      idColumns: const ['TIE_IdTipoEntrega'],
      labelColumns: const ['TIE_Descripcion'],
      limit: 500,
    );
    final paymentMethods = await _loadPaymentMethods(db);
    final shippingTypes = await _loadOptions(
      db,
      tableCandidates: const ['TipoEnvio_TAR'],
      idColumns: const ['TEN_IdTipoEnvio'],
      labelColumns: const ['TEN_Nombre', 'TEN_Descripcion'],
      limit: 500,
    );
    final services = await _loadOptions(
      db,
      tableCandidates: const [
        'Servicio_TAR',
        'HorarioServicio_MEN',
        'ServicioTipoServicio_TAR',
      ],
      idColumns: const ['SER_IdServicio', 'HSM_IdServicio', 'STS_IdServicio'],
      labelColumns: const [
        'SER_Nombre',
        'SER_NombreServicio',
        'HSM_NombreCorto',
        'HSM_Alias',
      ],
      limit: 1000,
    );
    final addressTypes = await _loadOptions(
      db,
      tableCandidates: const ['TipoDireccion'],
      idColumns: const ['TDI_IdTipoDireccion'],
      labelColumns: const ['TDI_Descripcion'],
      limit: 1000,
    );
    final propertyTypes = await _loadOptions(
      db,
      tableCandidates: const ['TipoViviendaEntrega_CLI'],
      idColumns: const ['TVE_IdVivienda', 'TVE_IdTipoVivienda'],
      labelColumns: const ['TVE_NombreVivienda', 'TVE_Descripcion'],
      limit: 1000,
    );
    final identificationTypes = await _loadOptions(
      db,
      tableCandidates: const ['TipoIdentificacion_PAR'],
      idColumns: const ['TID_IdTipoIdentificacion', 'TII_IdTipoIdentificacion'],
      labelColumns: const ['TID_Descripcion', 'TII_Descripcion'],
      limit: 500,
    );
    final packages = await _loadOptions(
      db,
      tableCandidates: const ['Producto_PRD', 'Empaque_MEN'],
      idColumns: const ['PRD_IdProducto', 'EMP_IdEmpaque'],
      labelColumns: const ['PRD_Nombre', 'PRD_Descripcion', 'EMP_Descripcion'],
      limit: 1000,
    );

    return VenderCatalogs(
      destinationCities: destinationCities,
      deliveryTypes: deliveryTypes,
      paymentMethods: paymentMethods,
      shippingTypes: shippingTypes,
      services: services,
      addressTypes: addressTypes,
      propertyTypes: propertyTypes,
      identificationTypes: identificationTypes,
      packages: packages,
      parameters: await _loadAdmissionParameters(db),
      availableSupplies: await _availableSuppliesCount(db),
      usedSupplies: await _usedSuppliesCount(db),
      pendingOfflineAdmissions:
          await _countRows(
            db,
            'AdmisionMensajeriaOffLine',
            where: 'EstaSincronizado = 0',
          ) +
          await _countRows(db, 'vender_drafts', where: "status <> 'synced'"),
    );
  }

  Future<int> currentPriceListId() async {
    final db = await _openDatabase();
    return _currentPriceListId(db);
  }

  Future<List<CatalogOption>> loadDeliveryTypesForPriceList(
    int priceListId,
  ) async {
    final db = await _openDatabase();
    if (priceListId <= 0 ||
        !await _tableExists(db, 'TipoEntrega_MEN') ||
        !await _tableExists(db, 'PrecioTipoEntrega_TAR') ||
        !await _tableExists(db, 'ListaPrecioServicio_TAR')) {
      return _loadOptions(
        db,
        tableCandidates: const ['TipoEntrega_MEN'],
        idColumns: const ['TIE_IdTipoEntrega'],
        labelColumns: const ['TIE_Descripcion'],
        limit: 20,
      );
    }

    final rows = await db.rawQuery(
      '''
SELECT TIE_IdTipoEntrega, TIE_Descripcion
FROM TipoEntrega_MEN
JOIN PrecioTipoEntrega_TAR ON PTE_IdTipoEntrega = TIE_IdTipoEntrega
JOIN ListaPrecioServicio_TAR ON LPS_IdListaPrecioServicio = PTE_IdListaPrecioServicio
WHERE LPS_IdListaPrecios = ?
UNION
SELECT TIE_IdTipoEntrega, TIE_Descripcion
FROM TipoEntrega_MEN
WHERE TRIM(TIE_IdTipoEntrega) IN ('1','2')
ORDER BY TIE_IdTipoEntrega ASC
''',
      [priceListId],
    );
    return rows
        .map(
          (row) => _optionFromRow(
            row,
            idColumns: const ['TIE_IdTipoEntrega'],
            labelColumns: const ['TIE_Descripcion'],
          ),
        )
        .where((item) => item.hasValue)
        .toList();
  }

  Future<List<CatalogOption>> loadShippingTypesForWeight(double weight) async {
    final db = await _openDatabase();
    if (!await _tableExists(db, 'TipoEnvio_TAR')) return const [];
    final rows = await db.rawQuery(
      '''
SELECT *
FROM TipoEnvio_TAR
WHERE TEN_PesoMaximo >= ? AND TEN_PesoMinimo <= ?
ORDER BY TEN_IdTipoEnvio ASC
''',
      [weight, weight],
    );
    return rows
        .map(
          (row) => _optionFromRow(
            row,
            idColumns: const ['TEN_IdTipoEnvio'],
            labelColumns: const ['TEN_Nombre', 'TEN_Descripcion'],
          ),
        )
        .where((item) => item.hasValue)
        .toList();
  }

  Future<VenderValueRange> declaredValueRange(double weight) async {
    final db = await _openDatabase();
    final priceListId = await _currentPriceListId(db);
    if (priceListId <= 0 || !await _tableExists(db, 'ValorPesoDeclarado_TAR')) {
      return const VenderValueRange(minimum: 0, maximum: 0);
    }
    final rows = await db.rawQuery(
      '''
SELECT VMD_ValorMinimoDeclarado, VMD_ValorMaximoDeclarado
FROM ValorPesoDeclarado_TAR
WHERE VMD_IdListaPrecios = ?
  AND VMD_PesoInicial <= ?
  AND VMD_PesoFinal >= ?
ORDER BY VMD_PesoInicial
LIMIT 1
''',
      [priceListId, weight, weight],
    );
    if (rows.isEmpty) return const VenderValueRange(minimum: 0, maximum: 0);
    final row = rows.first;
    return VenderValueRange(
      minimum: _doubleValue(row['VMD_ValorMinimoDeclarado']),
      maximum: _doubleValue(row['VMD_ValorMaximoDeclarado']),
    );
  }

  Future<List<VenderServiceQuote>> quoteServices({
    required AppInformation appInformation,
    required CatalogOption destinationCity,
    required CatalogOption deliveryType,
    required CatalogOption paymentMethod,
    required CatalogOption shippingType,
    required double weight,
    required double declaredValue,
  }) async {
    final db = await _openDatabase();
    final priceListId = await _currentPriceListId(db);
    if (priceListId <= 0) return const [];

    final serviceRows = await _enabledServiceRows(
      db,
      appInformation: appInformation,
      priceListId: priceListId,
      weight: weight,
    );
    final quotes = <VenderServiceQuote>[];
    final seenServices = <String>{};

    for (final row in serviceRows) {
      final serviceId = _firstColumnValue(row, const [
        'SER_IdServicio',
        'LPS_IdServicio',
        'SME_IdServicio',
      ]);
      if (serviceId.isEmpty || seenServices.contains(serviceId)) continue;
      seenServices.add(serviceId);
      final serviceName = _firstColumnValue(row, const [
        'SER_Nombre',
        'SER_NombreServicio',
        'Nombre',
      ]);
      if (_isPaymentCollect(paymentMethod) && serviceId == '15') continue;

      final price = await _serviceQuotePrice(
        db,
        serviceId: serviceId,
        priceListId: priceListId,
        originCityId: appInformation.idCiudad,
        destinationCityId: destinationCity.id,
        deliveryTypeId: deliveryType.id,
        weight: weight,
      );
      if (price == null) continue;
      final insurance = await _insuranceValue(
        db,
        serviceId: price.insuranceServiceId,
        priceListId: priceListId,
        declaredValue: declaredValue,
      );
      quotes.add(
        VenderServiceQuote(
          id: serviceId,
          name: serviceName.isEmpty ? 'Servicio $serviceId' : serviceName,
          baseValue: price.baseValue,
          insuranceValue: insurance,
          totalValue: price.baseValue + insurance,
          deliveryDays: price.deliveryDays,
          raw: row,
        ),
      );
    }

    quotes.sort((a, b) => a.totalValue.compareTo(b.totalValue));
    return quotes;
  }

  Future<void> insertSupplies(List<VenderSupply> supplies) async {
    if (supplies.isEmpty) return;
    final db = await _openDatabase();
    await _ensureAdmissionOfflineTables(db);
    final now = _sqliteDateTime(DateTime.now());
    await db.transaction((txn) async {
      for (final supply in supplies) {
        final guide = supply.guideNumber.trim();
        if (guide.isEmpty) continue;
        final expiration = _normalizeSupplyExpiration(supply.expirationDate);
        await txn.insert('SuministrosAdmision', {
          'numero': int.tryParse(guide) ?? guide,
          'fechaSincronizacion': now,
          'fechaVencimiento': expiration,
          'utilizado': 0,
          'fechaUtilizado': '',
          'estado': 'CREADO',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        final exists = await txn.rawQuery(
          'SELECT 1 FROM SuministrosMensajeriaOffLine WHERE NumeroGuia = ? LIMIT 1',
          [guide],
        );
        if (exists.isNotEmpty) continue;
        await txn.insert('SuministrosMensajeriaOffLine', {
          'NumeroGuia': guide,
          'FechaSincronizacion': now,
          'Utilizado': 0,
        });
      }
    });
  }

  Future<bool> cityHasGeoReference(String localityId) async {
    final db = await _openDatabase();
    if (!await _tableExists(db, 'Localidad_PAR')) return false;
    final rows = await db.rawQuery(
      'SELECT LOC_SeGeorreferencia FROM Localidad_PAR WHERE LOC_IdLocalidad = ? LIMIT 1',
      [localityId],
    );
    if (rows.isEmpty) return false;
    return _boolish(rows.first['LOC_SeGeorreferencia']);
  }

  Future<bool> cityHasCardinality(String localityId) async {
    final db = await _openDatabase();
    if (!await _tableExists(db, 'Ciudad_PAR')) return false;
    final rows = await db.rawQuery(
      'SELECT CIU_Activo FROM Ciudad_PAR WHERE CIU_IdLocalidad = ? LIMIT 1',
      [localityId],
    );
    if (rows.isEmpty) return false;
    return _boolish(rows.first['CIU_Activo']);
  }

  Future<bool> isSpecialCity(String localityId) async {
    final db = await _openDatabase();
    if (!await _tableExists(db, 'Ciudad_PAR')) return false;
    final rows = await db.rawQuery(
      'SELECT CIU_Especial FROM Ciudad_PAR WHERE CIU_IdLocalidad = ? LIMIT 1',
      [localityId],
    );
    if (rows.isEmpty) return false;
    return _boolish(rows.first['CIU_Especial']);
  }

  Future<VenderSaveResult> saveDraft({
    required VenderDraft draft,
    required bool reserveSupply,
  }) async {
    final db = await _openDatabase();
    await _ensureDraftTable(db);
    await _ensureAdmissionOfflineTables(db);

    return db.transaction((txn) async {
      final status = reserveSupply ? 'pending_offline' : 'draft';
      final guideNumber = reserveSupply
          ? await _reserveSupply(txn, preferredGuide: draft.guideNumber)
          : draft.guideNumber.trim();
      final payload = draft.copyWith(status: status, guideNumber: guideNumber);
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('vender_drafts', {
        'created_at': payload.createdAt.toIso8601String(),
        'updated_at': now,
        'status': payload.status,
        'payload_json': jsonEncode(payload.toJson()),
        'guide_number': payload.guideNumber,
        'destination_city': _stringValue(payload.destination['cityLabel']),
        'sender_document': _stringValue(payload.sender['document']),
        'recipient_document': _stringValue(payload.recipient['document']),
      });

      return VenderSaveResult(id: id, guideNumber: guideNumber, status: status);
    });
  }

  Future<void> _ensureDraftTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS vender_drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  guide_number TEXT,
  destination_city TEXT,
  sender_document TEXT,
  recipient_document TEXT
)
''');
  }

  Future<void> _ensureAdmissionOfflineTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS SuministrosAdmision (
  numero INTEGER PRIMARY KEY NOT NULL,
  fechaSincronizacion TEXT NOT NULL,
  fechaVencimiento TEXT NOT NULL,
  utilizado INTEGER NOT NULL,
  fechaUtilizado TEXT NOT NULL,
  estado TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS SuministrosMensajeriaOffLine (
  NumeroGuia INTEGER NOT NULL,
  FechaSincronizacion NUMERIC NOT NULL,
  Utilizado NUMERIC NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS AdmisionMensajeriaOffLine (
  IdAdmisionOffline INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  NumeroGuia TEXT NOT NULL,
  ObjetoMensajeriaRequest TEXT NOT NULL,
  ObjetoADGuiaImpresion TEXT NOT NULL,
  EstaSincronizado NUMERIC NOT NULL,
  FechaSincronizacion NUMERIC NULL
)
''');
  }

  Future<int> _currentPriceListId(Database db) async {
    if (!await _tableExists(db, 'ListaPrecios_TAR')) return 0;
    final now = DateTime.now().toIso8601String();
    final rows = await db.rawQuery(
      '''
SELECT LIP_IdListaPrecios
FROM ListaPrecios_TAR
WHERE DATE(?) >= DATE(LIP_Inicio)
  AND DATE(?) <= DATE(LIP_Fin)
  AND TRIM(LIP_Estado) = 'ACT'
  AND (LIP_EsTarifaPlena = 'True' OR LIP_EsTarifaPlena = '1')
LIMIT 1
''',
      [now, now],
    );
    if (rows.isEmpty) return 0;
    return _intValue(rows.first['LIP_IdListaPrecios']);
  }

  Future<List<Map<String, Object?>>> _enabledServiceRows(
    Database db, {
    required AppInformation appInformation,
    required int priceListId,
    required double weight,
  }) async {
    try {
      if (await _tableExists(db, 'CentroServicios_PUA') &&
          await _tableExists(db, 'CentroServicioServicio_PUA') &&
          await _tableExists(db, 'CentroServicioServicioDia_PUA') &&
          await _tableExists(db, 'Servicio_TAR') &&
          await _tableExists(db, 'ServicioMensajeria_TAR') &&
          await _tableExists(db, 'ListaPrecioServicio_TAR')) {
        final weekday = _weekdayForLocalDatabase(DateTime.now());
        final rows = await db.rawQuery(
          '''
SELECT DISTINCT Servicio_TAR.*, ServicioMensajeria_TAR.*, ListaPrecioServicio_TAR.*
FROM CentroServicios_PUA
JOIN CentroServicioServicio_PUA
  ON CentroServicios_PUA.CES_IdCentroServicios = CentroServicioServicio_PUA.CSS_IdCentroServicios
JOIN Servicio_TAR
  ON CentroServicioServicio_PUA.CSS_IdServicio = Servicio_TAR.SER_IdServicio
JOIN CentroServicioServicioDia_PUA
  ON CentroServicioServicio_PUA.CSS_IdCentroServicioServicio = CentroServicioServicioDia_PUA.CSD_IdCentroServicioServicio
LEFT OUTER JOIN ServicioMensajeria_TAR
  ON Servicio_TAR.SER_IdServicio = ServicioMensajeria_TAR.SME_IdServicio
JOIN ListaPrecioServicio_TAR
  ON ListaPrecioServicio_TAR.LPS_IdServicio = ServicioMensajeria_TAR.SME_IdServicio
WHERE TRIM(CentroServicioServicioDia_PUA.CSD_IdDia) = ?
  AND (TRIM(Servicio_TAR.SER_IdUnidadNegocio) = 'MEN' OR TRIM(Servicio_TAR.SER_IdUnidadNegocio) = 'CAR')
  AND TRIM(Servicio_TAR.SER_IdServicio) != '11'
  AND ListaPrecioServicio_TAR.LPS_IdListaPrecios = ?
  AND TRIM(ListaPrecioServicio_TAR.LPS_Estado) = 'ACT'
  AND TRIM(CentroServicios_PUA.CES_Estado) = 'ACT'
  AND TRIM(CentroServicioServicio_PUA.CSS_Estado) = 'ACT'
  AND DATE(CentroServicioServicio_PUA.CSS_FechaInicioVenta) <= DATE(?)
  AND CentroServicioServicio_PUA.CSS_IdCentroServicios = ?
  AND ? BETWEEN ServicioMensajeria_TAR.SME_PesoMinimo AND ServicioMensajeria_TAR.SME_PesoMaximo
''',
          [
            weekday,
            priceListId,
            DateTime.now().toIso8601String(),
            appInformation.idCentroServicio,
            weight,
          ],
        );
        return rows.where(_serviceWindowIsOpen).toList();
      }
    } on Object {
      // The offline schema varies by package; below we keep the same contract
      // with a lighter query over the synchronized tariff tables.
    }

    if (!await _tableExists(db, 'Servicio_TAR') ||
        !await _tableExists(db, 'ListaPrecioServicio_TAR')) {
      return const [];
    }
    return db.rawQuery(
      '''
SELECT DISTINCT Servicio_TAR.*, ListaPrecioServicio_TAR.*
FROM Servicio_TAR
JOIN ListaPrecioServicio_TAR
  ON ListaPrecioServicio_TAR.LPS_IdServicio = Servicio_TAR.SER_IdServicio
WHERE ListaPrecioServicio_TAR.LPS_IdListaPrecios = ?
  AND TRIM(ListaPrecioServicio_TAR.LPS_Estado) = 'ACT'
  AND TRIM(Servicio_TAR.SER_IdServicio) != '11'
ORDER BY Servicio_TAR.SER_Nombre COLLATE NOCASE
''',
      [priceListId],
    );
  }

  Future<_ServicePriceResult?> _serviceQuotePrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String originCityId,
    required String destinationCityId,
    required String deliveryTypeId,
    required double weight,
  }) async {
    final deliveryDays = await _deliveryDaysForService(
      db,
      serviceId: serviceId,
      originCityId: originCityId,
      destinationCityId: destinationCityId,
    );
    if (deliveryDays == null) {
      return null;
    }

    final serviceNumber = int.tryParse(serviceId.trim()) ?? 0;
    final delivery = deliveryTypeId.trim();
    final isKmOrRural = delivery == '3' || delivery == '4';

    if (isKmOrRural) {
      return _messagingPrice(
        db,
        serviceId: serviceId,
        priceListId: priceListId,
        originCityId: originCityId,
        destinationCityId: destinationCityId,
        deliveryTypeId: deliveryTypeId,
        weight: weight,
        deliveryDays: deliveryDays,
      );
    }

    if (serviceNumber == 5) {
      final promotional = await _promotionalRangePrice(
        db,
        serviceId: serviceId,
        priceListId: priceListId,
        weight: weight,
      );
      if (promotional == null) return null;
      return _ServicePriceResult(
        baseValue: promotional,
        insuranceServiceId: serviceId,
        deliveryDays: deliveryDays,
      );
    }

    if (serviceNumber == 6) {
      final cargo = await _cargoRouteRangePrice(
        db,
        serviceId: serviceId,
        priceListId: priceListId,
        originCityId: originCityId,
        destinationCityId: destinationCityId,
        deliveryTypeId: deliveryTypeId,
        weight: weight,
        deliveryDays: deliveryDays,
      );
      return cargo;
    }

    return _messagingPrice(
      db,
      serviceId: serviceId,
      priceListId: priceListId,
      originCityId: originCityId,
      destinationCityId: destinationCityId,
      deliveryTypeId: deliveryTypeId,
      weight: weight,
      deliveryDays: deliveryDays,
    );
  }

  Future<_ServicePriceResult?> _messagingPrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String originCityId,
    required String destinationCityId,
    required String deliveryTypeId,
    required double weight,
    required int deliveryDays,
  }) async {
    final effectiveServiceId =
        deliveryTypeId.trim() == '3' || deliveryTypeId.trim() == '4'
        ? '17'
        : serviceId;
    final byDeliveryType = await _deliveryTypeWeightPrice(
      db,
      serviceId: effectiveServiceId,
      priceListId: priceListId,
      deliveryTypeId: deliveryTypeId,
    );
    if (_hasInitialAndAdditionalPrice(byDeliveryType)) {
      return _ServicePriceResult(
        baseValue: _priceByWeight(byDeliveryType!, weight),
        insuranceServiceId: effectiveServiceId,
        deliveryDays: deliveryDays,
      );
    }

    final exception = await _exceptionServicePrice(
      db,
      serviceId: effectiveServiceId,
      priceListId: priceListId,
      originCityId: originCityId,
      destinationCityId: destinationCityId,
    );
    if (_hasInitialAndAdditionalPrice(exception)) {
      return _ServicePriceResult(
        baseValue: _priceByWeight(exception!, weight),
        insuranceServiceId: effectiveServiceId,
        deliveryDays: deliveryDays,
      );
    }

    final route = await _additionalRoutePrice(
      db,
      serviceId: effectiveServiceId,
      priceListId: priceListId,
      originCityId: originCityId,
      destinationCityId: destinationCityId,
    );
    if (_hasAnyWeightPrice(route)) {
      return _ServicePriceResult(
        baseValue: _priceByWeight(route!, weight),
        insuranceServiceId: effectiveServiceId,
        deliveryDays: deliveryDays,
      );
    }

    return null;
  }

  Future<Map<String, Object?>?> _deliveryTypeWeightPrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String deliveryTypeId,
  }) async {
    if (!await _tableExists(db, 'PrecioTipoEntrega_TAR') ||
        !await _tableExists(db, 'ListaPrecioServicio_TAR')) {
      return null;
    }
    final rows = await db.rawQuery(
      '''
SELECT PrecioTipoEntrega_TAR.PTE_ValorKiloInicial,
       PrecioTipoEntrega_TAR.PTE_ValorKiloAdicional
FROM ListaPrecioServicio_TAR
INNER JOIN PrecioTipoEntrega_TAR
  ON ListaPrecioServicio_TAR.LPS_IdListaPrecioServicio = PrecioTipoEntrega_TAR.PTE_IdListaPrecioServicio
WHERE TRIM(PrecioTipoEntrega_TAR.PTE_IdTipoEntrega) = ?
  AND TRIM(ListaPrecioServicio_TAR.LPS_IdListaPrecios) = ?
  AND TRIM(ListaPrecioServicio_TAR.LPS_IdServicio) = ?
LIMIT 1
''',
      [
        deliveryTypeId.trim().isEmpty ? '1' : deliveryTypeId.trim(),
        priceListId,
        serviceId,
      ],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> _exceptionServicePrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String originCityId,
    required String destinationCityId,
  }) async {
    if (!await _tableExists(db, 'PrecioServicioExcepcionTrayecto_TAR') ||
        !await _tableExists(db, 'ListaPrecioServicio_TAR')) {
      return null;
    }
    final rows = await db.rawQuery(
      '''
SELECT PrecioServicioExcepcionTrayecto_TAR.SET_ValorKiloInicial AS PTE_ValorKiloInicial,
       PrecioServicioExcepcionTrayecto_TAR.SET_ValorKiloAdicional AS PTE_ValorKiloAdicional
FROM ListaPrecioServicio_TAR
INNER JOIN PrecioServicioExcepcionTrayecto_TAR
  ON ListaPrecioServicio_TAR.LPS_IdListaPrecioServicio = PrecioServicioExcepcionTrayecto_TAR.SET_IdListaPrecioServicio
WHERE ListaPrecioServicio_TAR.LPS_IdServicio = ?
  AND ListaPrecioServicio_TAR.LPS_IdListaPrecios = ?
  AND PrecioServicioExcepcionTrayecto_TAR.SET_IdLocalidadOrigen = ?
  AND PrecioServicioExcepcionTrayecto_TAR.SET_IdLocalidadDestino = ?
UNION ALL
SELECT PrecioServicioExcepcionTrayecto_TAR.SET_ValorKiloInicial AS PTE_ValorKiloInicial,
       PrecioServicioExcepcionTrayecto_TAR.SET_ValorKiloAdicional AS PTE_ValorKiloAdicional
FROM ListaPrecioServicio_TAR
INNER JOIN PrecioServicioExcepcionTrayecto_TAR
  ON ListaPrecioServicio_TAR.LPS_IdListaPrecioServicio = PrecioServicioExcepcionTrayecto_TAR.SET_IdListaPrecioServicio
WHERE ListaPrecioServicio_TAR.LPS_IdServicio = ?
  AND ListaPrecioServicio_TAR.LPS_IdListaPrecios = ?
  AND PrecioServicioExcepcionTrayecto_TAR.SET_IdLocalidadOrigen = ?
  AND PrecioServicioExcepcionTrayecto_TAR.SET_IdLocalidadDestino = ?
  AND SET_EsDestinoTodoElPais = 1
UNION ALL
SELECT PrecioServicioExcepcionTrayecto_TAR.SET_ValorKiloInicial AS PTE_ValorKiloInicial,
       PrecioServicioExcepcionTrayecto_TAR.SET_ValorKiloAdicional AS PTE_ValorKiloAdicional
FROM ListaPrecioServicio_TAR
INNER JOIN PrecioServicioExcepcionTrayecto_TAR
  ON ListaPrecioServicio_TAR.LPS_IdListaPrecioServicio = PrecioServicioExcepcionTrayecto_TAR.SET_IdListaPrecioServicio
WHERE ListaPrecioServicio_TAR.LPS_IdServicio = ?
  AND ListaPrecioServicio_TAR.LPS_IdListaPrecios = ?
  AND PrecioServicioExcepcionTrayecto_TAR.SET_IdLocalidadOrigen = ?
  AND PrecioServicioExcepcionTrayecto_TAR.SET_IdLocalidadDestino = ?
  AND SET_EsOrigenTodoElPais = 1
''',
      [
        serviceId,
        priceListId,
        originCityId,
        destinationCityId,
        serviceId,
        priceListId,
        originCityId,
        destinationCityId,
        serviceId,
        priceListId,
        originCityId,
        destinationCityId,
      ],
    );
    if (rows.isEmpty) return null;
    return rows.last;
  }

  Future<Map<String, Object?>?> _additionalRoutePrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String originCityId,
    required String destinationCityId,
  }) async {
    if (!await _tableExists(db, 'Trayecto_TAR') ||
        !await _tableExists(db, 'TrayectoSubTrayecto_TAR') ||
        !await _tableExists(db, 'ServicioTrayecto_TAR') ||
        !await _tableExists(db, 'PrecioTrayecto_TAR') ||
        !await _tableExists(db, 'ListaPrecioServicio_TAR')) {
      return null;
    }
    final rows = await db.rawQuery(
      '''
SELECT TrayectoSubTrayecto_TAR.TRS_IdTipoSubTrayecto,
       PrecioTrayecto_TAR.PTR_ValorFijo
FROM Trayecto_TAR
JOIN TrayectoSubTrayecto_TAR
  ON Trayecto_TAR.TRA_IdTrayectoSubTrayecto = TrayectoSubTrayecto_TAR.TRS_IdTrayectoSubTrayecto
JOIN ServicioTrayecto_TAR
  ON Trayecto_TAR.TRA_IdTrayecto = ServicioTrayecto_TAR.STR_IdTrayecto
JOIN PrecioTrayecto_TAR
  ON TrayectoSubTrayecto_TAR.TRS_IdTrayectoSubTrayecto = PrecioTrayecto_TAR.PTR_IdTrayectoSubTrayecto
JOIN ListaPrecioServicio_TAR
  ON PrecioTrayecto_TAR.PTR_IdListaPrecioServicio = ListaPrecioServicio_TAR.LPS_IdListaPrecioServicio
WHERE ServicioTrayecto_TAR.STR_IdServicio = ?
  AND Trayecto_TAR.TRA_IdLocalidadOrigen = ?
  AND Trayecto_TAR.TRA_IdLocalidadDestino = ?
  AND ListaPrecioServicio_TAR.LPS_IdListaPrecios = ?
  AND ListaPrecioServicio_TAR.LPS_IdServicio = ?
''',
      [serviceId, originCityId, destinationCityId, priceListId, serviceId],
    );
    if (rows.isEmpty) return null;
    var initial = 0.0;
    var additional = 0.0;
    for (final row in rows) {
      final type = _stringValue(row['TRS_IdTipoSubTrayecto']).trim();
      final value = _doubleValue(row['PTR_ValorFijo']);
      if (type == 'SKI') {
        initial = value;
      } else {
        additional = value;
      }
    }
    return {
      'PTE_ValorKiloInicial': initial,
      'PTE_ValorKiloAdicional': additional,
    };
  }

  Future<double?> _promotionalRangePrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required double weight,
  }) async {
    if (!await _tableExists(db, 'PrecioRango_TAR')) return null;
    final priceListServiceId = await _priceListServiceId(
      db,
      serviceId: serviceId,
      priceListId: priceListId,
    );
    if (priceListServiceId <= 0) return null;
    final rows = await db.rawQuery(
      '''
SELECT PRA_Valor
FROM PrecioRango_TAR
WHERE PRA_IdListaPrecioServicio = ?
  AND PRA_Inicial <= ?
  AND PRA_Final >= ?
LIMIT 1
''',
      [priceListServiceId, weight, weight],
    );
    if (rows.isEmpty) return null;
    return _doubleValue(rows.first['PRA_Valor']);
  }

  Future<_ServicePriceResult?> _cargoRouteRangePrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String originCityId,
    required String destinationCityId,
    required String deliveryTypeId,
    required double weight,
    required int deliveryDays,
  }) async {
    if (!await _tableExists(db, 'Trayecto_TAR') ||
        !await _tableExists(db, 'TrayectoSubTrayecto_TAR') ||
        !await _tableExists(db, 'ServicioTrayecto_TAR') ||
        !await _tableExists(db, 'PrecioTrayecto_TAR') ||
        !await _tableExists(db, 'PrecioTrayectoRango_TAR')) {
      return null;
    }
    final priceListServiceId = await _priceListServiceId(
      db,
      serviceId: serviceId,
      priceListId: priceListId,
    );
    if (priceListServiceId <= 0) return null;
    final rows = await db.rawQuery(
      '''
SELECT TrayectoSubTrayecto_TAR.TRS_IdTipoSubTrayecto,
       PrecioTrayecto_TAR.PTR_ValorFijo,
       PrecioTrayectoRango_TAR.PPR_Inicial,
       PrecioTrayectoRango_TAR.PPR_Final,
       PrecioTrayectoRango_TAR.PPR_Valor
FROM Trayecto_TAR
JOIN TrayectoSubTrayecto_TAR
  ON Trayecto_TAR.TRA_IdTrayectoSubTrayecto = TrayectoSubTrayecto_TAR.TRS_IdTrayectoSubTrayecto
JOIN ServicioTrayecto_TAR
  ON Trayecto_TAR.TRA_IdTrayecto = ServicioTrayecto_TAR.STR_IdTrayecto
JOIN PrecioTrayecto_TAR
  ON TrayectoSubTrayecto_TAR.TRS_IdTrayectoSubTrayecto = PrecioTrayecto_TAR.PTR_IdTrayectoSubTrayecto
JOIN PrecioTrayectoRango_TAR
  ON PrecioTrayecto_TAR.PTR_IdPrecioTrayectoSubTrayect = PrecioTrayectoRango_TAR.PPR_IdPrecioTrayecto
WHERE ServicioTrayecto_TAR.STR_IdServicio = ?
  AND Trayecto_TAR.TRA_IdLocalidadOrigen = ?
  AND Trayecto_TAR.TRA_IdLocalidadDestino = ?
  AND PrecioTrayecto_TAR.PTR_IdListaPrecioServicio = ?
''',
      [serviceId, originCityId, destinationCityId, priceListServiceId],
    );
    for (final row in rows) {
      final initialRange = _doubleValue(row['PPR_Inicial']);
      final finalRange = _doubleValue(row['PPR_Final']);
      if (weight < initialRange || weight > finalRange) continue;
      final routeType = _stringValue(row['TRS_IdTipoSubTrayecto']).trim();
      if (routeType == 'ESPECIAL') {
        return _messagingPrice(
          db,
          serviceId: serviceId,
          priceListId: priceListId,
          originCityId: originCityId,
          destinationCityId: destinationCityId,
          deliveryTypeId: deliveryTypeId,
          weight: weight,
          deliveryDays: deliveryDays,
        );
      }
      final value = _doubleValue(row['PPR_Valor']) * finalRange;
      return _ServicePriceResult(
        baseValue: value,
        insuranceServiceId: serviceId,
        deliveryDays: deliveryDays,
      );
    }
    return null;
  }

  Future<int?> _deliveryDaysForService(
    Database db, {
    required String serviceId,
    required String originCityId,
    required String destinationCityId,
  }) async {
    if (!await _tableExists(db, 'Trayecto_TAR') ||
        !await _tableExists(db, 'ServicioTrayecto_TAR')) {
      return null;
    }
    final rows = await db.rawQuery(
      '''
SELECT ServicioTrayecto_TAR.STR_TiempoEntrega
FROM Trayecto_TAR
INNER JOIN ServicioTrayecto_TAR
  ON Trayecto_TAR.TRA_IdTrayecto = ServicioTrayecto_TAR.STR_IdTrayecto
WHERE Trayecto_TAR.TRA_IdLocalidadOrigen = ?
  AND Trayecto_TAR.TRA_IdLocalidadDestino = ?
  AND ServicioTrayecto_TAR.STR_IdServicio = ?
LIMIT 1
''',
      [originCityId, destinationCityId, serviceId],
    );
    if (rows.isEmpty) return null;
    return _intValue(rows.first['STR_TiempoEntrega']);
  }

  Future<int> _priceListServiceId(
    Database db, {
    required String serviceId,
    required int priceListId,
  }) async {
    if (!await _tableExists(db, 'ListaPrecioServicio_TAR')) return 0;
    final rows = await db.rawQuery(
      '''
SELECT LPS_IdListaPrecioServicio
FROM ListaPrecioServicio_TAR
WHERE LPS_IdServicio = ?
  AND LPS_IdListaPrecios = ?
LIMIT 1
''',
      [serviceId, priceListId],
    );
    if (rows.isEmpty) return 0;
    return _intValue(rows.first['LPS_IdListaPrecioServicio']);
  }

  bool _hasInitialAndAdditionalPrice(Map<String, Object?>? row) {
    if (row == null) return false;
    return _doubleValue(row['PTE_ValorKiloInicial']) != 0 &&
        _doubleValue(row['PTE_ValorKiloAdicional']) != 0;
  }

  bool _hasAnyWeightPrice(Map<String, Object?>? row) {
    if (row == null) return false;
    return _doubleValue(row['PTE_ValorKiloInicial']) != 0 ||
        _doubleValue(row['PTE_ValorKiloAdicional']) != 0;
  }

  double _priceByWeight(Map<String, Object?> row, double weight) {
    final initial = _doubleValue(row['PTE_ValorKiloInicial']);
    final additional = _doubleValue(row['PTE_ValorKiloAdicional']);
    return initial + (math.max(0, weight - 1) * additional);
  }

  Future<double> _insuranceValue(
    Database db, {
    required String serviceId,
    required int priceListId,
    required double declaredValue,
  }) async {
    if (!await _tableExists(db, 'ListaPrecioServicio_TAR')) return 0;
    final rows = await db.rawQuery(
      '''
SELECT LPS_PrimaSeguros
FROM ListaPrecioServicio_TAR
WHERE LPS_IdServicio = ?
  AND LPS_IdListaPrecios = ?
  AND TRIM(LPS_Estado) = 'ACT'
LIMIT 1
''',
      [serviceId, priceListId],
    );
    if (rows.isEmpty) return 0;
    final percentage = _doubleValue(rows.first['LPS_PrimaSeguros']);
    return (declaredValue * percentage) / 100;
  }

  Future<List<CatalogOption>> _loadPaymentMethods(Database db) async {
    if (!await _tableExists(db, 'FormasPago_TAR')) return const [];
    final columns = await _columnsFor(db, 'FormasPago_TAR');
    final filters = <String>[];
    if (columns.contains('FOP_AplicaFacturacion')) {
      filters.add(
        "(FOP_AplicaFacturacion = 'False' OR FOP_AplicaFacturacion = '0')",
      );
    }
    if (columns.contains('FOP_IdFormaPago')) {
      filters.add("TRIM(FOP_IdFormaPago) NOT IN ('2','4')");
    }
    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final rows = await db.rawQuery(
      'SELECT * FROM FormasPago_TAR $where ORDER BY FOP_Descripcion DESC',
    );
    return rows
        .map(
          (row) => _optionFromRow(
            row,
            idColumns: const ['FOP_IdFormaPago'],
            labelColumns: const ['FOP_Descripcion'],
          ),
        )
        .where((item) => item.hasValue)
        .toList();
  }

  Future<List<CatalogOption>> _loadOptions(
    Database db, {
    required List<String> tableCandidates,
    required List<String> idColumns,
    required List<String> labelColumns,
    required int limit,
  }) async {
    for (final table in tableCandidates) {
      if (!await _tableExists(db, table)) continue;
      final columns = await _columnsFor(db, table);
      final orderColumn = labelColumns.firstWhere(
        columns.contains,
        orElse: () => '',
      );
      final orderBy = orderColumn.isEmpty
          ? ''
          : ' ORDER BY ${_identifier(orderColumn)} COLLATE NOCASE';
      final rows = await db.rawQuery(
        'SELECT * FROM ${_identifier(table)}$orderBy LIMIT $limit',
      );
      final options = rows
          .map(
            (row) => _optionFromRow(
              row,
              idColumns: idColumns,
              labelColumns: labelColumns,
            ),
          )
          .where((item) => item.hasValue)
          .toList();
      if (options.isNotEmpty) return options;
    }
    return const [];
  }

  Future<Map<String, String>> _loadAdmissionParameters(Database db) async {
    final parameters = <String, String>{};
    if (await _tableExists(db, 'ParametrosAdmisiones_MEN')) {
      final rows = await db.rawQuery(
        'SELECT PAM_IdParametro, PAM_ValorParametro FROM ParametrosAdmisiones_MEN',
      );
      for (final row in rows) {
        parameters[_stringValue(row['PAM_IdParametro'])] = _stringValue(
          row['PAM_ValorParametro'],
        );
      }
    }
    if (await _tableExists(db, 'ParametrosFramework')) {
      final rows = await db.rawQuery(
        'SELECT Codigo, Valor FROM ParametrosFramework',
      );
      for (final row in rows) {
        parameters[_stringValue(row['Codigo'])] = _stringValue(row['Valor']);
      }
    }
    return parameters..removeWhere((key, value) => key.isEmpty);
  }

  Future<int> _countRows(
    DatabaseExecutor db,
    String table, {
    String? where,
  }) async {
    if (!await _tableExists(db, table)) return 0;
    final query =
        'SELECT COUNT(*) AS total FROM ${_identifier(table)}'
        '${where == null ? '' : ' WHERE $where'}';
    final rows = await db.rawQuery(query);
    final value = rows.first['total'];
    if (value is int) return value;
    return int.tryParse(_stringValue(value)) ?? 0;
  }

  Future<int> _availableSuppliesCount(DatabaseExecutor db) async {
    final admision = await _countRows(
      db,
      'SuministrosAdmision',
      where: "utilizado = 0 AND datetime('now','localtime') < fechaVencimiento",
    );
    final legacy = await _countRows(
      db,
      'SuministrosMensajeriaOffLine',
      where: 'Utilizado = 0',
    );
    return math.max(admision, legacy);
  }

  Future<int> _usedSuppliesCount(DatabaseExecutor db) async {
    final admision = await _countRows(
      db,
      'SuministrosAdmision',
      where: 'utilizado <> 0',
    );
    final legacy = await _countRows(
      db,
      'SuministrosMensajeriaOffLine',
      where: 'Utilizado <> 0',
    );
    return math.max(admision, legacy);
  }

  Future<String> _reserveSupply(
    Transaction txn, {
    required String preferredGuide,
  }) async {
    await _ensureAdmissionOfflineTables(txn);

    final guide = preferredGuide.trim().isNotEmpty
        ? preferredGuide.trim()
        : await _nextAvailableSupply(txn);
    if (guide.isEmpty) {
      throw const VenderLocalException(
        'No hay suministros disponibles para registrar la admision offline.',
      );
    }

    final now = _sqliteDateTime(DateTime.now());
    await txn.rawUpdate(
      '''
UPDATE SuministrosAdmision
SET utilizado = 1,
    fechaUtilizado = ?,
    estado = 'UTILIZADO'
WHERE numero = ?
  AND utilizado = 0
''',
      [now, int.tryParse(guide) ?? guide],
    );
    await txn.rawUpdate(
      'UPDATE SuministrosMensajeriaOffLine SET Utilizado = 1 '
      'WHERE NumeroGuia = ? AND Utilizado = 0',
      [guide],
    );
    return guide;
  }

  Future<String> _nextAvailableSupply(Transaction txn) async {
    final admisionRows = await txn.rawQuery('''
SELECT numero
FROM SuministrosAdmision
WHERE utilizado = 0
  AND datetime('now','localtime') < fechaVencimiento
ORDER BY numero ASC
LIMIT 1
''');
    if (admisionRows.isNotEmpty) {
      return _stringValue(admisionRows.first['numero']);
    }
    final legacyRows = await txn.rawQuery(
      'SELECT NumeroGuia FROM SuministrosMensajeriaOffLine '
      'WHERE Utilizado = 0 ORDER BY NumeroGuia ASC LIMIT 1',
    );
    if (legacyRows.isEmpty) return '';
    return _stringValue(legacyRows.first['NumeroGuia']);
  }

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columnsFor(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info(${_identifier(table)})');
    return rows.map((row) => _stringValue(row['name'])).toSet();
  }

  CatalogOption _optionFromRow(
    Map<String, Object?> row, {
    required List<String> idColumns,
    required List<String> labelColumns,
  }) {
    final id = _firstColumnValue(row, idColumns);
    final label = _firstColumnValue(row, labelColumns).trim().isNotEmpty
        ? _firstColumnValue(row, labelColumns)
        : _fallbackLabel(row, except: idColumns);
    return CatalogOption(
      id: id.trim(),
      label: label.trim().isEmpty ? id.trim() : label.trim(),
      raw: row,
    );
  }

  String _firstColumnValue(Map<String, Object?> row, List<String> columns) {
    final lowerIndex = {
      for (final entry in row.entries) entry.key.toLowerCase(): entry.value,
    };
    for (final column in columns) {
      if (row.containsKey(column)) return _stringValue(row[column]);
      final value = lowerIndex[column.toLowerCase()];
      if (value != null) return _stringValue(value);
    }
    return '';
  }

  String _fallbackLabel(
    Map<String, Object?> row, {
    required List<String> except,
  }) {
    final blocked = except.map((item) => item.toLowerCase()).toSet();
    for (final entry in row.entries) {
      if (blocked.contains(entry.key.toLowerCase())) continue;
      final value = _stringValue(entry.value).trim();
      if (value.isNotEmpty && double.tryParse(value) == null) return value;
    }
    for (final value in row.values) {
      final text = _stringValue(value).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    final raw = _stringValue(value).replaceAll(r'$', '').trim();
    if (raw.contains(',')) {
      final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0;
    }
    return double.tryParse(raw) ??
        double.tryParse(raw.replaceAll('.', '')) ??
        0;
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_stringValue(value).trim()) ?? 0;
  }

  bool _boolish(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _stringValue(value).trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí';
  }

  bool _isPaymentCollect(CatalogOption paymentMethod) {
    return paymentMethod.id.trim() == '3' ||
        paymentMethod.label.trim().toUpperCase().contains('AL COBRO');
  }

  bool _serviceWindowIsOpen(Map<String, Object?> row) {
    final start = _minutesFromTime(
      _firstColumnValue(row, const ['CSD_HoraInicial']),
    );
    final end = _minutesFromTime(
      _firstColumnValue(row, const ['CSD_HoraFinal']),
    );
    if (start == null || end == null) return true;
    final now = DateTime.now();
    final current = (now.hour * 60) + now.minute;
    if (start <= end) return current >= start && current <= end;
    return current >= start || current <= end;
  }

  int? _minutesFromTime(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return (hour * 60) + minute;
  }

  String _normalizeSupplyExpiration(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return _sqliteDateTime(DateTime.now().add(const Duration(days: 30)));
    }
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return _sqliteDateTime(parsed);
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(text);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      final hour = int.tryParse(match.group(4) ?? '') ?? 0;
      final minute = int.tryParse(match.group(5) ?? '') ?? 0;
      final second = int.tryParse(match.group(6) ?? '') ?? 0;
      return _sqliteDateTime(DateTime(year, month, day, hour, minute, second));
    }
    return text;
  }

  String _sqliteDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _weekdayForLocalDatabase(DateTime date) {
    if (date.weekday == DateTime.sunday) return '7';
    return date.weekday.toString();
  }

  String _identifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _stringValue(Object? value) => value == null ? '' : value.toString();
}

class _ServicePriceResult {
  const _ServicePriceResult({
    required this.baseValue,
    required this.insuranceServiceId,
    required this.deliveryDays,
  });

  final double baseValue;
  final String insuranceServiceId;
  final int deliveryDays;
}
