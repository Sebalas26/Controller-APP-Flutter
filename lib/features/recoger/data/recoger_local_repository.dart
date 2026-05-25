import 'package:sqflite/sqflite.dart';

import '../../login/login.dart';
import '../models/recoger_models.dart';

class RecogerLocalRepository {
  RecogerLocalRepository({ControllerLocalDatabase? localDatabase})
    : _localDatabase = localDatabase ?? ControllerLocalDatabase();

  final ControllerLocalDatabase _localDatabase;

  Future<Database> get _db async {
    final db = await _localDatabase.database;
    await _ensureSchema(db);
    return db;
  }

  Future<List<RecogidaItem>> fixedPickups() async {
    final db = await _db;
    final rows = await db.query('recogidas_fijas', orderBy: 'id_recogida DESC');
    return rows.map((row) {
      final raw = recogidaDecodeJson(row['json']?.toString() ?? '');
      return RecogidaItem.fromJson(
        raw,
        status: int.tryParse(row['estado']?.toString() ?? '') ?? 0,
      );
    }).toList();
  }

  Future<void> saveFixedPickups(List<RecogidaItem> pickups) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final pickup in pickups.where((item) => item.isFixedPickup)) {
        final previous = await txn.query(
          'recogidas_fijas',
          columns: ['estado'],
          where: 'id_recogida = ?',
          whereArgs: [pickup.id],
          limit: 1,
        );
        await txn.insert('recogidas_fijas', {
          'id_recogida': pickup.id,
          'json': recogidaEncodeJson(pickup.raw),
          'estado': previous.isEmpty ? pickup.status : previous.first['estado'],
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> markReserved(RecogidaItem pickup) async {
    final db = await _db;
    await db.insert('recogidas_fijas', {
      'id_recogida': pickup.id,
      'json': recogidaEncodeJson(pickup.raw),
      'estado': 1,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RecogidaItem>> offlineEffectivePickups() async {
    final db = await _db;
    final rows = await db.query(
      'recogidas_offline',
      where: 'estado_cerrado = 1 AND sincronizado = 0',
      orderBy: 'fecha_grabacion DESC',
    );
    return rows.map((row) {
      final raw = recogidaDecodeJson(row['json']?.toString() ?? '');
      return RecogidaItem.fromJson(raw.isEmpty ? _offlineRaw(row) : raw);
    }).toList();
  }

  Future<void> cacheEffectivePickups(
    List<RecogidaItem> pickups, {
    required bool online,
  }) async {
    final db = await _db;
    final source = online ? 'online' : 'offline';
    await db.transaction((txn) async {
      await txn.delete(
        'recogidas_efectivas_cache',
        where: 'source = ?',
        whereArgs: [source],
      );
      for (final pickup in pickups) {
        await txn.insert('recogidas_efectivas_cache', {
          'id_recogida': pickup.id,
          'source': source,
          'json': recogidaEncodeJson(pickup.raw),
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<RecogidaItem>> cachedEffectivePickups() async {
    final db = await _db;
    final rows = await db.query(
      'recogidas_efectivas_cache',
      orderBy: 'updated_at DESC',
    );
    final cached = rows
        .map((row) => RecogidaItem.fromJson(
              recogidaDecodeJson(row['json']?.toString() ?? ''),
            ))
        .toList();
    final offline = await offlineEffectivePickups();
    return _distinctById([...offline, ...cached]);
  }

  Future<List<RecogidaPreenvio>> cachedPreguides(String pickupId) async {
    final db = await _db;
    final rows = await db.query(
      'recogida_preenvios',
      where: 'id_recogida = ?',
      whereArgs: [pickupId],
      orderBy: 'id_preenvio DESC',
    );
    return rows.map((row) {
      return RecogidaPreenvio.fromJson(
        recogidaDecodeJson(row['json']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<void> cachePreguides(
    String pickupId,
    List<RecogidaPreenvio> preguides,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'recogida_preenvios',
        where: 'id_recogida = ?',
        whereArgs: [pickupId],
      );
      for (final preguide in preguides) {
        await txn.insert('recogida_preenvios', {
          'id_preenvio': preguide.id.isEmpty
              ? preguide.guideNumber
              : preguide.id,
          'id_recogida': pickupId,
          'json': recogidaEncodeJson(preguide.raw),
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveMotivos(List<RecogidaMotivo> motives) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final motive in motives) {
        await txn.insert('recogidas_motivos_estado', {
          'id_motivo': motive.id,
          'descripcion': motive.description,
          'json': recogidaEncodeJson(motive.raw),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS recogidas_fijas (
  id_recogida TEXT PRIMARY KEY,
  json TEXT NOT NULL,
  estado INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS recogidas_efectivas_cache (
  id_recogida TEXT NOT NULL,
  source TEXT NOT NULL,
  json TEXT NOT NULL,
  updated_at TEXT,
  PRIMARY KEY (id_recogida, source)
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS recogida_preenvios (
  id_preenvio TEXT PRIMARY KEY,
  id_recogida TEXT NOT NULL,
  json TEXT NOT NULL,
  updated_at TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS recogidas_motivos_estado (
  id_motivo INTEGER PRIMARY KEY,
  descripcion TEXT,
  json TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS recogidas_offline (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_recogida TEXT,
  json TEXT,
  estado_cerrado INTEGER NOT NULL DEFAULT 0,
  sincronizado INTEGER NOT NULL DEFAULT 0,
  fecha_grabacion TEXT
)''');
  }

  Map<String, dynamic> _offlineRaw(Map<String, Object?> row) {
    return {
      'Id': row['id_recogida']?.toString() ?? row['id']?.toString() ?? '',
      'TipoRecogida': 2,
      'PreguntarPor': 'Recogida offline',
      'Direccion': '',
      'DescripcionEnvios': 'Pendiente por sincronizar',
      'FechaRecogida': row['fecha_grabacion']?.toString() ?? '',
      'icon': 'unsincronized',
    };
  }

  List<RecogidaItem> _distinctById(List<RecogidaItem> source) {
    final result = <RecogidaItem>[];
    final seen = <String>{};
    for (final item in source) {
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }
}
