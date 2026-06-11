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
    await _backfillNativeOfflineAdmissions(db, appInformation);
    final sql = '''
      SELECT 
        Localidad_PAR.LOC_IdLocalidad, 
        Localidad_PAR_2.LOC_Nombre AS LOC_NombreSegundo, 
        Localidad_PAR_2.LOC_NombreCorto AS LOC_NombreCortoSegundo, 
        Localidad_PAR.LOC_CodigoPostal, 
        Localidad_PAR_1.LOC_Nombre AS Departamento,
        Localidad_PAR.LOC_Nombre || 
          CASE WHEN Localidad_PAR_1.LOC_NombreCorto IS NULL THEN '' ELSE ' \\ ' || Localidad_PAR_1.LOC_NombreCorto END NombreCompleto, 
        Localidad_PAR.LOC_Nombre || 
          CASE WHEN Localidad_PAR_1.LOC_NombreCorto IS NULL THEN '' ELSE ' \\ ' || Localidad_PAR_1.LOC_NombreCorto END || 
          CASE WHEN Localidad_PAR_2.LOC_NombreCorto IS NULL THEN '' ELSE ' \\ ' || Localidad_PAR_2.LOC_NombreCorto END AS NombreCompletoPais, 
        Localidad_PAR.LOC_Nombre || 
          CASE WHEN Localidad_PAR_1.LOC_Nombre IS NULL THEN '' ELSE ' \\ ' || Localidad_PAR_1.LOC_Nombre END AS NombreCompletoDept 
      FROM Localidad_PAR 
      LEFT JOIN Localidad_PAR AS Localidad_PAR_1 ON Localidad_PAR_1.LOC_IdLocalidad = Localidad_PAR.LOC_IdAncestroPrimerGrado 
      LEFT JOIN Localidad_PAR AS Localidad_PAR_2 ON Localidad_PAR_2.LOC_IdLocalidad = Localidad_PAR.LOC_IdAncestroSegundoGrado 
      LEFT JOIN Localidad_PAR AS Localidad_PAR_3 ON Localidad_PAR_3.LOC_IdLocalidad = Localidad_PAR.LOC_IdAncestroTercerGrado 
      WHERE Localidad_PAR.LOC_IdTipo <> 1 
        AND Localidad_PAR.LOC_IdTipo <> 2 
        AND Localidad_PAR.LOC_IdAncestroSegundoGrado IS NOT NULL 
        AND (Localidad_PAR.LOC_IdAncestroSegundoGrado LIKE '057' OR Localidad_PAR.LOC_IdAncestroTercerGrado LIKE '057')
      ORDER BY NombreCompleto;
    ''';
    final destinationCities = await _loadOptions(
      db,
      customQuery: sql,
      idColumns: const ['LOC_IdLocalidad', 'IdLocalidad'],
      labelColumns: const [
        'NombreCompleto',
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
      pendingOfflineAdmissions: await _pendingOfflineAdmissionsCount(db),
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
    required AppInformation appInformation,
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
      if (reserveSupply) {
        await _insertNativeOfflineAdmission(
          txn,
          draft: payload,
          appInformation: appInformation,
          createdAt: DateTime.now(),
        );
      }

      return VenderSaveResult(id: id, guideNumber: guideNumber, status: status);
    });
  }

  Future<List<VenderOfflineAdmissionRecord>> pendingOfflineAdmissions() async {
    final db = await _openDatabase();
    await _ensureDraftTable(db);
    await _ensureAdmissionOfflineTables(db);
    final rows = await db.query(
      'AdmisionMensajeriaOffLine',
      columns: const [
        'IdAdmisionOffline',
        'NumeroGuia',
        'ObjetoMensajeriaRequest',
        'ObjetoADGuiaImpresion',
      ],
      where: 'EstaSincronizado = 0',
      orderBy: 'IdAdmisionOffline ASC',
    );
    return rows.map(VenderOfflineAdmissionRecord.fromRow).toList();
  }

  Future<VenderOfflineAdmissionRecord?> pendingOfflineAdmissionByGuide(
    String guideNumber,
  ) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty) return null;
    final db = await _openDatabase();
    await _ensureDraftTable(db);
    await _ensureAdmissionOfflineTables(db);
    final rows = await db.query(
      'AdmisionMensajeriaOffLine',
      columns: const [
        'IdAdmisionOffline',
        'NumeroGuia',
        'ObjetoMensajeriaRequest',
        'ObjetoADGuiaImpresion',
      ],
      where: 'EstaSincronizado = 0 AND NumeroGuia = ?',
      whereArgs: [guide],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VenderOfflineAdmissionRecord.fromRow(rows.first);
  }

  Future<void> markOfflineAdmissionSynchronized(
    VenderOfflineAdmissionRecord admission,
  ) async {
    final db = await _openDatabase();
    await _ensureDraftTable(db);
    await _ensureAdmissionOfflineTables(db);
    await db.transaction((txn) async {
      if (admission.id > 0) {
        await txn.delete(
          'AdmisionMensajeriaOffLine',
          where: 'IdAdmisionOffline = ?',
          whereArgs: [admission.id],
        );
      } else {
        await txn.delete(
          'AdmisionMensajeriaOffLine',
          where: 'NumeroGuia = ?',
          whereArgs: [admission.guideNumber],
        );
      }
      await txn.update(
        'vender_drafts',
        {'status': 'synced', 'updated_at': DateTime.now().toIso8601String()},
        where: 'guide_number = ?',
        whereArgs: [admission.guideNumber],
      );
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

  Future<void> _backfillNativeOfflineAdmissions(
    Database db,
    AppInformation appInformation,
  ) async {
    final rows = await db.rawQuery('''
SELECT id, payload_json, guide_number
FROM vender_drafts
WHERE status = 'pending_offline'
  AND COALESCE(TRIM(guide_number), '') <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM AdmisionMensajeriaOffLine adm
    WHERE adm.NumeroGuia = vender_drafts.guide_number
      AND adm.EstaSincronizado = 0
  )
ORDER BY id ASC
''');
    if (rows.isEmpty) return;
    await db.transaction((txn) async {
      for (final row in rows) {
        try {
          final decoded = jsonDecode(_stringValue(row['payload_json']));
          if (decoded is! Map) continue;
          final draft = VenderDraft.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          final guide = _stringValue(row['guide_number']).trim();
          await _insertNativeOfflineAdmission(
            txn,
            draft: draft.copyWith(guideNumber: guide),
            appInformation: appInformation,
            createdAt: draft.createdAt,
          );
        } on Object {
          continue;
        }
      }
    });
  }

  Future<void> _insertNativeOfflineAdmission(
    DatabaseExecutor db, {
    required VenderDraft draft,
    required AppInformation appInformation,
    required DateTime createdAt,
  }) async {
    final guide = draft.guideNumber.trim();
    if (guide.isEmpty) return;
    final request = _nativeAdmissionRequest(
      draft,
      appInformation: appInformation,
      createdAt: createdAt,
    );
    final printPayload = _nativePrintPayload(
      draft,
      appInformation: appInformation,
      createdAt: createdAt,
    );
    await db.delete(
      'AdmisionMensajeriaOffLine',
      where: 'NumeroGuia = ? AND EstaSincronizado = 0',
      whereArgs: [guide],
    );
    await db.insert('AdmisionMensajeriaOffLine', {
      'NumeroGuia': guide,
      'ObjetoMensajeriaRequest': jsonEncode(request),
      'ObjetoADGuiaImpresion': jsonEncode(printPayload),
      'EstaSincronizado': 0,
      'FechaSincronizacion': _sqliteDateTime(createdAt),
    });
  }

  Map<String, Object?> _nativeAdmissionRequest(
    VenderDraft draft, {
    required AppInformation appInformation,
    required DateTime createdAt,
  }) {
    final origin = draft.origin;
    final destination = draft.destination;
    final initial = draft.initialData;
    final settlement = draft.settlement;
    final sender = draft.sender;
    final recipient = draft.recipient;
    final guide = draft.guideNumber.trim();
    final deliveryDays = _mapInt(settlement, 'deliveryDays');
    final estimatedDate = createdAt.add(
      Duration(days: math.max(0, deliveryDays)),
    );
    final senderThird = _nativeThirdParty(
      sender,
      cityId: _mapString(origin, 'cityId'),
      fechaGrabacion: _controllerDateTime(createdAt),
    );
    final recipientThird = _nativeThirdParty(
      recipient,
      cityId: _mapString(destination, 'cityId'),
      fechaGrabacion: _controllerDateTime(createdAt),
    );
    final admissionPreenvio = <String, Object?>{
      'idPreenvio': 0,
      'numeroPreenvio': _longValue(guide),
      'idPreenvioRecogida': 0,
      'idUnidadNegocio': 'MEN',
      'idServicio': _mapInt(settlement, 'serviceId'),
      'idTipoEntrega': _mapString(destination, 'deliveryTypeId'),
      'idCentroServicioOrigen': _mapInt(origin, 'serviceCenterId'),
      'nombreCentroServicioOrigen': _mapString(origin, 'serviceCenterLabel'),
      'idCentroServicioDestino': 0,
      'idPaisOrigen': '057',
      'idCiudadOrigen': _mapString(origin, 'cityId'),
      'codigoPostalOrigen': '',
      'idPaisDestino': '057',
      'idCiudadDestino': _mapString(destination, 'cityId'),
      'codigoPostalDestino': _postalCode(recipient, destination),
      'tipoCliente': '',
      'diasDeEntrega': deliveryDays,
      'fechaEstimadaEntrega': _controllerDateTime(estimatedDate),
      'valorTotal': _mapDouble(settlement, 'totalValue'),
      'valorDeclarado': _mapDouble(initial, 'declaredValue'),
      'diceContener': _upper(_mapString(settlement, 'content')),
      'peso': _mapDouble(initial, 'finalWeight').ceil(),
      'idTipoEnvio': _mapInt(settlement, 'shippingTypeId'),
      'esAlCobro': _isCollectPayment(draft),
      'numeroPieza': _mapInt(initial, 'pieces', fallback: 1),
      'idFormaPago': _mapInt(initial, 'paymentMethodId'),
      'nombreFormaPago': _mapString(initial, 'paymentMethodLabel'),
      'nombreServicio': _mapString(settlement, 'serviceLabel'),
      'descripcionTipoEntrega': _mapString(destination, 'deliveryTypeLabel'),
      'nombreCiudadOrigen': _mapString(origin, 'cityLabel'),
      'nombreCiudadDestino': _mapString(destination, 'cityLabel'),
      'valorAdmision': _mapDouble(settlement, 'baseValue'),
      'valorTotalImpuestos': 0,
      'valorTotalRetenciones': 0,
      'valorPrimaSeguro': _mapDouble(settlement, 'insuranceValue'),
      'valorEmpaque': 0,
      'valorAdicionales': 0,
      'valorContraPago': 0,
      'observaciones': _mapString(settlement, 'observations'),
      'pesoLiqVolumetrico': _mapDouble(initial, 'weightVolume').ceil(),
      'pesoLiqMasa': _mapDouble(initial, 'weightScale').ceil(),
      'esPesoVolumetrico':
          _mapDouble(initial, 'weightVolume') >
          _mapDouble(initial, 'weightScale'),
      'numeroBolsaSeguridad': _mapString(settlement, 'securityBag'),
      'idMotivoNoUsoBolsaSegurida': 0,
      'motivoNoUsoBolsaSeguriDesc': '',
      'noUsoaBolsaSeguridadObserv': '',
      'idUnidadMedida': 'kg',
      'largo': _mapDouble(initial, 'length'),
      'ancho': _mapDouble(initial, 'width'),
      'alto': _mapDouble(initial, 'height'),
      'nombreTipoEnvio': _mapString(settlement, 'shippingTypeLabel'),
      'emailRemitente': _mapString(sender, 'email'),
      'emailDestinatario': _mapString(recipient, 'email'),
      'idCaja': _intValue(appInformation.idCaja),
      'remitente': senderThird,
      'destinatario': recipientThird,
      'idPreFactura': 0,
      'idMensajero': _intValue(appInformation.idMensajero),
      'verificacionContenido': _mapBool(settlement, 'contentChecked'),
      'esPagoEnCasa': _mapBool(initial, 'paymentAtHome'),
      'FueraHorario': false,
      'offline': true,
    };
    final guidePayload = <String, Object?>{
      'NumeroGuia': guide,
      'IdCentroServicioOrigen': _mapInt(origin, 'serviceCenterId'),
      'Caja': _intValue(appInformation.idCaja),
      'IdServicio': _mapInt(settlement, 'serviceId'),
      'IdListaPrecios': 0,
      'DiasDeEntrega': deliveryDays,
      'TotalPiezas': _mapInt(initial, 'pieces', fallback: 1),
      'IdTipoEnvio': _mapInt(settlement, 'shippingTypeId'),
      'EsAutomatico': true,
      'EsPesoVolumetrico':
          _mapDouble(initial, 'weightVolume') >
          _mapDouble(initial, 'weightScale'),
      'AdmisionSistemaMensajero': true,
      'EsAlCobro': _isCollectPayment(draft),
      'EstaPagada': !_isCollectPayment(draft),
      'EsPagoEnCasa': _mapBool(initial, 'paymentAtHome'),
      'IdUnidadNegocio': 'MEN',
      'NombreServicio': _mapString(settlement, 'serviceLabel'),
      'IdTipoEntrega': _mapString(destination, 'deliveryTypeId'),
      'NombreCentroServicioOrigen': _mapString(origin, 'serviceCenterLabel'),
      'IdPaisOrigen': '057',
      'NombrePaisOrigen': 'COLOMBIA',
      'IdCiudadOrigen': _mapString(origin, 'cityId'),
      'NombreCiudadOrigen': _mapString(origin, 'cityLabel'),
      'IdPaisDestino': '057',
      'NombrePaisDestino': 'COLOMBIA',
      'IdCiudadDestino': _mapString(destination, 'cityId'),
      'NombreCiudadDestino': _mapString(destination, 'cityLabel'),
      'TelefonoDestinatario': _mapString(recipient, 'phone'),
      'Observaciones': _mapString(settlement, 'observations'),
      'NumeroBolsaSeguridad': _mapString(settlement, 'securityBag'),
      'IdUnidadMedida': 'kg',
      'NombreTipoEnvio': _mapString(settlement, 'shippingTypeLabel'),
      'NombreMensajero': appInformation.nombreMensajero,
      'FechaAdmision': _controllerDateTime(createdAt),
      'FechaGrabacion': _controllerDateTime(createdAt),
      'FechaEstimadaEntrega': _controllerDateTime(estimatedDate),
      'DiceContener': _upper(_mapString(settlement, 'content')),
      'CodigoPostalOrigen': '',
      'CreadoPor': appInformation.idUsuario,
      'CodigoPostalDestino': _postalCode(recipient, destination),
      'DescripcionTipoEntrega': _mapString(destination, 'deliveryTypeLabel'),
      'DireccionDestinatario': _upper(_mapString(recipient, 'address')),
      'ValorAdmision': _mapDouble(settlement, 'baseValue'),
      'ValorTotal': _mapDouble(settlement, 'totalValue'),
      'ValorTotalImpuestos': 0,
      'ValorTotalRetenciones': 0,
      'ValorPrimaSeguro': _mapDouble(settlement, 'insuranceValue'),
      'ValorEmpaque': 0,
      'ValorAdicionales': 0,
      'ValorDeclarado': _mapDouble(initial, 'declaredValue'),
      'Peso': _mapDouble(initial, 'finalWeight'),
      'PesoLiqMasa': _mapDouble(initial, 'weightScale'),
      'Largo': _mapDouble(initial, 'length'),
      'Ancho': _mapDouble(initial, 'width'),
      'Alto': _mapDouble(initial, 'height'),
      'ValorServicio': _mapDouble(settlement, 'baseValue'),
      'valorContraPago': 0,
      'IdMensajero': _intValue(appInformation.idMensajero),
      'IdCodigoUsuario': _intValue(appInformation.idUsuario),
      'PesoLiqVolumetrico': _mapDouble(initial, 'weightVolume'),
      'FormasPago': [
        {
          'IdFormaPago': _mapInt(initial, 'paymentMethodId'),
          'Valor': _mapDouble(settlement, 'totalValue'),
        },
      ],
    };
    return {
      'Guia': guidePayload,
      'idCaja': _intValue(appInformation.idCaja),
      'RemitenteDestinatario': {
        'FacturaRemitente': false,
        'IdContratoConvenioRemitente': 0,
        'ConvenioRemitente': null,
        'ConvenioDestinatario': null,
        'PeatonRemitente': senderThird,
        'PeatonDestinatario': recipientThird,
      },
      'Notificacion': _nativeNotification(draft, createdAt),
      'Radicado': <String, Object?>{},
      'admisionPreenvio': admissionPreenvio,
      'recogidaPreenvio': _nativePickupSender(
        draft,
        appInformation: appInformation,
        createdAt: createdAt,
      ),
      'IdPreFactura': 0,
    };
  }

  Map<String, Object?> _nativePrintPayload(
    VenderDraft draft, {
    required AppInformation appInformation,
    required DateTime createdAt,
  }) {
    final origin = draft.origin;
    final destination = draft.destination;
    final initial = draft.initialData;
    final settlement = draft.settlement;
    final sender = draft.sender;
    final recipient = draft.recipient;
    final deliveryDays = _mapInt(settlement, 'deliveryDays');
    final estimatedDate = createdAt.add(
      Duration(days: math.max(0, deliveryDays)),
    );
    return {
      'NumeroGuia': draft.guideNumber.trim(),
      'FechaEstimadaEntrega': _ticketDateTime(estimatedDate),
      'FechaPreenvio': _ticketDateTime(createdAt),
      'NombreCiudadDestinatario': _upper(_mapString(destination, 'cityLabel')),
      'CodigoCiudadDestinatario': _mapString(destination, 'cityId'),
      'NombreDestinatario': _upper(_fullName(recipient)),
      'NumeroIdentificacionDestinatario': _mapString(recipient, 'document'),
      'TelefonoDestinatario': _mapString(recipient, 'phone'),
      'DireccionDestinatario': _upper(_mapString(recipient, 'address')),
      'CodigoPostalDestino': _postalCode(recipient, destination),
      'NombreRemitente': _upper(_fullName(sender)),
      'NumeroIdentificacionRemitente': _mapString(sender, 'document'),
      'TelefonoRemitente': _mapString(sender, 'phone'),
      'DireccionRemitente': _upper(_mapString(sender, 'address')),
      'NombreCiudadRemitente': _upper(_mapString(origin, 'cityLabel')),
      'CodigoCiudadRemitente': _mapString(origin, 'cityId'),
      'EmailRemitente': _upper(_mapString(sender, 'email')),
      'CodigoPostalRemitente': _postalCode(sender, origin),
      'TipoEmpaque': _upper(_mapString(settlement, 'packageLabel')),
      'NumeroPiezas': _mapString(initial, 'pieces'),
      'Peso': _mapDouble(initial, 'finalWeight').toString(),
      'BolsaSeguridad': _upper(_mapString(settlement, 'securityBag')),
      'DiceContener': _upper(_mapString(settlement, 'content')),
      'TipoEnvio': _upper(_mapString(settlement, 'shippingTypeLabel')),
      'FormaPago': _upper(_mapString(initial, 'paymentMethodLabel')),
      'NombreServicio': _upper(_mapString(settlement, 'serviceLabel')),
      'FranjaServicio': '',
      'IdServicio': _mapInt(settlement, 'serviceId'),
      'ValorContraPago': 0,
      'ValorDeclarado': _mapDouble(initial, 'declaredValue'),
      'ValorComercial': _mapDouble(initial, 'declaredValue').toString(),
      'ValorTransporte': _mapDouble(settlement, 'baseValue').toString(),
      'ValorPrima': _mapDouble(settlement, 'insuranceValue').toString(),
      'ValorOtros': '0',
      'ValorTotal': _mapDouble(settlement, 'totalValue').toString(),
      'AfectaTiempos': false,
      'FueraHorario': false,
      'FechaEstimadaEntregaNew': '',
      'IdTipoEntrega': _mapString(destination, 'deliveryTypeId'),
      'isAdmisionDirecta': false,
      'isFromPreenvioCobroPagoCasa': false,
      'observacion': _mapString(settlement, 'observations'),
      'offline': true,
      'errorPuertasCasilleros': false,
      'fromReimpresion': false,
      'idCentroServicioOrigen': _mapInt(origin, 'serviceCenterId'),
      'pagoEnCasa': _mapBool(initial, 'paymentAtHome'),
      'idTipoVivienda': _mapInt(recipient, 'propertyTypeId'),
      'tipoEntrega': _mapString(destination, 'deliveryTypeLabel'),
      'microZona': _geoString(recipient, 'microZona'),
      'macroZona': _geoString(recipient, 'macroZona'),
    };
  }

  Map<String, Object?> _nativeThirdParty(
    Map<String, Object?> person, {
    required String cityId,
    required String fechaGrabacion,
  }) {
    return {
      'idDestinatario': 0,
      'idRemitente': 0,
      'tipoDocumento': _mapString(person, 'identificationTypeId'),
      'nombre': _upper(_mapString(person, 'name')),
      'primerApellido': _upper(_nativeFirstLastName(person)),
      'segundoApellido': _upper(_mapString(person, 'secondLastName')),
      'telefono': _mapString(person, 'phone'),
      'direccion': _upper(_mapString(person, 'address')),
      'correo': _upper(_mapString(person, 'email')),
      'fechaGrabacion': fechaGrabacion,
      'numeroDocumento': _mapString(person, 'document'),
      'convenioDestinatario': 0,
      'idTipoVivienda': _mapInt(person, 'propertyTypeId'),
      'IdDireccionGeneral': _geoInt(person, 'idDireccionGeneral'),
      'Valor': 0,
      'microZona': _geoString(person, 'microZona'),
      'macroZona': _geoString(person, 'macroZona'),
      'latitud': _geoString(person, 'latitude'),
      'longitud': _geoString(person, 'longitude'),
      'zonaPostal': _postalCode(person, const <String, Object?>{}),
      'idLocalidad': _geoString(person, 'idLocalidad').trim().isNotEmpty
          ? _geoString(person, 'idLocalidad')
          : cityId,
      'NumeroAsociadoFormaPago': '',
    };
  }

  Map<String, Object?> _nativePickupSender(
    VenderDraft draft, {
    required AppInformation appInformation,
    required DateTime createdAt,
  }) {
    final sender = draft.sender;
    final origin = draft.origin;
    return {
      'NumeroDocumento': _mapString(sender, 'document'),
      'Nombre': _upper(_fullName(sender)),
      'Direccion': _upper(_mapString(sender, 'address')),
      'Ciudad': _mapString(origin, 'cityId'),
      'nombreCiudad': _mapString(origin, 'cityLabel'),
      'NumeroTelefono': _mapString(sender, 'phone'),
      'FechaRecogida': _controllerDateTime(
        createdAt.add(const Duration(hours: 1)),
      ),
      'TipoRecogida': 2,
      'nombreLocalidad': _mapString(draft.destination, 'cityLabel'),
      'longitud': _geoString(sender, 'longitude'),
      'latitud': _geoString(sender, 'latitude'),
      'tipoDocumento': _mapString(sender, 'identificationTypeId'),
      'nombreCompleto': _upper(_fullName(sender)),
      'correo': _upper(_mapString(sender, 'email')),
      'PreguntarPor': '',
      'DocPersonaResponsable': appInformation.identificacionUsuario,
      'descripcionEnvios': _mapString(draft.settlement, 'content'),
    };
  }

  Map<String, Object?> _nativeNotification(
    VenderDraft draft,
    DateTime createdAt,
  ) {
    final recipient = draft.recipient;
    final destination = draft.destination;
    return {
      'idNotificacion': 0,
      'idAdmisionPreenvio': 0,
      'idDestinatario': 0,
      'idTipoDestino': _mapString(recipient, 'identificationTypeId'),
      'idCiudadDestino': _mapString(destination, 'cityId'),
      'fechaGrabacion': _controllerDateTime(createdAt),
      'direccionDestinatario': _upper(_mapString(recipient, 'address')),
      'nombreCiudadDestino': _mapString(destination, 'cityLabel'),
      'tipoDestino': _mapString(recipient, 'identificationTypeLabel'),
      'entregarDireccionRemitente': false,
      'NombreDestinatario': _upper(_mapString(recipient, 'name')),
      'Apellido1Destinatario': _upper(_mapString(recipient, 'firstLastName')),
      'Apellido2Destinatario': _upper(_mapString(recipient, 'secondLastName')),
      'TelefonoDestinatario': _mapString(recipient, 'phone'),
      'EmailDestinatario': _upper(_mapString(recipient, 'email')),
      'TipoIdentificacionDestinatario': _mapString(
        recipient,
        'identificationTypeId',
      ),
    };
  }

  bool _isCollectPayment(VenderDraft draft) {
    final id = _mapString(draft.initialData, 'paymentMethodId').trim();
    final label = _mapString(
      draft.initialData,
      'paymentMethodLabel',
    ).trim().toUpperCase();
    return id == '3' || label.contains('AL COBRO');
  }

  String _fullName(Map<String, Object?> person) {
    return [
      _mapString(person, 'name'),
      _mapString(person, 'firstLastName'),
      _mapString(person, 'secondLastName'),
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  }

  String _nativeFirstLastName(Map<String, Object?> person) {
    final type = _mapString(
      person,
      'identificationTypeId',
    ).trim().toUpperCase();
    if (type == 'NI') return '.';
    return _mapString(person, 'firstLastName');
  }

  String _postalCode(
    Map<String, Object?> person,
    Map<String, Object?> location,
  ) {
    final rawLocation = location['cityRaw'] is Map
        ? Map<String, Object?>.from(location['cityRaw'] as Map)
        : const <String, Object?>{};
    for (final key in const [
      'zonaPostal',
      'ZonaPostal',
      'zonapostal',
      'codigoPostal',
      'CodigoPostal',
      'LOC_CodigoPostal',
    ]) {
      final value = _geoString(person, key).trim();
      if (value.isNotEmpty && value != '0') return value;
      final locationValue = _mapString(location, key).trim();
      if (locationValue.isNotEmpty && locationValue != '0') {
        return locationValue;
      }
      final rawValue = _mapString(rawLocation, key).trim();
      if (rawValue.isNotEmpty && rawValue != '0') return rawValue;
    }
    return '';
  }

  Map<String, Object?> _geo(Map<String, Object?> person) {
    final value = person['geo'];
    if (value is Map<String, Object?>) {
      final data = value['data'] ?? value['Data'];
      if (data is Map) return Map<String, Object?>.from(data);
      return value;
    }
    if (value is Map) {
      final map = Map<String, Object?>.from(value);
      final data = map['data'] ?? map['Data'];
      if (data is Map) return Map<String, Object?>.from(data);
      return map;
    }
    return const <String, Object?>{};
  }

  String _geoString(Map<String, Object?> person, String key) {
    final geo = _geo(person);
    final lowerIndex = {
      for (final entry in geo.entries) entry.key.toLowerCase(): entry.value,
    };
    final normalizedKey = key.toLowerCase();
    final fallbackKey = normalizedKey == 'microzona'
        ? 'zona2'
        : normalizedKey == 'macrozona'
        ? 'zona3'
        : '';
    return _stringValue(
      geo[key] ??
          lowerIndex[normalizedKey] ??
          (fallbackKey.isEmpty ? null : lowerIndex[fallbackKey]),
    );
  }

  int _geoInt(Map<String, Object?> person, String key) {
    return _intValue(_geoString(person, key));
  }

  String _mapString(Map<String, Object?> map, String key) {
    return _stringValue(map[key]);
  }

  int _mapInt(Map<String, Object?> map, String key, {int fallback = 0}) {
    final value = _intValue(map[key]);
    return value == 0 ? fallback : value;
  }

  double _mapDouble(Map<String, Object?> map, String key) {
    return _doubleValue(map[key]);
  }

  bool _mapBool(Map<String, Object?> map, String key) {
    return _boolish(map[key]);
  }

  int _longValue(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  String _upper(String value) {
    return value.trim().toUpperCase();
  }

  String _controllerDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)}T'
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}Z';
  }

  String _ticketDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
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
    List<String> tableCandidates = const [],
    required List<String> idColumns,
    required List<String> labelColumns,
    required int limit,
    String? customQuery,
  }) async {
    if (customQuery != null && customQuery.trim().isNotEmpty) {
      final queryWithLimit = customQuery.toLowerCase().contains('limit')
          ? customQuery
          : '$customQuery LIMIT $limit';

      final rows = await db.rawQuery(queryWithLimit);

      return rows
          .map(
            (row) => _optionFromRow(
              row,
              idColumns: idColumns,
              labelColumns: labelColumns,
            ),
          )
          .where((item) => item.hasValue)
          .toList();
    }
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
    try {
      if (await _tableExists(db, 'ParametrosAdmisiones_MEN')) {
        final admissionColumns = await _columnsFor(
          db,
          'ParametrosAdmisiones_MEN',
        );
        if (admissionColumns.contains('PAM_IdParametro') &&
            admissionColumns.contains('PAM_ValorParametro')) {
          final rows = await db.query(
            'ParametrosAdmisiones_MEN',
            columns: const ['PAM_IdParametro', 'PAM_ValorParametro'],
          );
          for (final row in rows) {
            parameters[_stringValue(row['PAM_IdParametro'])] = _stringValue(
              row['PAM_ValorParametro'],
            );
          }
        }
      }
      if (await _tableExists(db, 'ParametrosFramework')) {
        final frameworkColumns = await _columnsFor(db, 'ParametrosFramework');
        final codeColumn = _firstAvailableColumn(frameworkColumns, const [
          'PAR_IdParametro',
          'Codigo',
          'PAR_Codigo',
          'Nombre',
          'PFR_Nombre',
          'Parametro',
        ]);
        final valueColumn = _firstAvailableColumn(frameworkColumns, const [
          'PAR_ValorParametro',
          'Valor',
          'PAR_Valor',
          'PFR_Valor',
          'ValorParametro',
          'Descripcion',
        ]);
        if (codeColumn.isNotEmpty && valueColumn.isNotEmpty) {
          final rows = await db.query(
            'ParametrosFramework',
            columns: [codeColumn, valueColumn],
          );
          for (final row in rows) {
            parameters[_stringValue(row[codeColumn])] = _stringValue(
              row[valueColumn],
            );
          }
        }
      }
    } on Object {
      return parameters..removeWhere((key, value) => key.isEmpty);
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

  Future<int> _pendingOfflineAdmissionsCount(DatabaseExecutor db) async {
    final native = await _countRows(
      db,
      'AdmisionMensajeriaOffLine',
      where: 'EstaSincronizado = 0',
    );
    final drafts = await _countRows(
      db,
      'vender_drafts',
      where: "status <> 'synced'",
    );
    return math.max(native, drafts);
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

  String _firstAvailableColumn(Set<String> columns, List<String> candidates) {
    final lowerIndex = {
      for (final column in columns) column.toLowerCase(): column,
    };
    for (final candidate in candidates) {
      final column = lowerIndex[candidate.toLowerCase()];
      if (column != null) return column;
    }
    return '';
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
