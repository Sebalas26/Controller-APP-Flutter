import '../../login/login.dart';
import '../models/tarjeta_comercial_models.dart';

class TarjetaComercialLocalRepository {
  TarjetaComercialLocalRepository({ControllerLocalDatabase? localDatabase})
    : _localDatabase = localDatabase ?? ControllerLocalDatabase();

  static const _table = 'TarjetaComercial_MEN';

  final ControllerLocalDatabase _localDatabase;

  Future<List<TarjetaComercialItem>> loadItems() async {
    final db = await _localDatabase.database;
    final tableName = await _resolveTableName();
    if (tableName == null) return const [];

    final columns = await db.rawQuery(
      'PRAGMA table_info(${_quoteIdentifier(tableName)})',
    );
    if (columns.isEmpty) return const [];

    final columnNames = columns
        .map((row) => _readString(row['name']))
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final descriptionColumn =
        _findColumn(columnNames, 'TCM_Descripcion') ??
        (columnNames.length > 1 ? columnNames[1] : columnNames.first);
    final titleColumn = columnNames.length > 2 ? columnNames[2] : null;
    final detailColumn = columnNames.length > 3 ? columnNames[3] : null;
    final rows = await db.query(tableName);

    return rows
        .map(
          (row) => TarjetaComercialItem(
            description: _readString(row[descriptionColumn]),
            messageTitle: titleColumn == null
                ? ''
                : _readString(row[titleColumn]),
            messageDetail: detailColumn == null
                ? ''
                : _readString(row[detailColumn]),
          ),
        )
        .where(
          (item) =>
              item.description.trim().isNotEmpty ||
              item.messageTitle.trim().isNotEmpty ||
              item.messageDetail.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<String?> _resolveTableName() async {
    final db = await _localDatabase.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND lower(name) = lower(?) LIMIT 1",
      [_table],
    );
    if (rows.isEmpty) return null;
    final name = _readString(rows.first['name']);
    return name.isEmpty ? null : name;
  }

  String? _findColumn(List<String> columns, String expected) {
    for (final column in columns) {
      if (column.toLowerCase() == expected.toLowerCase()) return column;
    }
    return null;
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _readString(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}
