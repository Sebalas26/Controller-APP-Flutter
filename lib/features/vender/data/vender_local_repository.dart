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
      availableSupplies: await _countRows(
        db,
        'SuministrosMensajeriaOffLine',
        where: 'Utilizado = 0',
      ),
      usedSupplies: await _countRows(
        db,
        'SuministrosMensajeriaOffLine',
        where: 'Utilizado <> 0',
      ),
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
      final price = await _servicePrice(
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
        serviceId: serviceId,
        priceListId: priceListId,
        declaredValue: declaredValue,
      );
      quotes.add(
        VenderServiceQuote(
          id: serviceId,
          name: serviceName.isEmpty ? 'Servicio $serviceId' : serviceName,
          baseValue: price,
          insuranceValue: insurance,
          totalValue: price + insurance,
          deliveryDays: _intValue(
            _firstExisting(row, const ['SME_DiasEntrega', 'SER_DiasEntrega']),
          ),
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
    if (!await _tableExists(db, 'SuministrosMensajeriaOffLine')) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS SuministrosMensajeriaOffLine('
        'NumeroGuia INTEGER NOT NULL, '
        'FechaSincronizacion NUMERIC NOT NULL, '
        'Utilizado NUMERIC NOT NULL)',
      );
    }
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final supply in supplies) {
        final guide = supply.guideNumber.trim();
        if (guide.isEmpty) continue;
        final exists = await txn.rawQuery(
          'SELECT 1 FROM SuministrosMensajeriaOffLine WHERE NumeroGuia = ? LIMIT 1',
          [guide],
        );
        if (exists.isNotEmpty) continue;
        await txn.insert('SuministrosMensajeriaOffLine', {
          'NumeroGuia': guide,
          'FechaSincronizacion': supply.expirationDate.trim().isNotEmpty
              ? supply.expirationDate
              : now,
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
        return await db.rawQuery(
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

  Future<double?> _servicePrice(
    Database db, {
    required String serviceId,
    required int priceListId,
    required String originCityId,
    required String destinationCityId,
    required String deliveryTypeId,
    required double weight,
  }) async {
    final exception = await _exceptionServicePrice(
      db,
      serviceId: serviceId,
      priceListId: priceListId,
      originCityId: originCityId,
      destinationCityId: destinationCityId,
    );
    if (exception != null) return _priceByWeight(exception, weight);

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
    return _priceByWeight(rows.first, weight);
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
LIMIT 1
''',
      [serviceId, priceListId, originCityId, destinationCityId],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  double _priceByWeight(Map<String, Object?> row, double weight) {
    final initial = _doubleValue(row['PTE_ValorKiloInicial']);
    final additional = _doubleValue(row['PTE_ValorKiloAdicional']);
    final billableWeight = math.max(1, weight.ceil());
    return initial + (math.max(0, billableWeight - 1) * additional);
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
SELECT LPS_PrimaSeguros, LPS_IgnorarPrima
FROM ListaPrecioServicio_TAR
WHERE LPS_IdServicio = ?
  AND LPS_IdListaPrecios = ?
  AND TRIM(LPS_Estado) = 'ACT'
LIMIT 1
''',
      [serviceId, priceListId],
    );
    if (rows.isEmpty) return 0;
    final ignore = _boolish(rows.first['LPS_IgnorarPrima']);
    if (ignore) return 0;
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
    if (!await _tableExists(db, 'ParametrosAdmisiones_MEN')) return const {};
    final rows = await db.rawQuery(
      'SELECT PAM_IdParametro, PAM_ValorParametro FROM ParametrosAdmisiones_MEN',
    );
    return {
      for (final row in rows)
        _stringValue(row['PAM_IdParametro']): _stringValue(
          row['PAM_ValorParametro'],
        ),
    }..removeWhere((key, value) => key.isEmpty);
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

  Future<String> _reserveSupply(
    Transaction txn, {
    required String preferredGuide,
  }) async {
    if (!await _tableExists(txn, 'SuministrosMensajeriaOffLine')) {
      if (preferredGuide.trim().isNotEmpty) return preferredGuide.trim();
      throw const VenderLocalException(
        'No hay tabla local de suministros para registrar la admision offline.',
      );
    }

    final guide = preferredGuide.trim().isNotEmpty
        ? preferredGuide.trim()
        : await _nextAvailableSupply(txn);
    if (guide.isEmpty) {
      throw const VenderLocalException(
        'No hay suministros disponibles para registrar la admision offline.',
      );
    }

    await txn.rawUpdate(
      'UPDATE SuministrosMensajeriaOffLine SET Utilizado = 1 '
      'WHERE NumeroGuia = ? AND Utilizado = 0',
      [guide],
    );
    return guide;
  }

  Future<String> _nextAvailableSupply(Transaction txn) async {
    final rows = await txn.rawQuery(
      'SELECT NumeroGuia FROM SuministrosMensajeriaOffLine '
      'WHERE Utilizado = 0 ORDER BY NumeroGuia ASC LIMIT 1',
    );
    if (rows.isEmpty) return '';
    return _stringValue(rows.first['NumeroGuia']);
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

  Object? _firstExisting(Map<String, Object?> row, List<String> columns) {
    final lowerIndex = {
      for (final entry in row.entries) entry.key.toLowerCase(): entry.value,
    };
    for (final column in columns) {
      if (row.containsKey(column)) return row[column];
      final value = lowerIndex[column.toLowerCase()];
      if (value != null) return value;
    }
    return null;
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

  String _weekdayForLocalDatabase(DateTime date) {
    if (date.weekday == DateTime.sunday) return '7';
    return date.weekday.toString();
  }

  String _identifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _stringValue(Object? value) => value == null ? '' : value.toString();
}
