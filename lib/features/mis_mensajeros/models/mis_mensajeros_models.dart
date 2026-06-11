import 'dart:convert';

class MisMensajerosException implements Exception {
  const MisMensajerosException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MisMensajerosTokens {
  const MisMensajerosTokens({
    required this.tokenRefresh,
    required this.token,
    required this.userName,
    required this.idRolApoyo,
  });

  final String tokenRefresh;
  final String token;
  final String userName;
  final int idRolApoyo;

  bool get isValid =>
      tokenRefresh.trim().isNotEmpty &&
      token.trim().isNotEmpty &&
      userName.trim().isNotEmpty;
}

class MisMensajero {
  const MisMensajero({
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

  MisMensajero copyWith({bool? usuarioActivo}) {
    return MisMensajero(
      idMensajero: idMensajero,
      idCentroServicio: idCentroServicio,
      identificacion: identificacion,
      nombre: nombre,
      idTipoMensajero: idTipoMensajero,
      loginUsuario: loginUsuario,
      telefono: telefono,
      usuarioActivo: usuarioActivo ?? this.usuarioActivo,
    );
  }

  factory MisMensajero.fromJson(Map<String, dynamic> json) {
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
    final composedName = _titleCase(
      [
        firstName,
        lastName,
        secondLastName,
      ].map((item) => item.trim()).where((item) => item.isNotEmpty).join(' '),
    );
    return MisMensajero(
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
      nombre: composedName.isEmpty
          ? _titleCase(
              _readString(
                json,
                'nombreCompleto',
                fallbackKeys: ['NombreCompleto'],
              ),
            )
          : composedName,
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

class GenerateOtpResult {
  const GenerateOtpResult({
    required this.rawMessage,
    this.codigoOtp = '',
    this.mensajeValidacion = '',
    this.huboError = false,
  });

  final String rawMessage;
  final String codigoOtp;
  final String mensajeValidacion;
  final bool huboError;

  bool get success => !huboError;

  factory GenerateOtpResult.fromData(Object? data) {
    if (data is String) {
      final text = data.trim();
      if (text.isEmpty) return const GenerateOtpResult(rawMessage: '');
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return GenerateOtpResult.fromJson(_asMap(decoded));
      } on Object {
        return GenerateOtpResult(rawMessage: text);
      }
      return GenerateOtpResult(rawMessage: text);
    }
    if (data is Map) return GenerateOtpResult.fromJson(_asMap(data));
    return GenerateOtpResult(rawMessage: data?.toString() ?? '');
  }

  factory GenerateOtpResult.fromJson(Map<String, dynamic> json) {
    return GenerateOtpResult(
      rawMessage: _readString(
        json,
        'mensajeValidacion',
        fallbackKeys: ['MensajeValidacion'],
      ),
      codigoOtp: _readString(json, 'codigoOtp', fallbackKeys: ['CodigoOtp']),
      mensajeValidacion: _readString(
        json,
        'mensajeValidacion',
        fallbackKeys: ['MensajeValidacion'],
      ),
      huboError: _readBool(json, 'huboError', fallbackKeys: ['HuboError']),
    );
  }
}

Map<String, dynamic> misMensajerosAsMap(Object? value) => _asMap(value);

List<Map<String, dynamic>> misMensajerosAsMapList(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return misMensajerosAsMapList(jsonDecode(value));
  }
  if (value is! List) return const [];
  return value
      .map(_asMap)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return _asMap(decoded);
  }
  return const {};
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  List<String> fallbackKeys = const [],
}) {
  for (final current in [key, ...fallbackKeys]) {
    final value = json[current];
    if (value != null) return value.toString();
  }
  return '';
}

int _readInt(
  Map<String, dynamic> json,
  String key, {
  List<String> fallbackKeys = const [],
}) {
  for (final current in [key, ...fallbackKeys]) {
    final value = json[current];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  List<String> fallbackKeys = const [],
  bool defaultValue = false,
}) {
  for (final current in [key, ...fallbackKeys]) {
    final value = json[current];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
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
