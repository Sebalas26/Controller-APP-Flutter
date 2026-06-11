import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/mis_mensajeros_models.dart';

class MisMensajerosLocalRepository {
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<void> ensureSchema() async {
    final db = await _openDatabase();
    await _ensureTables(db);
  }

  Future<MisMensajerosTokens> loadTokens() async {
    final db = await _openDatabase();
    final rows = await db.query('tokens', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      throw const MisMensajerosException(
        'No se encontraron credenciales del servicio.',
      );
    }
    final tokens = MisMensajerosTokens(
      tokenRefresh: _dbString(rows.first['token_refresh']),
      token: _dbString(rows.first['token']),
      userName: _dbString(rows.first['user_name']),
      idRolApoyo: _dbInt(rows.first['id_rol_apoyo_a_crear']),
    );
    if (!tokens.isValid) {
      throw const MisMensajerosException(
        'No se encontraron credenciales del servicio.',
      );
    }
    return tokens;
  }

  Future<int> roleIdByName(String roleName) async {
    final name = roleName.trim();
    if (name.isEmpty) return 0;
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'roles',
        columns: ['id'],
        where: 'LOWER(name) = LOWER(?)',
        whereArgs: [name],
        limit: 1,
      );
      if (rows.isNotEmpty) return _dbInt(rows.first['id']);
    } on Object {
      return 0;
    }
    return 0;
  }

  Future<int> maxSupports() async {
    final value = await frameworkParameter('MaximoMensajerosPermitidos');
    return int.tryParse(value.trim()) ?? 100;
  }

  Future<int> maxActiveSupports() async {
    final value = await frameworkParameter('MaxUsuariosActMisMensajeros');
    return int.tryParse(value.trim()) ?? 20;
  }

  Future<String> frameworkParameter(String code) async {
    try {
      final db = await _openDatabase();
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
        if (rows.isNotEmpty) return _dbString(rows.first[valueColumns.first]);
      }
    } on Object {
      return '';
    }
    return '';
  }

  Future<List<MisMensajero>> loadCachedSupports() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'mis_mensajeros_cache',
      orderBy: 'usuario_activo DESC, nombre ASC',
    );
    return rows
        .map(
          (row) => MisMensajero.fromJson(
            misMensajerosAsMap(_dbString(row['apoyo_json'])),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveCachedSupports(List<MisMensajero> supports) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('mis_mensajeros_cache');
      for (final support in supports) {
        await txn.insert('mis_mensajeros_cache', {
          'id_mensajero': support.idMensajero,
          'identificacion': support.identificacion,
          'nombre': support.nombre,
          'usuario_activo': support.usuarioActivo ? 1 : 0,
          'apoyo_json': jsonEncode(support.toJson()),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
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

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS mis_mensajeros_cache (
  id_mensajero INTEGER PRIMARY KEY,
  identificacion TEXT,
  nombre TEXT,
  usuario_activo INTEGER,
  apoyo_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  int _dbInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _dbString(Object? value) => value?.toString() ?? '';
}
