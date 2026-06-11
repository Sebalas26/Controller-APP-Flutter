import 'dart:convert';

class AsignacionGuiasException implements Exception {
  const AsignacionGuiasException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AsignacionAccessTokens {
  const AsignacionAccessTokens({
    required this.tokenRefresh,
    required this.token,
    required this.userName,
  });

  final String tokenRefresh;
  final String token;
  final String userName;

  bool get isValid =>
      tokenRefresh.trim().isNotEmpty &&
      token.trim().isNotEmpty &&
      userName.trim().isNotEmpty;
}

class AsignacionMessenger {
  const AsignacionMessenger({
    required this.idMensajero,
    required this.idCentroServicio,
    required this.identificacion,
    required this.nombre,
    required this.idTipoMensajero,
    required this.loginUsuario,
    required this.telefono,
    required this.usuarioActivo,
  });

  final int idMensajero;
  final int idCentroServicio;
  final String identificacion;
  final String nombre;
  final int idTipoMensajero;
  final String loginUsuario;
  final String telefono;
  final bool usuarioActivo;

  factory AsignacionMessenger.parent({
    required int idMensajero,
    required int idTipoMensajero,
    required String nombre,
  }) {
    return AsignacionMessenger(
      idMensajero: idMensajero,
      idCentroServicio: 0,
      identificacion: '',
      nombre: nombre.trim().isEmpty ? 'Asignar al principal' : nombre.trim(),
      idTipoMensajero: idTipoMensajero,
      loginUsuario: '',
      telefono: '',
      usuarioActivo: true,
    );
  }

  factory AsignacionMessenger.fromJson(Map<String, dynamic> json) {
    final firstName = _readString(json, 'nombre', fallbackKeys: ['Nombre']);
    final lastName = _readString(
      json,
      'primerApellido',
      fallbackKeys: ['PrimerApellido'],
    );
    final secondLastName = _readString(
      json,
      'segundoApellido',
      fallbackKeys: ['SegundoApellido'],
    );
    final fullName = _titleCase(
      [firstName, lastName, secondLastName]
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(' '),
    );
    return AsignacionMessenger(
      idMensajero: _readInt(json, 'idMensajero', fallbackKeys: ['IdMensajero']),
      idCentroServicio: _readInt(
        json,
        'idCentroServicio',
        fallbackKeys: ['IdCentroServicio'],
      ),
      identificacion: _readString(
        json,
        'identificacion',
        fallbackKeys: ['Identificacion'],
      ),
      nombre: fullName.isEmpty
          ? _titleCase(_readString(json, 'nombreCompleto'))
          : fullName,
      idTipoMensajero: _readInt(
        json,
        'idTipoMensajero',
        fallbackKeys: ['IdTipoMensajero'],
      ),
      loginUsuario: _readString(
        json,
        'loginUsuario',
        fallbackKeys: ['LoginUsuario'],
      ),
      telefono: _readString(json, 'telefono', fallbackKeys: ['Telefono']),
      usuarioActivo: _readBool(
        json,
        'usuarioActivo',
        fallbackKeys: ['UsuarioActivo'],
        defaultValue: true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idMensajero': idMensajero,
      'idCentroServicio': idCentroServicio,
      'identificacion': identificacion,
      'nombre': nombre,
      'idTipoMensajero': idTipoMensajero,
      'loginUsuario': loginUsuario,
      'telefono': telefono,
      'usuarioActivo': usuarioActivo,
    };
  }
}

class AsignacionGuideState {
  const AsignacionGuideState({
    required this.numeroGuia,
    required this.estadoGuia,
    required this.peso,
    required this.direccionDestinatario,
    this.esReasignacionFallida = false,
  });

  final int numeroGuia;
  final int estadoGuia;
  final int peso;
  final String direccionDestinatario;
  final bool esReasignacionFallida;

  AsignacionGuideState copyWith({bool? esReasignacionFallida}) {
    return AsignacionGuideState(
      numeroGuia: numeroGuia,
      estadoGuia: estadoGuia,
      peso: peso,
      direccionDestinatario: direccionDestinatario,
      esReasignacionFallida:
          esReasignacionFallida ?? this.esReasignacionFallida,
    );
  }

  factory AsignacionGuideState.fromJson(Map<String, dynamic> json) {
    return AsignacionGuideState(
      numeroGuia: _readInt(json, 'NumeroGuia', fallbackKeys: ['numeroGuia']),
      estadoGuia: _readInt(json, 'EstadoGuia', fallbackKeys: ['estadoGuia']),
      peso: _readInt(json, 'Peso', fallbackKeys: ['peso']),
      direccionDestinatario: _readString(
        json,
        'DireccionDestinatario',
        fallbackKeys: ['direccionDestinatario'],
      ),
      esReasignacionFallida: _readBool(
        json,
        'esReAsignacionFallida',
        fallbackKeys: ['esReasignacionFallida'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'NumeroGuia': numeroGuia,
      'EstadoGuia': estadoGuia,
      'Peso': peso,
      'DireccionDestinatario': direccionDestinatario,
      'esReAsignacionFallida': esReasignacionFallida,
    };
  }
}

class ReassignGuidesResult {
  const ReassignGuidesResult({
    required this.idPlanilla,
    required this.guiasSinAsignar,
  });

  final int idPlanilla;
  final List<int> guiasSinAsignar;

  factory ReassignGuidesResult.fromJson(Map<String, dynamic> json) {
    return ReassignGuidesResult(
      idPlanilla: _readInt(json, 'idPlanilla', fallbackKeys: ['IdPlanilla']),
      guiasSinAsignar: _readIntList(
        json['guiasSinAsignar'] ?? json['GuiasSinAsignar'],
      ),
    );
  }
}

class PreviousSheets {
  const PreviousSheets({required this.planillas});

  final List<AssignedSheet> planillas;

  factory PreviousSheets.empty() => const PreviousSheets(planillas: []);

  factory PreviousSheets.fromJson(Map<String, dynamic> json) {
    return PreviousSheets(
      planillas: _readMapList(
        json['Planillas'] ?? json['planillas'],
      ).map(AssignedSheet.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {'Planillas': planillas.map((item) => item.toJson()).toList()};
  }
}

class AssignedSheet {
  const AssignedSheet({
    required this.idPlanilla,
    required this.fechaAsignacion,
    required this.guias,
  });

  final int idPlanilla;
  final String fechaAsignacion;
  final List<PreviousGuide> guias;

  AssignedSheet copyWith({List<PreviousGuide>? guias}) {
    return AssignedSheet(
      idPlanilla: idPlanilla,
      fechaAsignacion: fechaAsignacion,
      guias: guias ?? this.guias,
    );
  }

  factory AssignedSheet.fromJson(Map<String, dynamic> json) {
    final date = _readString(
      json,
      'FechaAsignacion',
      fallbackKeys: ['fechaAsignacion'],
    );
    return AssignedSheet(
      idPlanilla: _readInt(json, 'IdPlanilla', fallbackKeys: ['idPlanilla']),
      fechaAsignacion: date,
      guias: _readMapList(json['Guias'] ?? json['guias'])
          .map((item) => PreviousGuide.fromJson(item, date))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'IdPlanilla': idPlanilla,
      'FechaAsignacion': fechaAsignacion,
      'Guias': guias.map((item) => item.toJson()).toList(),
    };
  }
}

class PreviousGuide {
  const PreviousGuide({
    required this.numeroGuia,
    required this.direccionDestinatario,
    required this.estado,
    required this.valorTotal,
    required this.fechaAsignacion,
    this.esReasignacionFallida = false,
  });

  final int numeroGuia;
  final String direccionDestinatario;
  final String estado;
  final int valorTotal;
  final String fechaAsignacion;
  final bool esReasignacionFallida;

  bool get isPlanillada => estado.trim().toUpperCase() == 'PLA';

  PreviousGuide copyWith({bool? esReasignacionFallida}) {
    return PreviousGuide(
      numeroGuia: numeroGuia,
      direccionDestinatario: direccionDestinatario,
      estado: estado,
      valorTotal: valorTotal,
      fechaAsignacion: fechaAsignacion,
      esReasignacionFallida:
          esReasignacionFallida ?? this.esReasignacionFallida,
    );
  }

  factory PreviousGuide.fromJson(
    Map<String, dynamic> json,
    String fallbackDate,
  ) {
    return PreviousGuide(
      numeroGuia: _readInt(json, 'NumeroGuia', fallbackKeys: ['numeroGuia']),
      direccionDestinatario: _readString(
        json,
        'DireccionDestinatario',
        fallbackKeys: ['direccionDestinatario'],
      ),
      estado: _readString(json, 'Estado', fallbackKeys: ['estado']),
      valorTotal: _readInt(
        json,
        'ValorTotalGuia',
        fallbackKeys: ['valorTotal'],
      ),
      fechaAsignacion: _readString(
        json,
        'FechaAsignacion',
        fallbackKeys: ['fechaAsignacion'],
        defaultValue: fallbackDate,
      ),
      esReasignacionFallida: _readBool(
        json,
        'esReasignacionFallida',
        fallbackKeys: ['esReAsignacionFallida'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'NumeroGuia': numeroGuia,
      'DireccionDestinatario': direccionDestinatario,
      'ValorTotalGuia': valorTotal,
      'Estado': estado,
      'FechaAsignacion': fechaAsignacion,
      'esReasignacionFallida': esReasignacionFallida,
    };
  }
}

Map<String, dynamic> asignacionAsMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return asignacionAsMap(decoded);
  }
  return const {};
}

List<Map<String, dynamic>> asignacionAsMapList(Object? value) {
  if (value is List) return _readMapList(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return _readMapList(decoded);
  }
  return const [];
}

List<Map<String, dynamic>> _readMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object?>()
      .map(asignacionAsMap)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _readIntList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => int.tryParse(item?.toString() ?? '') ?? 0)
      .where((item) => item != 0)
      .toList(growable: false);
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  List<String> fallbackKeys = const [],
  String defaultValue = '',
}) {
  final keys = [key, ...fallbackKeys];
  for (final item in keys) {
    final value = json[item];
    if (value != null) return value.toString();
  }
  return defaultValue;
}

int _readInt(
  Map<String, dynamic> json,
  String key, {
  List<String> fallbackKeys = const [],
}) {
  final value = [key, ...fallbackKeys]
      .map((item) => json[item])
      .firstWhere((item) => item != null, orElse: () => null);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  List<String> fallbackKeys = const [],
  bool defaultValue = false,
}) {
  final value = [key, ...fallbackKeys]
      .map((item) => json[item])
      .firstWhere((item) => item != null, orElse: () => null);
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return defaultValue;
}

String _titleCase(String value) {
  return value
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .map((item) {
        if (item.length == 1) return item.toUpperCase();
        return '${item[0].toUpperCase()}${item.substring(1)}';
      })
      .join(' ');
}
