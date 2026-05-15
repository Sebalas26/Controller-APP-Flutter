part of '../login_data.dart';

class PostLoginSuppliesSyncService {
  PostLoginSuppliesSyncService({Dio? dio}) : _dio = dio ?? Dio();

  static const _integrationUser =
      '9PG4iMLN2pRb4rOUA6I9BuImv44U1QrUsxOmzjRYPDPU27rw+CuowP9fem8Xoe1jjIuQqbVCgxMg4TdEU3Ts4g==';
  static const _integrationPassword =
      'HkdqzsVRIzK+7i5Hb62Wlt+cj3Py+fML4ULt7tyUvCUisJhzh/V8kU/TVpzRxL8G';

  final Dio _dio;

  Future<int> synchronize({
    required ControllerApiConfig config,
    required ControllerLocalDatabase localDatabase,
    required AppInformation appInformation,
    LoginProgress? onProgress,
  }) async {
    final db = await localDatabase.database;
    await _ensureSupplyTables(db);
    final target = await _configuredSupplyTarget(db);
    final current = await _availableSuppliesCount(db);
    final amount = math.max(0, target - current);
    if (amount <= 0) return current;

    onProgress?.call('Cargando suministros offline...');
    final auth = await _loginIntegration(config);
    final client = _plainClient(config.admisionOfflineBaseUrl);
    final response = await client.post<dynamic>(
      'suministros',
      data: {
        'idDispositivo': appInformation.idDispositivo,
        'idMensajero': int.tryParse(appInformation.idMensajero) ?? 0,
        'cantidadSuministros': amount,
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: _admissionOfflineHeaders(auth, appInformation),
      ),
    );
    final decoded = _decodePossiblyGzip(response.data);
    final json = jsonDecode(decoded);
    final list = _findList(json);
    if (list == null) {
      throw const LoginException('Respuesta invalida al cargar suministros.');
    }

    final supplies = list
        .whereType<Object?>()
        .map(_asMapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(_SupplyResponse.fromJson)
        .where((supply) => supply.guideNumber.trim().isNotEmpty)
        .toList();
    if (supplies.length != amount) {
      throw const LoginException(
        'La cantidad de suministros recibida no coincide con la solicitada.',
      );
    }

    await _insertSupplies(db, supplies);
    return _availableSuppliesCount(db);
  }

  Future<_IntegrationAuth> _loginIntegration(ControllerApiConfig config) async {
    final client = _plainClient(config.loginIntegrationBaseUrl);
    final response = await client.post<dynamic>(
      'Autenticacion/Login',
      data: {'UserName': _integrationUser, 'Password': _integrationPassword},
    );
    final json = _asMap(response.data);
    final token = _findString(json, const ['Token', 'token']);
    final userName = _findString(json, const ['UserName', 'userName']);
    if (token.trim().isEmpty || userName.trim().isEmpty) {
      throw const LoginException(
        'No fue posible autenticar LoginIntegracion para suministros.',
      );
    }
    return _IntegrationAuth(token: token, userName: userName);
  }

  Dio _plainClient(String baseUrl) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final client = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    client.httpClientAdapter = _dio.httpClientAdapter;
    return client;
  }

  Map<String, Object> _admissionOfflineHeaders(
    _IntegrationAuth auth,
    AppInformation appInformation,
  ) {
    return {
      'UserName': auth.userName,
      'Token': auth.token,
      'Usuario': appInformation.idUsuario,
      'IdUsuario': appInformation.idUsuario,
      'IdCentroServicio': appInformation.idCentroServicio,
      'NombreCentroServicio': _sanitizeHeaderValue(
        appInformation.nombreCentroServicio,
      ),
      'IdAplicativoOrigen': '9',
      'Identificacion': appInformation.identificacionUsuario,
      'Content-Type': 'application/json',
      'Accept': 'text/json',
    };
  }

  Future<void> _ensureSupplyTables(DatabaseExecutor db) async {
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

  Future<int> _configuredSupplyTarget(Database db) async {
    final framework = await _frameworkParameter(db, 'CantidadSuministros');
    final frameworkValue = int.tryParse(framework.trim()) ?? 0;
    if (frameworkValue > 0) return frameworkValue;

    final maxGuides = await _admissionParameter(db, 'MaximoGuiasOffLine');
    final maxGuidesValue = int.tryParse(maxGuides.trim()) ?? 0;
    if (maxGuidesValue > 0) return maxGuidesValue;

    return 200;
  }

  Future<String> _frameworkParameter(Database db, String code) async {
    if (!await _tableExists(db, 'ParametrosFramework')) return '';
    final columns = await _columnsFor(db, 'ParametrosFramework');
    final codeColumns = [
      'PAR_IdParametro',
      'Codigo',
      'PAR_Codigo',
      'Nombre',
      'PFR_Nombre',
      'Parametro',
    ].where(columns.contains).toList();
    final valueColumns = [
      'PAR_ValorParametro',
      'Valor',
      'PAR_Valor',
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
      if (rows.isNotEmpty) return _stringValue(rows.first[valueColumns.first]);
    }
    return '';
  }

  Future<String> _admissionParameter(Database db, String code) async {
    if (!await _tableExists(db, 'ParametrosAdmisiones_MEN')) return '';
    final columns = await _columnsFor(db, 'ParametrosAdmisiones_MEN');
    if (!columns.contains('PAM_IdParametro') ||
        !columns.contains('PAM_ValorParametro')) {
      return '';
    }
    final rows = await db.query(
      'ParametrosAdmisiones_MEN',
      columns: const ['PAM_ValorParametro'],
      where: 'PAM_IdParametro = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return _stringValue(rows.first['PAM_ValorParametro']);
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

  Future<void> _insertSupplies(
    Database db,
    List<_SupplyResponse> supplies,
  ) async {
    final now = _sqliteDateTime(DateTime.now());
    await db.transaction((txn) async {
      for (final supply in supplies) {
        final guide = supply.guideNumber.trim();
        if (guide.isEmpty) continue;
        await txn.insert('SuministrosAdmision', {
          'numero': int.tryParse(guide) ?? guide,
          'fechaSincronizacion': now,
          'fechaVencimiento': _normalizeSupplyExpiration(supply.expirationDate),
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

  String _decodePossiblyGzip(dynamic data) {
    final bytes = data is List<int> ? data : utf8.encode(data.toString());
    try {
      return utf8.decode(GZipCodec().decode(bytes));
    } on Object {
      return utf8.decode(bytes);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    final map = _asMapOrNull(data);
    if (map != null) return map;
    throw const LoginException('Respuesta remota invalida en suministros.');
  }

  Map<String, dynamic>? _asMapOrNull(dynamic data) {
    final decoded = data is String && data.trim().isNotEmpty
        ? jsonDecode(data)
        : data;
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  String _findString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key].toString();
      }
    }
    for (final value in json.values) {
      if (value is Map<String, dynamic>) {
        final found = _findString(value, keys);
        if (found.trim().isNotEmpty) return found;
      } else if (value is Map) {
        final found = _findString(Map<String, dynamic>.from(value), keys);
        if (found.trim().isNotEmpty) return found;
      }
    }
    return '';
  }

  List<dynamic>? _findList(dynamic json) {
    if (json is List) return json;
    if (json is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'Data',
        'suministros',
        'Suministros',
        'result',
        'Result',
        'response',
        'Response',
      ]) {
        final value = json[key];
        final list = _findList(value);
        if (list != null) return list;
      }
      for (final value in json.values) {
        final list = _findList(value);
        if (list != null) return list;
      }
    } else if (json is Map) {
      return _findList(Map<String, dynamic>.from(json));
    }
    return null;
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

  String _sanitizeHeaderValue(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final isControl = codeUnit <= 0x1f && codeUnit != 0x09;
      if (!isControl && codeUnit < 0x7f) buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  String _identifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _stringValue(Object? value) => value == null ? '' : value.toString();
}

class _IntegrationAuth {
  const _IntegrationAuth({required this.token, required this.userName});

  final String token;
  final String userName;
}

class _SupplyResponse {
  const _SupplyResponse({
    required this.guideNumber,
    required this.expirationDate,
  });

  final String guideNumber;
  final String expirationDate;

  factory _SupplyResponse.fromJson(Map<String, dynamic> json) {
    return _SupplyResponse(
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
    );
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value.toString();
    }
    return '';
  }
}
