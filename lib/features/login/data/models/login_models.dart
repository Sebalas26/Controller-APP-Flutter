part of '../login_data.dart';

class CredentialRequest {
  const CredentialRequest({
    required this.user,
    required this.password,
    required this.path,
    required this.mac,
    required this.applicationName,
    this.deviceId = '',
    this.firebaseToken = '',
  });

  final String user;
  final String password;
  final String path;
  final String mac;
  final String applicationName;
  final String deviceId;
  final String firebaseToken;

  Map<String, dynamic> toJson() {
    return {
      'Usuario': user,
      'Password': password,
      'Path': path,
      'Mac': mac,
      'NomAplicacion': applicationName,
      'IdDispositivo': deviceId,
      'TokenFirebase': firebaseToken,
    };
  }
}

class LoginCredential {
  const LoginCredential({
    required this.raw,
    required this.usuario,
    required this.tipoIdentificacion,
    required this.identificacion,
    required this.nombre,
    required this.apellido1,
    required this.apellido2,
    required this.cargo,
    required this.codigo,
    required this.idLocalidad,
    required this.nombreLocalidad,
    required this.locations,
    required this.mensajeResultado,
    required this.nomRol,
    required this.aplicaciones,
    required this.modules,
    required this.userAppLogin,
    required this.roles,
    required this.idRolApoyoACrear,
  });

  final Map<String, dynamic> raw;
  final String usuario;
  final String tipoIdentificacion;
  final String identificacion;
  final String nombre;
  final String apellido1;
  final String apellido2;
  final String cargo;
  final String codigo;
  final String idLocalidad;
  final String nombreLocalidad;
  final List<AuthorizedLocation> locations;
  final int mensajeResultado;
  final String nomRol;
  final Map<String, dynamic> aplicaciones;
  final List<ModuleApp> modules;
  final UsuarioAppLogin? userAppLogin;
  final List<RoleDto> roles;
  final int idRolApoyoACrear;

  String get fullName {
    return [
      nombre,
      apellido1,
      apellido2,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).join(' ');
  }

  static LoginCredential fromCompressedResponse(String encoded) {
    final trimmed = encoded.trim();
    final unquoted = trimmed.startsWith('"')
        ? jsonDecode(trimmed) as String
        : trimmed;
    final bytes = base64Decode(unquoted.replaceAll(RegExp(r'\s'), ''));
    final jsonText = utf8.decode(GZipCodec().decode(bytes));
    return LoginCredential.fromJson(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
  }

  factory LoginCredential.fromJson(Map<String, dynamic> json) {
    return LoginCredential(
      raw: Map<String, dynamic>.from(json),
      usuario: _readString(json, 'Usuario'),
      tipoIdentificacion: _readString(json, 'TipoIdentificacion'),
      identificacion: _readString(json, 'Identificacion'),
      nombre: _readString(json, 'Nombre'),
      apellido1: _readString(json, 'Apellido1'),
      apellido2: _readString(json, 'Apellido2'),
      cargo: _readString(json, 'Cargo'),
      codigo: _readString(json, 'Codigo'),
      idLocalidad: _readString(json, 'IdLocalidad'),
      nombreLocalidad: _readString(json, 'NombreLocalidad'),
      locations: _readMapList(
        json['Ubicaciones'],
      ).map(AuthorizedLocation.fromJson).toList(),
      mensajeResultado: _readInt(json, 'MensajeResultado'),
      nomRol: _readString(json, 'NomRol'),
      aplicaciones: _asMap(json['Aplicaciones']) ?? const {},
      modules: _readMapList(
        json['ModulosApp'],
      ).map(ModuleApp.fromJson).toList(),
      userAppLogin: _asMap(json['UsuarioAppLogin']) == null
          ? null
          : UsuarioAppLogin.fromJson(_asMap(json['UsuarioAppLogin'])!),
      roles: _readMapList(json['Roles']).map(RoleDto.fromJson).toList(),
      idRolApoyoACrear: _readInt(json, 'IdRolApoyoACrear'),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class AuthorizedLocation {
  const AuthorizedLocation({
    required this.userId,
    required this.serviceCenterName,
    required this.cityId,
    required this.cityName,
    required this.serviceCenterId,
    required this.cashBoxId,
  });

  final String userId;
  final String serviceCenterName;
  final String cityId;
  final String cityName;
  final int serviceCenterId;
  final int cashBoxId;

  factory AuthorizedLocation.fromJson(Map<String, dynamic> json) {
    return AuthorizedLocation(
      userId: _readString(json, 'UBUIdUsuario'),
      serviceCenterName: _readString(json, 'NombreCentroServicios'),
      cityId: _readString(json, 'IdLocalidad'),
      cityName: _readString(json, 'NombreCompletoLocalidad'),
      serviceCenterId: _readInt(json, 'UBUIdCentroServicios'),
      cashBoxId: _readInt(json, 'IdCaja'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'UBUIdUsuario': userId,
      'NombreCentroServicios': serviceCenterName,
      'IdLocalidad': cityId,
      'NombreCompletoLocalidad': cityName,
      'UBUIdCentroServicios': serviceCenterId,
      'IdCaja': cashBoxId,
    };
  }
}

class ModuleApp {
  const ModuleApp({
    required this.id,
    required this.name,
    required this.enabled,
    required this.visible,
    required this.order,
    required this.applicationId,
    required this.newDate,
    required this.primary,
  });

  final int id;
  final String name;
  final bool enabled;
  final bool visible;
  final int order;
  final int applicationId;
  final String newDate;
  final bool primary;

  factory ModuleApp.fromJson(Map<String, dynamic> json) {
    return ModuleApp(
      id: _readInt(json, 'MODIdModulo'),
      name: _readString(json, 'MODNombre'),
      enabled: _readBool(json, 'MODEstado'),
      visible: _readBool(json, 'MODVisible'),
      order: _readInt(json, 'MODOrden'),
      applicationId: _readInt(json, 'MODIdAplicacion'),
      newDate: _readString(json, 'MODFechaModuloNuevo'),
      primary: _readBool(json, 'MODPrincipal'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MODIdModulo': id,
      'MODNombre': name,
      'MODEstado': enabled,
      'MODVisible': visible,
      'MODOrden': order,
      'MODIdAplicacion': applicationId,
      'MODFechaModuloNuevo': newDate,
      'MODPrincipal': primary,
    };
  }
}

class RoleDto {
  const RoleDto({required this.id, required this.name});

  final int id;
  final String name;

  factory RoleDto.fromJson(Map<String, dynamic> json) {
    return RoleDto(id: _readInt(json, 'Id'), name: _readString(json, 'Nombre'));
  }

  Map<String, dynamic> toJson() => {'Id': id, 'Nombre': name};
}

class UsuarioAppLogin {
  const UsuarioAppLogin({
    required this.tokenRefresh,
    required this.uuidDevice,
    required this.user,
  });

  final String tokenRefresh;
  final String uuidDevice;
  final UsuarioDto? user;

  factory UsuarioAppLogin.fromJson(Map<String, dynamic> json) {
    final userJson = _asMap(json['Usuario']);
    return UsuarioAppLogin(
      tokenRefresh: _readString(json, 'TokenRefresh'),
      uuidDevice: _readString(json, 'UuidDispositivo'),
      user: userJson == null ? null : UsuarioDto.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'TokenRefresh': tokenRefresh,
      'UuidDispositivo': uuidDevice,
      'Usuario': user?.toJson(),
    };
  }
}

class UsuarioDto {
  const UsuarioDto({
    required this.userName,
    required this.displayName,
    required this.token,
  });

  final String userName;
  final String displayName;
  final String token;

  factory UsuarioDto.fromJson(Map<String, dynamic> json) {
    return UsuarioDto(
      userName: _readString(json, 'UserName'),
      displayName: _readString(json, 'DisplayName'),
      token: _readString(json, 'Token'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'UserName': userName, 'DisplayName': displayName, 'Token': token};
  }
}

class UserInfo {
  const UserInfo({
    required this.enabled,
    required this.messengerId,
    required this.messengerTypeId,
    required this.fullName,
    required this.currentDate,
    required this.serviceCenterId,
  });

  final bool enabled;
  final int messengerId;
  final int messengerTypeId;
  final String fullName;
  final String currentDate;
  final int serviceCenterId;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      enabled: _readBool(json, 'Habilitado'),
      messengerId: _readInt(json, 'IdMensajero'),
      messengerTypeId: _readInt(json, 'IdTipoMensajero'),
      fullName: _readString(json, 'NombreCompleto'),
      currentDate: _readString(json, 'FechaActual'),
      serviceCenterId: _readInt(json, 'IdCentroServicio'),
    );
  }
}

class AppInformation implements ControllerHeaderSource {
  const AppInformation({
    required this.idUsuario,
    required this.idMensajero,
    required this.nombreMensajero,
    required this.rol,
    required this.idCaja,
    required this.identificacionUsuario,
    required this.nombreCentroServicio,
    required this.idCentroServicio,
    required this.nombreUsuario,
    required this.idCiudad,
    required this.idDispositivo,
    required this.permisos,
    required this.nombreCiudad,
    required this.idTipoMensajero,
    required this.loginDate,
    required this.loginDateCompact,
    required this.environmentLabel,
    required this.isLoginOnline,
  });

  @override
  final String idUsuario;
  final String idMensajero;
  final String nombreMensajero;
  final String rol;
  final String idCaja;
  @override
  final String identificacionUsuario;
  @override
  final String nombreCentroServicio;
  @override
  final String idCentroServicio;
  final String nombreUsuario;
  final String idCiudad;
  final String idDispositivo;
  final Map<String, dynamic> permisos;
  final String nombreCiudad;
  final String idTipoMensajero;
  final String loginDate;
  final String loginDateCompact;
  final String environmentLabel;
  final bool isLoginOnline;

  String get displayName {
    if (nombreMensajero.trim().isNotEmpty) return nombreMensajero.trim();
    if (nombreUsuario.trim().isNotEmpty) return nombreUsuario.trim();
    return idUsuario;
  }

  AppInformation copyWith({
    String? idMensajero,
    String? nombreMensajero,
    String? idTipoMensajero,
    String? idDispositivo,
    String? loginDate,
    String? loginDateCompact,
    bool? isLoginOnline,
  }) {
    return AppInformation(
      idUsuario: idUsuario,
      idMensajero: idMensajero ?? this.idMensajero,
      nombreMensajero: nombreMensajero ?? this.nombreMensajero,
      rol: rol,
      idCaja: idCaja,
      identificacionUsuario: identificacionUsuario,
      nombreCentroServicio: nombreCentroServicio,
      idCentroServicio: idCentroServicio,
      nombreUsuario: nombreUsuario,
      idCiudad: idCiudad,
      idDispositivo: idDispositivo ?? this.idDispositivo,
      permisos: permisos,
      nombreCiudad: nombreCiudad,
      idTipoMensajero: idTipoMensajero ?? this.idTipoMensajero,
      loginDate: loginDate ?? this.loginDate,
      loginDateCompact: loginDateCompact ?? this.loginDateCompact,
      environmentLabel: environmentLabel,
      isLoginOnline: isLoginOnline ?? this.isLoginOnline,
    );
  }

  Map<String, Object?> toDb() {
    return {
      'id': 1,
      'id_usuario': idUsuario,
      'id_mensajero': idMensajero,
      'nombre_mensajero': nombreMensajero,
      'rol': rol,
      'id_caja': idCaja,
      'identificacion_usuario': identificacionUsuario,
      'nombre_centro_servicio': nombreCentroServicio,
      'id_centro_servicio': idCentroServicio,
      'nombre_usuario': nombreUsuario,
      'id_ciudad': idCiudad,
      'id_dispositivo': idDispositivo,
      'permisos_json': jsonEncode(permisos),
      'nombre_ciudad': nombreCiudad,
      'id_tipo_mensajero': idTipoMensajero,
      'login_date': loginDate,
      'login_date_compact': loginDateCompact,
      'environment_label': environmentLabel,
      'is_login_online': isLoginOnline ? 1 : 0,
    };
  }

  factory AppInformation.fromDb(Map<String, Object?> row) {
    return AppInformation(
      idUsuario: _dbString(row['id_usuario']),
      idMensajero: _dbString(row['id_mensajero']),
      nombreMensajero: _dbString(row['nombre_mensajero']),
      rol: _dbString(row['rol']),
      idCaja: _dbString(row['id_caja']),
      identificacionUsuario: _dbString(row['identificacion_usuario']),
      nombreCentroServicio: _dbString(row['nombre_centro_servicio']),
      idCentroServicio: _dbString(row['id_centro_servicio']),
      nombreUsuario: _dbString(row['nombre_usuario']),
      idCiudad: _dbString(row['id_ciudad']),
      idDispositivo: _dbString(row['id_dispositivo']),
      permisos: _decodeObject(_dbString(row['permisos_json'])),
      nombreCiudad: _dbString(row['nombre_ciudad']),
      idTipoMensajero: _dbString(row['id_tipo_mensajero']),
      loginDate: _dbString(row['login_date']),
      loginDateCompact: _dbString(row['login_date_compact']),
      environmentLabel: _dbString(row['environment_label']),
      isLoginOnline: row['is_login_online'] == 1,
    );
  }

  static AppInformation fromLogin({
    required LoginCredential credential,
    required AuthorizedLocation location,
    required String environmentLabel,
  }) {
    return AppInformation(
      idUsuario: credential.usuario,
      idMensajero: '',
      nombreMensajero: credential.nombre.trim(),
      rol: credential.nomRol.trim(),
      idCaja: location.cashBoxId.toString(),
      identificacionUsuario: credential.identificacion,
      nombreCentroServicio: location.serviceCenterName,
      idCentroServicio: location.serviceCenterId.toString(),
      nombreUsuario: credential.nombre.trim(),
      idCiudad: location.cityId,
      idDispositivo: '',
      permisos: credential.aplicaciones,
      nombreCiudad: location.cityName,
      idTipoMensajero: '',
      loginDate: '',
      loginDateCompact: '',
      environmentLabel: environmentLabel,
      isLoginOnline: false,
    );
  }
}

class SyncSchema {
  const SyncSchema({
    required this.batchSize,
    required this.error,
    required this.filter,
    required this.tableName,
    required this.fieldCount,
    required this.primaryKey,
    required this.createQuery,
  });

  final int batchSize;
  final String error;
  final String filter;
  final String tableName;
  final int fieldCount;
  final String primaryKey;
  final String createQuery;

  factory SyncSchema.fromJson(Map<String, dynamic> json) {
    return SyncSchema(
      batchSize: _readAnyInt(json, const ['BatchSize', '_batchSize']),
      error: _readAnyString(json, const ['Error', '_error']),
      filter: _readAnyString(json, const ['Filtro', '_filtro']),
      tableName: _readAnyString(json, const ['NombreTabla', '_nombreTabla']),
      fieldCount: _readAnyInt(json, const ['NumeroCampos', '_numeroCampos']),
      primaryKey: _readAnyString(json, const ['Pk', '_pk']),
      createQuery: _readAnyString(json, const [
        'QueryCreacion',
        '_queryCreacion',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BatchSize': batchSize,
      'Error': error,
      'Filtro': filter,
      'NombreTabla': tableName,
      'NumeroCampos': fieldCount,
      'Pk': primaryKey,
      'QueryCreacion': createQuery,
    };
  }
}

class SyncBatchRecord {
  const SyncBatchRecord({
    required this.insertUpdate,
    required this.tableName,
    required this.actualAnchor,
    required this.currentBatch,
    required this.totalBatch,
    required this.error,
  });

  final String insertUpdate;
  final String tableName;
  final String actualAnchor;
  final int currentBatch;
  final int totalBatch;
  final String error;

  factory SyncBatchRecord.fromJson(Map<String, dynamic> json) {
    return SyncBatchRecord(
      insertUpdate: _readString(json, 'InsertUpdate'),
      tableName: _readString(json, 'NombreTabla'),
      actualAnchor: _readString(json, 'ActualAnchor'),
      currentBatch: _readInt(json, 'BatchActual'),
      totalBatch: _readInt(json, 'TotalBatch'),
      error: _readString(json, 'Error'),
    );
  }
}

class TorreDirectionSchema {
  const TorreDirectionSchema({
    required this.tableName,
    required this.filter,
    required this.createQuery,
    required this.fieldCount,
    required this.updatedAt,
  });

  final String tableName;
  final String filter;
  final String createQuery;
  final int fieldCount;
  final String updatedAt;

  bool get hasServiceCenterFilter => filter.trim().isNotEmpty;

  factory TorreDirectionSchema.fromJson(Map<String, dynamic> json) {
    return TorreDirectionSchema(
      tableName: _readAnyString(json, const ['nombreTabla', 'NombreTabla']),
      filter: _readAnyString(json, const ['filtro', 'Filtro']),
      createQuery: _readAnyString(json, const ['queryCreate', 'QueryCreate']),
      fieldCount: _readAnyInt(json, const ['numeroColumnas', 'NumeroColumnas']),
      updatedAt: _readAnyString(json, const [
        'fechaCreacionActualizacion',
        'FechaCreacionActualizacion',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombreTabla': tableName,
      'filtro': filter,
      'queryCreate': createQuery,
      'numeroColumnas': fieldCount,
      'fechaCreacionActualizacion': updatedAt,
    };
  }
}

class LocalSyncStatus {
  const LocalSyncStatus({
    required this.completed,
    required this.message,
    required this.startedAt,
    this.finishedAt,
    this.tables = 0,
  });

  final bool completed;
  final String message;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int tables;

  Map<String, Object?> toDb() {
    return {
      'id': 1,
      'completed': completed ? 1 : 0,
      'message': message,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'tables': tables,
    };
  }

  factory LocalSyncStatus.fromDb(Map<String, Object?> row) {
    return LocalSyncStatus(
      completed: row['completed'] == 1,
      message: _dbString(row['message']),
      startedAt:
          DateTime.tryParse(_dbString(row['started_at'])) ?? DateTime.now(),
      finishedAt: DateTime.tryParse(_dbString(row['finished_at'])),
      tables: (row['tables'] as int?) ?? 0,
    );
  }
}

class AuthenticatedSession {
  const AuthenticatedSession({
    required this.username,
    required this.environmentLabel,
    required this.rememberUser,
    required this.loginDate,
    required this.appInformation,
    required this.syncStatus,
    required this.modules,
    required this.offline,
  });

  final String username;
  final String environmentLabel;
  final bool rememberUser;
  final DateTime loginDate;
  final AppInformation appInformation;
  final LocalSyncStatus? syncStatus;
  final List<ModuleApp> modules;
  final bool offline;
}

class LoginDraft {
  const LoginDraft({
    required this.config,
    required this.username,
    required this.password,
    required this.androidId,
    required this.aesSecret,
    required this.firebaseToken,
    required this.credential,
  });

  final ControllerApiConfig config;
  final String username;
  final String password;
  final String androidId;
  final String aesSecret;
  final String firebaseToken;
  final LoginCredential credential;
}

class LoginStartResult {
  const LoginStartResult._({this.draft, this.offlineSession});

  factory LoginStartResult.online(LoginDraft draft) {
    return LoginStartResult._(draft: draft);
  }

  factory LoginStartResult.offline(AuthenticatedSession session) {
    return LoginStartResult._(offlineSession: session);
  }

  final LoginDraft? draft;
  final AuthenticatedSession? offlineSession;

  bool get isOffline => offlineSession != null;
}

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _responseText(dynamic data) {
  if (data == null) return '';
  if (data is String) return data.trim();
  return jsonEncode(data);
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return null;
}

List<Map<String, dynamic>> _readMapList(dynamic value) {
  if (value is List) {
    return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key] ?? json[_lowerFirst(key)] ?? json[key.toLowerCase()];
  return value?.toString() ?? '';
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key] ?? json[_lowerFirst(key)] ?? json[key.toLowerCase()];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key] ?? json[_lowerFirst(key)] ?? json[key.toLowerCase()];
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase() ?? '';
  return text == 'true' || text == '1';
}

String _readAnyString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _readString(json, key);
    if (value.isNotEmpty) return value;
  }
  return '';
}

int _readAnyInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _readInt(json, key);
    if (value != 0) return value;
  }
  return 0;
}

String _lowerFirst(String key) {
  if (key.isEmpty) return key;
  return key[0].toLowerCase() + key.substring(1);
}

String _dbString(Object? value) => value?.toString() ?? '';

int _dbInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _dbBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase() ?? '';
  return text == 'true' || text == '1';
}

Map<String, dynamic> _decodeObject(String text) {
  if (text.trim().isEmpty) return {};
  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {};
}

String _formatHumanDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _formatCompactDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}

DateTime? _parseHumanDate(String value) {
  if (value.length < 16) return null;
  try {
    return DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
      int.parse(value.substring(11, 13)),
      int.parse(value.substring(14, 16)),
    );
  } on Object {
    return null;
  }
}

DateTime? _parseCompactDate(String value) {
  if (value.length < 17) return null;
  try {
    return DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(4, 6)),
      int.parse(value.substring(6, 8)),
      int.parse(value.substring(9, 11)),
      int.parse(value.substring(12, 14)),
      int.parse(value.substring(15, 17)),
    );
  } on Object {
    return null;
  }
}
