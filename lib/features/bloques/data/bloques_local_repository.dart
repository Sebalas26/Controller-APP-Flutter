import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/bloques_models.dart';

class BloquesLocalRepository {
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<void> ensureSchema() async {
    final db = await _openDatabase();
    await _ensureTables(db);
  }

  Future<YaapCourier?> loadCourier() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'yaap_courier_cache',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return YaapCourier.fromJson(_decodeMap(rows.first['courier_json']));
  }

  Future<void> saveCourier(YaapCourier courier) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.insert('yaap_courier_cache', {
      'documento': courier.document,
      'courier_json': jsonEncode(courier.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<YaapDelivery>> loadDeliveries() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'yaap_deliveries_cache',
      orderBy: 'numero_guia ASC',
    );
    return rows
        .map((row) => YaapDelivery.fromJson(_decodeMap(row['delivery_json'])))
        .toList(growable: false);
  }

  Future<void> saveDeliveries(List<YaapDelivery> deliveries) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('yaap_deliveries_cache');
      for (final delivery in deliveries) {
        if (delivery.guideNumber.trim().isEmpty) continue;
        await txn.insert('yaap_deliveries_cache', {
          'numero_guia': delivery.guideNumber,
          'delivery_json': jsonEncode(delivery.toJson()),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<YaapPendingBlock>> loadPendingBlocks() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'yaap_pending_blocks_cache',
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => YaapPendingBlock.fromJson(_decodeMap(row['block_json'])))
        .toList(growable: false);
  }

  Future<void> savePendingBlocks(List<YaapPendingBlock> blocks) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('yaap_pending_blocks_cache');
      for (final block in blocks) {
        if (block.motherGuideNumber.trim().isEmpty) continue;
        await txn.insert(
          'yaap_pending_blocks_cache',
          {
            'numero_guia_madre': block.motherGuideNumber,
            'block_json': jsonEncode(block.toJson()),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS yaap_courier_cache (
  documento TEXT PRIMARY KEY,
  courier_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS yaap_deliveries_cache (
  numero_guia TEXT PRIMARY KEY,
  delivery_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS yaap_pending_blocks_cache (
  numero_guia_madre TEXT PRIMARY KEY,
  block_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  Map<String, dynamic> _decodeMap(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, val) => MapEntry(key.toString(), val));
      }
    }
    return const {};
  }
}
