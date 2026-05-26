import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/print_label_models.dart';

class VenderPrintLocalRepository {
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<void> ensureSchema() async {
    final db = await _openDatabase();
    await db.execute('''
CREATE TABLE IF NOT EXISTS ImpresionAdmision_MEN (
  NumeroGuia_IMP TEXT,
  ObjetoImpresion_IMP TEXT
)
''');
  }

  Future<void> saveLatestPrintPayload({
    required String guideNumber,
    required String payloadJson,
  }) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty || payloadJson.trim().isEmpty) return;
    final db = await _openDatabase();
    await ensureSchema();
    await db.transaction((txn) async {
      await txn.delete('ImpresionAdmision_MEN');
      await txn.insert('ImpresionAdmision_MEN', {
        'NumeroGuia_IMP': guide,
        'ObjetoImpresion_IMP': payloadJson,
      });
    });
  }

  Future<VenderPrintLabel?> latestLabel() async {
    await ensureSchema();
    final db = await _openDatabase();
    final rows = await db.query(
      'ImpresionAdmision_MEN',
      columns: const ['ObjetoImpresion_IMP'],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _labelFromJson(rows.first['ObjetoImpresion_IMP']);
  }

  Future<VenderPrintLabel?> labelByGuide(String guideNumber) async {
    final guide = guideNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (guide.isEmpty) return null;
    await ensureSchema();
    final db = await _openDatabase();
    final latest = await db.query(
      'ImpresionAdmision_MEN',
      columns: const ['ObjetoImpresion_IMP'],
      where: 'NumeroGuia_IMP = ?',
      whereArgs: [guide],
      limit: 1,
    );
    if (latest.isNotEmpty) {
      return _labelFromJson(latest.first['ObjetoImpresion_IMP']);
    }
    if (!await _tableExists(db, 'AdmisionMensajeriaOffLine')) return null;
    final offline = await db.query(
      'AdmisionMensajeriaOffLine',
      columns: const ['ObjetoADGuiaImpresion'],
      where: 'NumeroGuia = ?',
      whereArgs: [guide],
      orderBy: 'IdAdmisionOffline DESC',
      limit: 1,
    );
    if (offline.isEmpty) return null;
    return _labelFromJson(offline.first['ObjetoADGuiaImpresion']);
  }

  VenderPrintLabel? _labelFromJson(Object? value) {
    final text = value?.toString() ?? '';
    if (text.trim().isEmpty) return null;
    try {
      return VenderPrintLabel.fromJsonString(text);
    } on Object {
      return null;
    }
  }

  String payloadFromLabel(VenderPrintLabel label) {
    return jsonEncode(label.toJson());
  }

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }
}
