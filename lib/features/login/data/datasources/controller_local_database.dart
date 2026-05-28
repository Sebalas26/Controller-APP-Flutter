part of '../login_data.dart';

class ControllerLocalDatabase {
  ControllerLocalDatabase({ControllerCrypto? crypto})
    : _crypto = crypto ?? ControllerCrypto();

  final ControllerCrypto _crypto;
  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(
      path.join(dbPath, 'controller_app_flutter.db'),
      version: 1,
      onCreate: _onCreate,
      onOpen: _ensureSchema,
    );
    _db = db;
    return db;
  }

  Future<AuthenticatedSession?> loadActiveSession({
    required String environmentLabel,
  }) async {
    final db = await database;
    final appRows = await db.query('app_information', limit: 1);
    if (appRows.isEmpty) return null;
    final appInfo = AppInformation.fromDb(appRows.first);
    if (appInfo.environmentLabel != environmentLabel) return null;
    if (_isLoginExpired(appInfo.loginDateCompact)) return null;

    final credentialRows = await db.query(
      'credentials',
      where: 'active = 1',
      limit: 1,
    );
    if (credentialRows.isEmpty) return null;

    final syncStatus = await currentSyncStatus();
    final modules = await _loadModules(db);
    final loginDate =
        _parseCompactDate(appInfo.loginDateCompact) ??
        _parseHumanDate(appInfo.loginDate) ??
        DateTime.now();

    return AuthenticatedSession(
      username: _dbString(credentialRows.first['username']),
      environmentLabel: environmentLabel,
      rememberUser: true,
      loginDate: loginDate,
      appInformation: appInfo,
      syncStatus: syncStatus,
      modules: modules,
      offline: false,
    );
  }

  Future<AuthenticatedSession> validateOfflineLogin({
    required String username,
    required String password,
    required String aesSecret,
    required String environmentLabel,
    required bool rememberUser,
  }) async {
    final db = await database;
    final credentialRows = await db.query(
      'credentials',
      where: 'username = ? AND active = 1',
      whereArgs: [username],
      limit: 1,
    );
    if (credentialRows.isEmpty) {
      throw const LoginException(
        'No hay credenciales locales para este usuario.',
      );
    }

    final row = credentialRows.first;
    final decrypted = _crypto.decryptAES256(
      _dbString(row['password_aes256']),
      aesSecret,
    );
    if (decrypted != password) {
      throw const LoginException('Usuario o contrasena local invalida.');
    }

    final appRows = await db.query('app_information', limit: 1);
    if (appRows.isEmpty) {
      throw const LoginException('No hay informacion local de sesion.');
    }

    final appInfo = AppInformation.fromDb(appRows.first);
    if (appInfo.environmentLabel != environmentLabel) {
      throw const LoginException('La sesion local pertenece a otro ambiente.');
    }

    final limit = await offlineHoursLimit();
    final lastLogin = _parseHumanDate(appInfo.loginDate);
    if (lastLogin == null ||
        DateTime.now().difference(lastLogin).inHours > limit) {
      throw const LoginException('El tiempo de acceso offline fue superado.');
    }

    return AuthenticatedSession(
      username: username,
      environmentLabel: environmentLabel,
      rememberUser: rememberUser,
      loginDate: lastLogin,
      appInformation: appInfo,
      syncStatus: await currentSyncStatus(),
      modules: await _loadModules(db),
      offline: true,
    );
  }

  Future<AppInformation> saveLoginBootstrap({
    required LoginCredential credential,
    required AuthorizedLocation location,
    required String username,
    required String plainPassword,
    required String environmentLabel,
    required bool active,
    required String aesSecret,
  }) async {
    final db = await database;
    final appInfo = AppInformation.fromLogin(
      credential: credential,
      location: location,
      environmentLabel: environmentLabel,
    );

    await db.transaction((txn) async {
      await txn.insert(
        'app_information',
        appInfo.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('modules_app');
      await txn.delete('roles');
      await txn.insert('credentials', {
        'username': username,
        'password_md5': _crypto.md5Lower(plainPassword),
        'password_base64': _crypto.base64Utf8(plainPassword),
        'password_aes256': _crypto.encryptAES256(plainPassword, aesSecret),
        'session_json': jsonEncode(credential.toJson()),
        'active': active ? 1 : 0,
        'id_localidad_autorizada': location.cityId,
        'nombre_localidad_autorizada': location.cityName,
        'id_centro_servicio_autorizado': location.serviceCenterId.toString(),
        'nombre_centro_servicio_autorizado': location.serviceCenterName,
        'id_caja': location.cashBoxId.toString(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('tokens', {
        'id': 1,
        'token_refresh': credential.userAppLogin?.tokenRefresh ?? '',
        'token': credential.userAppLogin?.user?.token ?? '',
        'uuid_dispositivo': credential.userAppLogin?.uuidDevice ?? '',
        'user_name': credential.userAppLogin?.user?.userName ?? '',
        'id_rol_apoyo_a_crear': credential.idRolApoyoACrear,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final module in credential.modules) {
        await txn.insert('modules_app', {
          'mod_id': module.id,
          'name': module.name,
          'enabled': module.enabled ? 1 : 0,
          'visible': module.visible ? 1 : 0,
          'sort_order': module.order,
          'application_id': module.applicationId,
          'new_date': module.newDate,
          'primary_module': module.primary ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final role in credential.roles) {
        await txn.insert('roles', {
          'id': role.id,
          'name': role.name,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    return appInfo;
  }

  Future<AppInformation> saveUserInfo({
    required AppInformation current,
    required UserInfo userInfo,
    required bool active,
    required String? deviceId,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final updated = current.copyWith(
      idMensajero: userInfo.messengerId.toString(),
      nombreMensajero: userInfo.fullName.trim().isEmpty
          ? current.nombreMensajero
          : userInfo.fullName,
      idTipoMensajero: userInfo.messengerTypeId.toString(),
      idDispositivo: deviceId ?? current.idDispositivo,
      loginDate: _formatHumanDate(now),
      loginDateCompact: _formatCompactDate(now),
      isLoginOnline: true,
    );

    await db.transaction((txn) async {
      await txn.insert(
        'app_information',
        updated.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update('credentials', {'active': active ? 1 : 0});
      await txn.insert('positions', {
        'id_mensajero': updated.idMensajero,
        'latitud': '0',
        'longitud': '0',
        'fecha_registro': '0',
        'localidad': updated.idCiudad,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return updated;
  }

  Future<void> saveDeviceId(String idDispositivo) async {
    if (idDispositivo.trim().isEmpty) return;
    final db = await database;
    final rows = await db.query('app_information', limit: 1);
    if (rows.isEmpty) return;
    final current = AppInformation.fromDb(rows.first);
    await db.insert(
      'app_information',
      current.copyWith(idDispositivo: idDispositivo).toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveFirebaseToken(String token) async {
    final db = await database;
    await db.insert('firebase_tokens', {
      'id': 1,
      'token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> currentFirebaseToken() async {
    final db = await database;
    final rows = await db.query('firebase_tokens', limit: 1);
    if (rows.isEmpty) return '';
    return _dbString(rows.first['token']);
  }

  Future<List<ModuleApp>> _loadModules(Database db) async {
    final rows = await db.query('modules_app', orderBy: 'sort_order ASC');
    return rows
        .map(
          (row) => ModuleApp(
            id: _dbInt(row['mod_id']),
            name: _dbString(row['name']),
            enabled: _dbBool(row['enabled']),
            visible: _dbBool(row['visible']),
            order: _dbInt(row['sort_order']),
            applicationId: _dbInt(row['application_id']),
            newDate: _dbString(row['new_date']),
            primary: _dbBool(row['primary_module']),
          ),
        )
        .toList();
  }

  Future<void> saveSchemasAndCreateTables(List<SyncSchema> schemas) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final schema in schemas) {
        if (schema.createQuery.trim().isNotEmpty) {
          try {
            await txn.execute(_createTableIfNeeded(schema));
          } on Object {
            // El Android nativo ignora errores puntuales de esquema y sigue.
          }
        }
        await txn.insert('sync_schemas', {
          'table_name': schema.tableName,
          'batch_size': schema.batchSize,
          'filter': schema.filter,
          'json': jsonEncode(schema.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<bool> hasTorreDirectionRegistry() async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM torre_direction_tables',
      );
      if (rows.isEmpty) return false;
      final total = rows.first['total'];
      if (total is int) return total > 0;
      if (total is num) return total > 0;
      return int.tryParse(total?.toString() ?? '') != 0;
    } on Object {
      return false;
    }
  }

  Future<void> saveTorreSchemasAndCreateTables(
    List<TorreDirectionSchema> schemas,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final schema in schemas) {
        if (schema.createQuery.trim().isNotEmpty) {
          try {
            await txn.execute(schema.createQuery);
          } on Object {
            // Android continua aunque una tabla de Torre falle al crearse.
          }
        }
        await txn.insert('torre_direction_tables', {
          'table_name': schema.tableName,
          'has_service_center_filter': schema.hasServiceCenterFilter ? 1 : 0,
          'json': jsonEncode(schema.toJson()),
          'updated_at': schema.updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<String>> torreDirectionTableNames() async {
    final db = await database;
    final rows = await db.query('torre_direction_tables');
    return rows
        .map((row) => _dbString(row['table_name']).trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<String> frameworkParameter(String code) async {
    try {
      final db = await database;
      final columns = await _columnsFor(db, 'ParametrosFramework');
      if (columns.isEmpty) return '';
      final codeColumns = [
        'Codigo',
        'PAR_IdParametro',
        'PAR_Codigo',
        'Nombre',
        'PFR_Nombre',
        'Parametro',
      ].where(columns.contains).toList();
      final valueColumns = [
        'Valor',
        'PAR_Valor',
        'PAR_ValorParametro',
        'PFR_Valor',
        'ValorParametro',
        'Descripcion',
      ].where(columns.contains).toList();
      if (codeColumns.isEmpty || valueColumns.isEmpty) return '';
      for (final codeColumn in codeColumns) {
        final rows = await db.query(
          'ParametrosFramework',
          columns: [valueColumns.first],
          where: '$codeColumn = ?',
          whereArgs: [code],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          return _dbString(rows.first[valueColumns.first]);
        }
      }
    } on Object {
      return '';
    }
    return '';
  }

  Future<void> executeSyncStatements(List<String> statements) async {
    if (statements.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final statement in statements) {
        if (statement.trim().isEmpty) continue;
        try {
          await txn.execute(statement);
        } on Object {
          // El flujo nativo tolera fallos puntuales por lote.
        }
      }
    });
  }

  Future<bool> tableHasRows(String tableName) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM $tableName',
      );
      if (rows.isEmpty) return false;
      final total = rows.first['total'];
      if (total is int) return total > 0;
      if (total is num) return total > 0;
      return int.tryParse(total?.toString() ?? '') != 0;
    } on Object {
      return false;
    }
  }

  Future<Set<String>> _columnsFor(Database db, String tableName) async {
    try {
      final rows = await db.rawQuery(
        'PRAGMA table_info("${tableName.replaceAll('"', '""')}")',
      );
      return rows.map((row) => _dbString(row['name'])).toSet();
    } on Object {
      return const {};
    }
  }

  Future<void> insertSyncFile({
    required File file,
    required String filterSuffix,
  }) async {
    final db = await database;
    var tableName = path
        .basename(file.path)
        .replaceFirst(RegExp(r'\.txt$', caseSensitive: false), '');
    if (filterSuffix.isNotEmpty) {
      tableName = tableName.replaceAll(filterSuffix, '').trim();
    }
    if (tableName.isEmpty) return;

    final insertPrefix = 'INSERT OR REPLACE INTO $tableName VALUES ';
    const batchSize = 1000;
    final record = StringBuffer();
    final values = StringBuffer();
    var currentBatch = 0;

    Future<void> flush(Transaction txn) async {
      if (values.isEmpty) return;
      try {
        await txn.execute('$insertPrefix$values');
      } on Object {
        // El Android nativo registra el error por lote y continua con la tabla.
      }
      values.clear();
      currentBatch = 0;
    }

    await db.transaction((txn) async {
      final lines = file
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      await for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        record.write(line);
        record.write(' ');
        if (!line.endsWith('),')) continue;

        var sqlRecord = record.toString().trim();
        sqlRecord = sqlRecord.substring(0, sqlRecord.length - 1);
        if (values.isNotEmpty) values.write(',');
        values.write(sqlRecord);
        record.clear();
        currentBatch++;

        if (currentBatch == batchSize) {
          await flush(txn);
        }
      }

      if (values.isNotEmpty) {
        await flush(txn);
      }

      if (record.isNotEmpty) {
        var sqlRecord = record.toString().trim();
        if (sqlRecord.endsWith('),')) {
          sqlRecord = sqlRecord.substring(0, sqlRecord.length - 1);
        }
        if (sqlRecord.endsWith(')')) {
          try {
            await txn.execute('$insertPrefix$sqlRecord');
          } on Object {
            // Mantiene el comportamiento tolerante de la sincronizacion nativa.
          }
        }
      }
    });
  }

  Future<void> executeSyncStatement(String statement) async {
    if (statement.trim().isEmpty) return;
    final db = await database;
    await db.execute(statement);
  }

  Future<String> maxAnchor(String tableName) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT MAX(Anchor) AS anchor FROM $tableName',
      );
      final value = rows.isEmpty ? null : rows.first['anchor'];
      final text = _dbString(value);
      if (text.isEmpty) return '_';
      return text.replaceAll('/', 'SLASH').replaceAll('+', 'SUMA');
    } on Object {
      return '_';
    }
  }

  Future<int> offlineHoursLimit() async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        "SELECT Valor FROM ParametrosFramework WHERE Codigo = 'HorasOffline' "
        "OR Nombre = 'HorasOffline' LIMIT 1",
      );
      if (rows.isEmpty) return 24;
      return int.tryParse(_dbString(rows.first.values.first)) ?? 24;
    } on Object {
      return 24;
    }
  }

  Future<void> saveSyncStatus(LocalSyncStatus status) async {
    final db = await database;
    await db.insert(
      'sync_status',
      status.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LocalSyncStatus?> currentSyncStatus() async {
    final db = await database;
    final rows = await db.query('sync_status', limit: 1);
    if (rows.isEmpty) return null;
    return LocalSyncStatus.fromDb(rows.first);
  }

  Future<void> markTableSynchronized(String tableName) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('TablasSincronizacion', {
      'NombreTabla': tableName,
      'FechaActualizacion': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert(
      'TablaSincronizacionSegmentada',
      {'Evento': 'Sincronizacion Segmentada', 'FechaActualizacion': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearActiveSession() async {
    final db = await database;
    await db.update('credentials', {'active': 0});
  }

  Future<void> _onCreate(Database db, int version) async {
    await _ensureSchema(db);
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_information (
  id INTEGER PRIMARY KEY,
  id_usuario TEXT,
  id_mensajero TEXT,
  nombre_mensajero TEXT,
  rol TEXT,
  id_caja TEXT,
  identificacion_usuario TEXT,
  nombre_centro_servicio TEXT,
  id_centro_servicio TEXT,
  nombre_usuario TEXT,
  id_ciudad TEXT,
  id_dispositivo TEXT,
  permisos_json TEXT,
  nombre_ciudad TEXT,
  id_tipo_mensajero TEXT,
  login_date TEXT,
  login_date_compact TEXT,
  environment_label TEXT,
  is_login_online INTEGER
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS credentials (
  username TEXT PRIMARY KEY,
  password_md5 TEXT,
  password_base64 TEXT,
  password_aes256 TEXT,
  session_json TEXT,
  active INTEGER,
  id_localidad_autorizada TEXT,
  nombre_localidad_autorizada TEXT,
  id_centro_servicio_autorizado TEXT,
  nombre_centro_servicio_autorizado TEXT,
  id_caja TEXT,
  updated_at TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS tokens (
  id INTEGER PRIMARY KEY,
  token_refresh TEXT,
  token TEXT,
  uuid_dispositivo TEXT,
  user_name TEXT,
  id_rol_apoyo_a_crear INTEGER
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS firebase_tokens (
  id INTEGER PRIMARY KEY,
  token TEXT,
  updated_at TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS modules_app (
  mod_id INTEGER PRIMARY KEY,
  name TEXT,
  enabled INTEGER,
  visible INTEGER,
  sort_order INTEGER,
  application_id INTEGER,
  new_date TEXT,
  primary_module INTEGER
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS roles (
  id INTEGER PRIMARY KEY,
  name TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS positions (
  id_mensajero TEXT PRIMARY KEY,
  latitud TEXT,
  longitud TEXT,
  fecha_registro TEXT,
  localidad TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS sync_schemas (
  table_name TEXT PRIMARY KEY,
  batch_size INTEGER,
  filter TEXT,
  json TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS torre_direction_tables (
  table_name TEXT PRIMARY KEY,
  has_service_center_filter INTEGER,
  json TEXT,
  updated_at TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS sync_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER,
  message TEXT,
  started_at TEXT,
  finished_at TEXT,
  tables INTEGER
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS TablasSincronizacion (
  NombreTabla TEXT PRIMARY KEY,
  FechaActualizacion TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS TablaSincronizacionSegmentada (
  Evento TEXT PRIMARY KEY,
  FechaActualizacion TEXT
)''');
  }

  String _createTableIfNeeded(SyncSchema schema) {
    var query = schema.createQuery;
    if (schema.tableName == 'ServicioMensajeria_TAR') {
      query = query.replaceAll('í', 'i').replaceAll('Í', 'I');
    }
    return query.replaceFirst(
      RegExp(r'CREATE\s+TABLE\b', caseSensitive: false),
      'CREATE TABLE IF NOT EXISTS',
    );
  }

  bool _isLoginExpired(String compactLoginDate) {
    final parsed = _parseCompactDate(compactLoginDate);
    if (parsed == null) return true;
    final nextMidnight = DateTime(parsed.year, parsed.month, parsed.day + 1);
    return DateTime.now().isAfter(nextMidnight);
  }
}
