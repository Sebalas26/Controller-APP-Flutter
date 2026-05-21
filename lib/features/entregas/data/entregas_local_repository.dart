import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/entregas_models.dart';

class EntregasLocalRepository {
  static const _estadoNoSincronizado = 0;
  static const _estadoSincronizado = 1;
  static const _estadoEntregada = 13;
  static const _estadoDevolucion = 7;

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(path.join(dbPath, 'controller_app_flutter.db'));
  }

  Future<void> ensureSchema() async {
    final db = await _openDatabase();
    await _ensureTables(db);
  }

  Future<List<EntregaGuide>> loadGuides(EntregaGuideStatus status) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'entregas_guias_cache',
      where: 'status = ?',
      whereArgs: [status.value],
      orderBy: 'updated_at DESC',
    );
    final guides = <String, EntregaGuide>{};
    for (final row in rows) {
      final guide = EntregaGuide.fromJson(_decodeMap(row['guide_json']));
      if (guide.guideNumber.trim().isNotEmpty) {
        guides[guide.guideNumber] = guide;
      }
    }
    await _mergeNativeGuides(db, status, guides);
    return guides.values.toList();
  }

  Future<EntregaGuide?> findGuide(String guideNumber) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty) return null;
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'entregas_guias_cache',
      where: 'numero_guia = ?',
      whereArgs: [guide],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EntregaGuide.fromJson(_decodeMap(rows.first['guide_json']));
  }

  Future<void> saveGuides(
    List<EntregaGuide> guides,
    EntregaGuideStatus status,
  ) async {
    if (guides.isEmpty) return;
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final guide in guides) {
        if (guide.guideNumber.trim().isEmpty) continue;
        await txn.insert('entregas_guias_cache', {
          'numero_guia': guide.guideNumber,
          'status': status.value,
          'guide_json': jsonEncode(guide.toJson()),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        if (status == EntregaGuideStatus.enZona) {
          await txn.delete(
            'GuiasPlanilladas_LO',
            where: 'GP_NumeroGuia = ?',
            whereArgs: [guide.guideNumber],
          );
          await txn.insert('GuiasPlanilladas_LO', {
            'GP_NumeroGuia': guide.guideNumber,
            'GP_Objeto': jsonEncode(guide.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<List<EntregaReason>> loadReasons() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query('DevolucionMotivoGuia_LOI');
    return rows.map((row) {
      return EntregaReason.fromJson({
        'IdMotivoGuia': _stringValue(row['MD_IdMotivo']),
        'DescripcionAPP': _stringValue(row['MD_Descripcion']),
        'EsEscaneo': _stringValue(row['MD_EsEscaneo']),
        'ObservacionMotivo': _stringValue(row['MD_ObservacionesMotivo']),
        'CapturaPredio': _stringValue(row['MD_CapturaPredio']),
        'CapturaContador': _stringValue(row['MD_CapturaContador']),
        'CapturaObservacion': _stringValue(row['MD_CapturaObservacion']),
        'TiempoAfectacion': _stringValue(row['MD_TiempoAfectacion']),
        'AfectaTiempos': _stringValue(row['MD_AfectaTiempos']),
        'Restriccion': _stringValue(row['MD_Restriccion']),
        'CreaRatificada': _stringValue(row['MD_CreaRatificada']),
        'EsVisibleApp': _stringValue(row['MD_EsVisibleApp']),
      });
    }).toList();
  }

  Future<void> saveReasons(List<EntregaReason> reasons) async {
    if (reasons.isEmpty) return;
    final db = await _openDatabase();
    await _ensureTables(db);
    await db.transaction((txn) async {
      await txn.delete('DevolucionMotivoGuia_LOI');
      for (final reason in reasons) {
        await txn.insert('DevolucionMotivoGuia_LOI', {
          'MD_IdMotivo': reason.id.toString(),
          'MD_Descripcion': reason.description,
          'MD_EsEscaneo': reason.scan ? '1' : '0',
          'MD_ObservacionesMotivo': reason.raw['ObservacionMotivo'] ?? '',
          'MD_CapturaPredio': reason.raw['CapturaPredio'] ?? '',
          'MD_CapturaContador': reason.raw['CapturaContador'] ?? '',
          'MD_CapturaObservacion': reason.raw['CapturaObservacion'] ?? '',
          'MD_TiempoAfectacion': reason.timeAffectation.toString(),
          'MD_AfectaTiempos': reason.raw['AfectaTiempos'] ?? '',
          'MD_Restriccion': reason.raw['Restriccion'] ?? '',
          'MD_CreaRatificada': reason.raw['CreaRatificada'] ?? '',
          'MD_EsVisibleApp': reason.raw['EsVisibleApp'] ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<int> pendingCount() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM entregas_descargues_offline WHERE synced = 0',
    );
    return _intValue(rows.first['total']);
  }

  Future<bool> isGuideAlreadyDownloaded(String guideNumber) async {
    final guide = guideNumber.trim();
    if (guide.isEmpty) return false;
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.rawQuery(
      '''
SELECT 1 FROM entregas_descargues_offline
WHERE numero_guia = ?
UNION
SELECT 1 FROM DescargueOffline_LO
WHERE DEO_NumeroGuia = ?
UNION
SELECT 1 FROM DescarguesSincronizadosOffline_LO
WHERE DEO_NumeroGuia = ?
LIMIT 1
''',
      [guide, guide, guide],
    );
    return rows.isNotEmpty;
  }

  Future<EntregaPendingDownload> savePendingDownload({
    required EntregaGuide guide,
    required EntregaDownloadType type,
    required Map<String, dynamic> payload,
    required bool isQr,
  }) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final guideNumber = guide.guideNumber.trim();
    if (guideNumber.isEmpty) {
      throw const EntregaException('La guia no tiene numero valido.');
    }
    final now = DateTime.now();
    final guideStatus = type == EntregaDownloadType.devolucionMensajero
        ? EntregaGuideStatus.devolucion
        : EntregaGuideStatus.entregada;
    final updatedGuide = guide.copyWith(
      stateId: type == EntregaDownloadType.devolucionMensajero
          ? _estadoDevolucion
          : _estadoEntregada,
      stateName: type == EntregaDownloadType.devolucionMensajero
          ? 'DEVOLUCION'
          : 'ENTREGADA',
    );

    return db.transaction((txn) async {
      await txn.delete(
        'entregas_descargues_offline',
        where: 'numero_guia = ?',
        whereArgs: [guideNumber],
      );
      await txn.delete(
        'DescargueOffline_LO',
        where: 'DEO_NumeroGuia = ?',
        whereArgs: [guideNumber],
      );
      await txn.delete(
        'DescargueAWS',
        where: 'DEO_NumeroGuia = ?',
        whereArgs: [guideNumber],
      );

      final motivo = _motivoText(payload['MotivoGuia']);
      await txn.insert('DescargueOffline_LO', {
        'DEO_NumeroGuia': guideNumber,
        'DEO_TipoDescargue': type.code,
        'DEO_Objeto': jsonEncode(payload),
        'DEO_ObjetoCompleto': jsonEncode(updatedGuide.toJson()),
        'DEO_ObjetoSincronizado': 0,
        'DEO_EstadoSincronizacion': _estadoNoSincronizado,
        'DEO_MensajeSincronizacion': '',
        'DEO_MotivoGuia': motivo,
        'DEO_FechaAsignacion': guide.assignmentDate,
        'DEO_EsCodigoQr': isQr ? 1 : 0,
        'DEO_SimulaEstados': 0,
        'DEO_EsPrePago': 0,
        'DEO_ErrorEntrega': 0,
        'DEO_ErrorMsg': '',
        'DEO_IntentosSyncFailed': 0,
        'DEO_MedioPago': 0,
        'DEO_EstadoPago': 0,
      });
      if (type == EntregaDownloadType.entregaCorrectaMensajero) {
        await txn.insert('DescargueAWS', {
          'DEO_NumeroGuia': guideNumber,
          'DEO_TipoDescargue': type.code,
          'DEO_Objeto': jsonEncode(payload),
          'DEO_ObjetoCompleto': jsonEncode(updatedGuide.toJson()),
          'DEO_ObjetoSincronizado': 0,
          'DEO_EstadoSincronizacion': _estadoNoSincronizado,
          'DEO_MensajeSincronizacion': '',
          'DEO_MotivoGuia': motivo,
          'DEO_FechaAsignacion': guide.assignmentDate,
          'DEO_FechaEntrega': payload['FechaEntrega']?.toString() ?? '',
        });
      }
      final id = await txn.insert('entregas_descargues_offline', {
        'numero_guia': guideNumber,
        'tipo_descargue': type.code,
        'payload_json': jsonEncode(payload),
        'guide_json': jsonEncode(updatedGuide.toJson()),
        'synced': 0,
        'is_qr': isQr ? 1 : 0,
        'created_at': now.toIso8601String(),
        'synced_at': null,
        'resultado': 0,
        'mensaje': '',
      });
      await txn.insert('entregas_guias_cache', {
        'numero_guia': guideNumber,
        'status': guideStatus.value,
        'guide_json': jsonEncode(updatedGuide.toJson()),
        'updated_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'GuiasPlanilladas_LO',
        where: 'GP_NumeroGuia = ?',
        whereArgs: [guideNumber],
      );
      return EntregaPendingDownload(
        id: id,
        guideNumber: guideNumber,
        type: type,
        guide: updatedGuide,
        payload: payload,
        synced: false,
        createdAt: now,
        isQr: isQr,
        message: '',
      );
    });
  }

  Future<List<EntregaPendingDownload>> pendingDownloads() async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final rows = await db.query(
      'entregas_descargues_offline',
      where: 'synced = 0',
      orderBy: 'id ASC',
    );
    return rows.map(EntregaPendingDownload.fromRow).toList();
  }

  Future<void> markDownloadSynced(
    EntregaPendingDownload download,
    EntregaSyncResult result,
  ) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'entregas_descargues_offline',
        {
          'synced': 1,
          'synced_at': now,
          'resultado': result.resultCode == 1 ? 100 : result.resultCode,
          'mensaje': result.message,
        },
        where: 'id = ?',
        whereArgs: [download.id],
      );
      await txn.update(
        'DescargueOffline_LO',
        {
          'DEO_ObjetoSincronizado': 1,
          'DEO_EstadoSincronizacion': _estadoSincronizado,
          'DEO_MensajeSincronizacion': result.message,
        },
        where: 'DEO_NumeroGuia = ?',
        whereArgs: [download.guideNumber],
      );
      await txn.update(
        'DescargueAWS',
        {
          'DEO_ObjetoSincronizado': 1,
          'DEO_EstadoSincronizacion': _estadoSincronizado,
          'DEO_MensajeSincronizacion': result.message,
        },
        where: 'DEO_NumeroGuia = ?',
        whereArgs: [download.guideNumber],
      );
      await txn.insert(
        'DescarguesSincronizadosOffline_LO',
        {
          'DEO_NumeroGuia': download.guideNumber,
          'DEO_FechaEntrega': _sqliteDate(DateTime.now()),
          'DEO_TipoDescargue': download.type.code,
          'DEO_Objeto': jsonEncode(download.payload),
          'DEO_ObjetoCompleto': jsonEncode(download.guide.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> markDownloadFailed(
    EntregaPendingDownload download,
    Object error,
  ) async {
    final db = await _openDatabase();
    await _ensureTables(db);
    final message = error.toString();
    await db.transaction((txn) async {
      await txn.update(
        'entregas_descargues_offline',
        {'mensaje': message},
        where: 'id = ?',
        whereArgs: [download.id],
      );
      await txn.update(
        'DescargueOffline_LO',
        {
          'DEO_EstadoSincronizacion': _estadoNoSincronizado,
          'DEO_MensajeSincronizacion': message,
          'DEO_ErrorEntrega': 1,
          'DEO_ErrorMsg': message,
          'DEO_IntentosSyncFailed': 1,
        },
        where: 'DEO_NumeroGuia = ?',
        whereArgs: [download.guideNumber],
      );
    });
  }

  Future<void> _ensureTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS entregas_guias_cache (
  numero_guia TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  guide_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS entregas_descargues_offline (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_guia TEXT NOT NULL,
  tipo_descargue TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  guide_json TEXT NOT NULL,
  synced INTEGER NOT NULL,
  is_qr INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  synced_at TEXT,
  resultado INTEGER,
  mensaje TEXT
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS GuiasPlanilladas_LO (
  GP_NumeroGuia TEXT,
  GP_Objeto VARCHAR
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS DescargueOffline_LO (
  DEO_NumeroGuia TEXT,
  DEO_TipoDescargue TEXT,
  DEO_Objeto VARCHAR,
  DEO_ObjetoCompleto VARCHAR,
  DEO_ObjetoSincronizado INT,
  DEO_EstadoSincronizacion INT,
  DEO_MensajeSincronizacion VARCHAR,
  DEO_MotivoGuia VARCHAR,
  DEO_FechaAsignacion TEXT,
  DEO_EsCodigoQr INT,
  DEO_SimulaEstados INT,
  DEO_EsPrePago INT,
  DEO_ErrorEntrega INTEGER DEFAULT 0,
  DEO_ErrorMsg TEXT DEFAULT '',
  DEO_IntentosSyncFailed INTEGER DEFAULT 0,
  DEO_MedioPago INTEGER DEFAULT 0,
  DEO_EstadoPago INTEGER DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS DescargueAWS (
  DEO_NumeroGuia TEXT,
  DEO_TipoDescargue TEXT,
  DEO_Objeto VARCHAR,
  DEO_ObjetoCompleto VARCHAR,
  DEO_ObjetoSincronizado INT,
  DEO_EstadoSincronizacion INT,
  DEO_MensajeSincronizacion VARCHAR,
  DEO_MotivoGuia VARCHAR,
  DEO_FechaAsignacion TEXT,
  DEO_FechaEntrega TEXT
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS DescarguesSincronizadosOffline_LO (
  DEO_NumeroGuia TEXT PRIMARY KEY,
  DEO_FechaEntrega DATE,
  DEO_TipoDescargue TEXT,
  DEO_Objeto VARCHAR,
  DEO_ObjetoCompleto VARCHAR
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS DevolucionMotivoGuia_LOI (
  MD_IdMotivo TEXT PRIMARY KEY,
  MD_Descripcion TEXT,
  MD_EsEscaneo TEXT,
  MD_ObservacionesMotivo TEXT,
  MD_CapturaPredio TEXT,
  MD_CapturaContador TEXT,
  MD_CapturaObservacion TEXT,
  MD_TiempoAfectacion TEXT,
  MD_AfectaTiempos TEXT,
  MD_Restriccion TEXT,
  MD_CreaRatificada TEXT,
  MD_EsVisibleApp TEXT
)
''');
  }

  Future<void> _mergeNativeGuides(
    Database db,
    EntregaGuideStatus status,
    Map<String, EntregaGuide> guides,
  ) async {
    if (status == EntregaGuideStatus.enZona) {
      final rows = await db.query('GuiasPlanilladas_LO');
      for (final row in rows) {
        final guide = EntregaGuide.fromJson(_decodeMap(row['GP_Objeto']));
        if (guide.guideNumber.trim().isNotEmpty) {
          guides.putIfAbsent(guide.guideNumber, () => guide);
        }
      }
      return;
    }

    final type = status == EntregaGuideStatus.devolucion
        ? EntregaDownloadType.devolucionMensajero
        : EntregaDownloadType.entregaCorrectaMensajero;
    final syncedRows = await db.query(
      'DescarguesSincronizadosOffline_LO',
      where: 'DEO_TipoDescargue = ?',
      whereArgs: [type.code],
    );
    final pendingRows = await db.query(
      'DescargueOffline_LO',
      where: 'DEO_TipoDescargue = ?',
      whereArgs: [type.code],
    );
    for (final row in [...syncedRows, ...pendingRows]) {
      final guide = EntregaGuide.fromJson(
        _decodeMap(row['DEO_ObjetoCompleto']),
      );
      if (guide.guideNumber.trim().isNotEmpty) {
        guides.putIfAbsent(guide.guideNumber, () => guide);
      }
    }
  }

  String _motivoText(Object? value) {
    if (value is Map) {
      return _stringValue(value['Descripcion'] ?? value['DescripcionAPP']);
    }
    return '';
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

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_stringValue(value).trim()) ?? 0;
  }

  String _sqliteDate(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)}';
  }

  String _stringValue(Object? value) => value?.toString() ?? '';
}
