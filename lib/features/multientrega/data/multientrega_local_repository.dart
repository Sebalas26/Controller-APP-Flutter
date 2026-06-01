import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../entregas/entregas.dart';
import '../models/multientrega_models.dart';

class MultientregaLocalRepository {
  MultientregaLocalRepository({EntregasLocalRepository? entregasRepository})
    : entregasRepository = entregasRepository ?? EntregasLocalRepository();

  final EntregasLocalRepository entregasRepository;

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<void> ensureSchema() async {
    await entregasRepository.ensureSchema();
    final db = await _openDatabase();
    await _ensureTables(db);
  }

  Future<int> maxGuides() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final value = await _frameworkParameter(db, 'MaxMultiEntrega');
    return int.tryParse(value) ?? 50;
  }

  Future<List<MultientregaGuide>> loadPendingGuides() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'multientrega_items',
      where: 'finalizada = 0',
      orderBy: 'created_at DESC',
    );
    final guides = <String, MultientregaGuide>{};
    for (final row in rows) {
      final guide = EntregaGuide.fromJson(_decodeMap(row['guide_json']));
      if (guide.guideNumber.trim().isEmpty) continue;
      guides[guide.guideNumber] = MultientregaGuide(
        guide: guide,
        photoBase64: _stringValue(row['imagen_evidencia']),
        requiresSeal: _intValue(row['es_sello']) == 1,
        createdAt:
            DateTime.tryParse(_stringValue(row['created_at'])) ??
            DateTime.now(),
      );
    }
    await _mergeNativePending(db, guides);
    return guides.values.toList(growable: false);
  }

  Future<EntregaGuide?> findGuide(String guideNumber) {
    return entregasRepository.findGuide(guideNumber, pendingOnly: true);
  }

  Future<bool> isAlreadyDownloaded(String guideNumber) {
    return entregasRepository.isGuideAlreadyDownloaded(guideNumber);
  }

  Future<bool> isAlreadyInProcess(String guideNumber) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.rawQuery(
      '''
SELECT 1 FROM multientrega_items WHERE numero_guia = ? AND finalizada = 0
UNION
SELECT 1 FROM AsociacionMultientrega_LO WHERE numeroGuia = ? AND Finalizada = '0'
LIMIT 1
''',
      [guideNumber, guideNumber],
    );
    return rows.isNotEmpty;
  }

  Future<void> saveGuide(MultientregaGuide item) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final idFirma = await _activeSignatureId(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('multientrega_items', {
        'numero_guia': item.guideNumber,
        'guide_json': jsonEncode(item.guide.toJson()),
        'imagen_evidencia': item.photoBase64,
        'es_sello': item.requiresSeal ? 1 : 0,
        'finalizada': 0,
        'id_firma': idFirma,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'AsociacionMultientrega_LO',
        where: 'numeroGuia = ? AND Finalizada = ?',
        whereArgs: [item.guideNumber, '0'],
      );
      await txn.insert('AsociacionMultientrega_LO', {
        'numeroGuia': item.guideNumber,
        'Finalizada': '0',
        'FechaCreacion': _sqliteDateTime(DateTime.now()),
        'ImagenEvidencia': item.photoBase64,
        'EsSello': item.requiresSeal ? '1' : '0',
        'IdFirma': idFirma,
      });
    });
  }

  Future<void> updateGuidePhoto(String guideNumber, String photoBase64) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty) return;
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'multientrega_items',
        {'imagen_evidencia': photoBase64, 'updated_at': now},
        where: 'numero_guia = ? AND finalizada = 0',
        whereArgs: [guide],
      );
      await txn.update(
        'AsociacionMultientrega_LO',
        {'ImagenEvidencia': photoBase64},
        where: 'numeroGuia = ? AND Finalizada = ?',
        whereArgs: [guide, '0'],
      );
    });
  }

  Future<void> deleteGuide(String guideNumber) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty) return;
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.transaction((txn) async {
      await txn.delete(
        'multientrega_items',
        where: 'numero_guia = ? AND finalizada = 0',
        whereArgs: [guide],
      );
      await txn.delete(
        'AsociacionMultientrega_LO',
        where: 'numeroGuia = ? AND Finalizada = ?',
        whereArgs: [guide, '0'],
      );
      await _deleteDownloadRows(txn, guide);
    });
    await _deleteOrphanSignature(db);
  }

  Future<void> clearPending() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'multientrega_items',
      columns: ['numero_guia'],
      where: 'finalizada = 0',
    );
    await db.transaction((txn) async {
      for (final row in rows) {
        await _deleteDownloadRows(txn, _stringValue(row['numero_guia']));
      }
      await txn.delete('multientrega_items', where: 'finalizada = 0');
      await txn.delete(
        'AsociacionMultientrega_LO',
        where: 'Finalizada = ?',
        whereArgs: ['0'],
      );
      await txn.delete('AsociacionFirmaSelloMultiEntrega_LO');
    });
  }

  Future<int> activeSignatureId() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    return _activeSignatureId(db);
  }

  Future<void> saveSignatureData({
    required int signatureId,
    required MultientregaReceiverData receiver,
    required String signatureBase64,
    required String sealBase64,
  }) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final data = jsonEncode(receiver.toJson());
    await db.update(
      'AsociacionFirmaSelloMultiEntrega_LO',
      {
        'imagenFirma': signatureBase64,
        'imagenSello': sealBase64,
        'datosRecibe': data,
      },
      where: '_id = ?',
      whereArgs: [signatureId],
    );
  }

  Future<EntregaPendingDownload> savePendingDownload({
    required EntregaGuide guide,
    required Map<String, dynamic> payload,
    required bool isQr,
  }) {
    return entregasRepository.savePendingDownload(
      guide: guide,
      type: EntregaDownloadType.entregaCorrectaMensajero,
      payload: payload,
      isQr: isQr,
    );
  }

  Future<void> markDownloadSynced(
    EntregaPendingDownload download,
    EntregaSyncResult result,
  ) {
    return entregasRepository.markDownloadSynced(download, result);
  }

  Future<void> markDownloadFailed(
    EntregaPendingDownload download,
    Object error,
  ) {
    return entregasRepository.markDownloadFailed(download, error);
  }

  Future<void> markGuidesFinalized(Iterable<String> guideNumbers) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final rawGuide in guideNumbers) {
        final guide = rawGuide.trim();
        if (guide.isEmpty) continue;
        await txn.update(
          'multientrega_items',
          {'finalizada': 1, 'updated_at': now},
          where: 'numero_guia = ?',
          whereArgs: [guide],
        );
        await txn.update(
          'AsociacionMultientrega_LO',
          {'Finalizada': '1'},
          where: 'numeroGuia = ?',
          whereArgs: [guide],
        );
      }
    });
  }

  Future<void> _ensureTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS AsociacionFirmaSelloMultiEntrega_LO (
  _id INTEGER PRIMARY KEY AUTOINCREMENT,
  imagenFirma TEXT,
  datosRecibe TEXT,
  imagenSello TEXT
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS AsociacionMultientrega_LO (
  numeroGuia TEXT,
  Finalizada TEXT,
  FechaCreacion TEXT,
  ImagenEvidencia TEXT,
  EsSello TEXT,
  IdFirma INTEGER
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS multientrega_items (
  numero_guia TEXT PRIMARY KEY,
  guide_json TEXT NOT NULL,
  imagen_evidencia TEXT,
  es_sello INTEGER NOT NULL DEFAULT 0,
  finalizada INTEGER NOT NULL DEFAULT 0,
  id_firma INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  Future<int> _activeSignatureId(Database db) async {
    final rows = await db.query(
      'multientrega_items',
      columns: ['id_firma'],
      where: 'finalizada = 0',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final id = _intValue(rows.first['id_firma']);
      if (id > 0) return id;
    }
    final id = await db.insert('AsociacionFirmaSelloMultiEntrega_LO', {
      'imagenFirma': '',
      'datosRecibe': '',
      'imagenSello': '',
    });
    return id;
  }

  Future<void> _mergeNativePending(
    Database db,
    Map<String, MultientregaGuide> guides,
  ) async {
    try {
      final rows = await db.rawQuery('''
SELECT A.numeroGuia,
       A.ImagenEvidencia,
       A.EsSello,
       A.FechaCreacion,
       D.DEO_ObjetoCompleto
FROM AsociacionMultientrega_LO A
INNER JOIN DescargueOffline_LO D ON A.numeroGuia = D.DEO_NumeroGuia
WHERE A.Finalizada = '0'
ORDER BY A.FechaCreacion DESC
''');
      for (final row in rows) {
        final guide = EntregaGuide.fromJson(
          _decodeMap(row['DEO_ObjetoCompleto']),
        );
        if (guide.guideNumber.trim().isEmpty ||
            guides.containsKey(guide.guideNumber)) {
          continue;
        }
        guides[guide.guideNumber] = MultientregaGuide(
          guide: guide,
          photoBase64: _stringValue(row['ImagenEvidencia']),
          requiresSeal: _stringValue(row['EsSello']) == '1',
          createdAt:
              DateTime.tryParse(_stringValue(row['FechaCreacion'])) ??
              DateTime.now(),
        );
      }
    } on Object {
      return;
    }
  }

  Future<String> _frameworkParameter(Database db, String code) async {
    try {
      final rows = await db.rawQuery(
        "SELECT Valor FROM ParametrosFramework WHERE Codigo = ? OR Nombre = ? LIMIT 1",
        [code, code],
      );
      if (rows.isEmpty) return '';
      return _stringValue(rows.first.values.first);
    } on Object {
      return '';
    }
  }

  Future<void> _deleteDownloadRows(DatabaseExecutor db, String guide) async {
    if (guide.isEmpty) return;
    await db.delete(
      'entregas_descargues_offline',
      where: 'numero_guia = ?',
      whereArgs: [guide],
    );
    await db.delete(
      'DescargueOffline_LO',
      where: 'DEO_NumeroGuia = ?',
      whereArgs: [guide],
    );
    await db.delete(
      'DescargueAWS',
      where: 'DEO_NumeroGuia = ?',
      whereArgs: [guide],
    );
  }

  Future<void> _deleteOrphanSignature(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM multientrega_items WHERE finalizada = 0',
    );
    if (_intValue(rows.first['total']) == 0) {
      await db.delete('AsociacionFirmaSelloMultiEntrega_LO');
    }
  }

  Map<String, dynamic> _decodeMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  String _sqliteDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_stringValue(value).trim()) ?? 0;
  }

  String _stringValue(Object? value) => value?.toString() ?? '';
}
