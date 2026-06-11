import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/asignacion_guias_models.dart';

class AsignacionGuiasLocalRepository {
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<void> ensureSchema() async {
    final db = await _openDatabase();
    await _ensureTables(db);
  }

  Future<AsignacionAccessTokens> loadAccessTokens() async {
    final db = await _openDatabase();
    final rows = await db.query('tokens', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      throw const AsignacionGuiasException(
        'No se encontraron credenciales del servicio.',
      );
    }
    final tokens = AsignacionAccessTokens(
      tokenRefresh: _dbString(rows.first['token_refresh']),
      token: _dbString(rows.first['token']),
      userName: _dbString(rows.first['user_name']),
    );
    if (!tokens.isValid) {
      throw const AsignacionGuiasException(
        'No se encontraron credenciales del servicio.',
      );
    }
    return tokens;
  }

  Future<int> maxGuiasAsignar() async {
    final value = await frameworkParameter('CantMaxEnviosPorLote');
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

  Future<List<AsignacionGuideState>> loadPendingGuides() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'asignacion_guias_pending',
      orderBy: 'updated_at DESC',
    );
    return rows
        .map(
          (row) => AsignacionGuideState.fromJson(
            asignacionAsMap(_dbString(row['guia_json'])),
          ),
        )
        .toList(growable: false);
  }

  Future<void> savePendingGuide(AsignacionGuideState guide) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.insert('asignacion_guias_pending', {
      'numero_guia': guide.numeroGuia,
      'guia_json': jsonEncode(guide.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replacePendingGuides(List<AsignacionGuideState> guides) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('asignacion_guias_pending');
      for (final guide in guides) {
        await txn.insert('asignacion_guias_pending', {
          'numero_guia': guide.numeroGuia,
          'guia_json': jsonEncode(guide.toJson()),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deletePendingGuide(int numeroGuia) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.delete(
      'asignacion_guias_pending',
      where: 'numero_guia = ?',
      whereArgs: [numeroGuia],
    );
  }

  Future<void> clearPendingGuides() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.delete('asignacion_guias_pending');
  }

  Future<void> savePreviousSheetsAndMessengers({
    required PreviousSheets sheets,
    required List<AsignacionMessenger> messengers,
  }) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.insert('asignacion_guias_previas', {
      'id': 1,
      'planillas_json': jsonEncode(sheets.toJson()),
      'apoyos_json': jsonEncode(
        messengers.map((item) => item.toJson()).toList(),
      ),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PreviousSheets> loadPreviousSheets() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'asignacion_guias_previas',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return PreviousSheets.empty();
    return PreviousSheets.fromJson(
      asignacionAsMap(_dbString(rows.first['planillas_json'])),
    );
  }

  Future<List<AsignacionMessenger>> loadPreviousMessengers() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'asignacion_guias_previas',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    return asignacionAsMapList(
      _dbString(rows.first['apoyos_json']),
    ).map(AsignacionMessenger.fromJson).toList(growable: false);
  }

  Future<void> clearPreviousSheets() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.delete('asignacion_guias_previas');
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
CREATE TABLE IF NOT EXISTS asignacion_guias_pending (
  numero_guia INTEGER PRIMARY KEY,
  guia_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS asignacion_guias_previas (
  id INTEGER PRIMARY KEY,
  planillas_json TEXT NOT NULL,
  apoyos_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  String _dbString(Object? value) => value?.toString() ?? '';
}
