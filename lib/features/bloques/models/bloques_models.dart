import 'dart:convert';

class YaapException implements Exception {
  const YaapException(this.message);

  final String message;

  @override
  String toString() => message;
}

class YaapQrIdentity {
  const YaapQrIdentity({required this.document, required this.otp});

  final String document;
  final String otp;
}

class YaapToken {
  const YaapToken({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String idToken;
  final String refreshToken;

  bool get isValid =>
      accessToken.trim().isNotEmpty &&
      idToken.trim().isNotEmpty &&
      refreshToken.trim().isNotEmpty;

  factory YaapToken.fromJson(Map<String, dynamic> json) {
    return YaapToken(
      accessToken: _readAnyString(json, const ['access_token', 'accessToken']),
      idToken: _readAnyString(json, const ['id_token', 'idToken']),
      refreshToken: _readAnyString(json, const [
        'refresh_token',
        'refreshToken',
      ]),
    );
  }
}

class YaapCourier {
  const YaapCourier({
    required this.raw,
    required this.document,
    required this.name,
    required this.photoUrl,
    required this.routeId,
    required this.guideNumbers,
    required this.otp,
  });

  final Map<String, dynamic> raw;
  final String document;
  final String name;
  final String photoUrl;
  final String routeId;
  final List<String> guideNumbers;
  final String otp;

  factory YaapCourier.fromJson(Map<String, dynamic> json, {String otp = ''}) {
    final payload = _asMap(json['data']) ?? json;
    return YaapCourier(
      raw: Map<String, dynamic>.from(payload),
      document: _readAnyString(payload, const [
        'documento',
        'documentoMensajero',
        'identificacion',
      ]),
      name: _readAnyString(payload, const [
        'nombremensajero',
        'nombreMensajero',
        'nombres',
        'nombre',
      ]),
      photoUrl: _readAnyString(payload, const [
        'rutaimagen',
        'rutaImagen',
        'foto',
        'linkFotoMensajero',
      ]),
      routeId: _readAnyString(payload, const ['idruta', 'idRuta']),
      guideNumbers: _readGuides(payload['listaguias'] ?? payload['listaGuias']),
      otp: otp.isEmpty ? _readAnyString(payload, const ['otp', 'OTP']) : otp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'documento': document,
      'nombremensajero': name,
      'rutaimagen': photoUrl,
      'idruta': routeId,
      'listaguias': guideNumbers.map((guide) => {'idguia': guide}).toList(),
      'otp': otp,
    };
  }
}

class YaapDelivery {
  const YaapDelivery({
    required this.raw,
    required this.guideNumber,
    required this.location,
    required this.locationType,
    required this.locationDetail,
    required this.description,
    required this.weight,
    required this.admissionId,
    required this.stateId,
    this.verified = false,
  });

  final Map<String, dynamic> raw;
  final String guideNumber;
  final int location;
  final int locationType;
  final String locationDetail;
  final String description;
  final double weight;
  final int admissionId;
  final int stateId;
  final bool verified;

  factory YaapDelivery.fromJson(Map<String, dynamic> json) {
    return YaapDelivery(
      raw: Map<String, dynamic>.from(json),
      guideNumber: _readAnyString(json, const ['NumeroGuia', 'numeroGuia']),
      location: _readAnyInt(json, const ['Ubicacion', 'ubicacion']),
      locationType: _readAnyInt(json, const ['TipoUbicacion', 'tipoUbicacion']),
      locationDetail: _readAnyString(json, const [
        'UbicacionDetalle',
        'ubicacionDetalle',
      ]),
      description: _readAnyString(json, const ['Descripcion', 'descripcion']),
      weight: _readAnyDouble(json, const ['Peso', 'peso']),
      admissionId: _readAnyInt(json, const [
        'IdAdmisionMensajeria',
        'idAdmisionMensajeria',
      ]),
      stateId: _readAnyInt(json, const ['IdEstadoGuia', 'idEstadoGuia']),
      verified: _readAnyBool(json, const ['Verificado', 'verified']),
    );
  }

  YaapDelivery copyWith({bool? verified}) {
    return YaapDelivery(
      raw: raw,
      guideNumber: guideNumber,
      location: location,
      locationType: locationType,
      locationDetail: locationDetail,
      description: description,
      weight: weight,
      admissionId: admissionId,
      stateId: stateId,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'NumeroGuia': int.tryParse(guideNumber) ?? guideNumber,
      'Ubicacion': location,
      'TipoUbicacion': locationType,
      'UbicacionDetalle': locationDetail,
      'Descripcion': description,
      'Peso': weight,
      'IdAdmisionMensajeria': admissionId,
      'IdEstadoGuia': stateId,
      'Verificado': verified,
    };
  }
}

class YaapPendingBlock {
  const YaapPendingBlock({
    required this.raw,
    required this.id,
    required this.motherGuideNumber,
    required this.courierDocument,
    required this.courierName,
    required this.assignedUser,
    required this.photoUrl,
    required this.status,
    required this.guideNumbers,
    required this.createdAt,
    required this.endsAt,
  });

  final Map<String, dynamic> raw;
  final int id;
  final String motherGuideNumber;
  final String courierDocument;
  final String courierName;
  final String assignedUser;
  final String photoUrl;
  final String status;
  final List<String> guideNumbers;
  final DateTime? createdAt;
  final DateTime? endsAt;

  factory YaapPendingBlock.fromJson(Map<String, dynamic> json) {
    return YaapPendingBlock(
      raw: Map<String, dynamic>.from(json),
      id: _readAnyInt(json, const ['idBloque', 'id']),
      motherGuideNumber: _readAnyString(json, const [
        'numeroGuiaMadre',
        'numGuiaMadre',
        'NumeroGuiaMadre',
      ]),
      courierDocument: _readAnyString(json, const [
        'documentoMensajero',
        'numDocumento',
      ]),
      courierName: _readAnyString(json, const ['nombreMensajero', 'name']),
      assignedUser: _readAnyString(json, const ['usuarioGestion', 'usuario']),
      photoUrl: _readAnyString(json, const ['linkFotoMensajero', 'foto']),
      status: _readAnyString(json, const ['status', 'estado']),
      guideNumbers: _readGuides(json['guiasBloque'] ?? json['guias']),
      createdAt: _readDate(json['fechaInicioGestion'] ?? json['createdAt']),
      endsAt: _readDate(json['fechaFinGestion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'idBloque': id,
      'numeroGuiaMadre': int.tryParse(motherGuideNumber) ?? motherGuideNumber,
      'documentoMensajero': int.tryParse(courierDocument) ?? courierDocument,
      'nombreMensajero': courierName,
      'usuarioGestion': assignedUser,
      'linkFotoMensajero': photoUrl,
      'status': status,
      'guiasBloque': guideNumbers
          .map((guide) => int.tryParse(guide) ?? guide)
          .toList(),
      'fechaInicioGestion': createdAt?.toIso8601String(),
      'fechaFinGestion': endsAt?.toIso8601String(),
    };
  }
}

class YaapRouteState {
  const YaapRouteState({required this.status, required this.rejectedGuides});

  final String status;
  final List<YaapRejectedGuide> rejectedGuides;

  factory YaapRouteState.fromJson(Map<String, dynamic> json) {
    return YaapRouteState(
      status: _readAnyString(json, const [
        'descripcionEstado',
        'DescripcionEstado',
        'estado',
      ]),
      rejectedGuides: _readMapList(
        json['listaGuias'] ?? json['ListaGuias'],
      ).map(YaapRejectedGuide.fromJson).toList(),
    );
  }
}

class YaapRejectedGuide {
  const YaapRejectedGuide({required this.guideNumber, required this.reason});

  final String guideNumber;
  final String reason;

  factory YaapRejectedGuide.fromJson(Map<String, dynamic> json) {
    return YaapRejectedGuide(
      guideNumber: _readAnyString(json, const ['numeroGuia', 'NumeroGuia']),
      reason: _readAnyString(json, const ['descripcion', 'Descripcion']),
    );
  }
}

class YaapRejectionReason {
  const YaapRejectionReason({required this.id, required this.description});

  static const guideTransportIssueId = 60;

  final int id;
  final String description;

  bool get requiresGuideSelection => id == guideTransportIssueId;

  factory YaapRejectionReason.fromJson(Map<String, dynamic> json) {
    return YaapRejectionReason(
      id: _readAnyInt(json, const ['idCausalRechazo', 'IdCausalRechazo', 'id']),
      description: _readAnyString(json, const [
        'descripcionCausalRechazo',
        'DescripcionCausalRechazo',
        'descripcion',
        'Descripcion',
      ]),
    );
  }
}

Map<String, dynamic>? yaapAsMap(Object? value) => _asMap(value);

List<Map<String, dynamic>> yaapReadMapList(Object? value) =>
    _readMapList(value);

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return decoded.map((key, val) => MapEntry(key.toString(), val));
    }
  }
  return null;
}

List<Map<String, dynamic>> _readMapList(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return _readMapList(decoded);
  }
  if (value is List) {
    return value
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
  return const [];
}

List<String> _readGuides(Object? value) {
  if (value is String) {
    return value
        .split(',')
        .map((guide) => guide.replaceAll(RegExp(r'[^0-9]'), '').trim())
        .where((guide) => guide.isNotEmpty)
        .toList(growable: false);
  }
  if (value is List) {
    return value
        .map((item) {
          final map = _asMap(item);
          if (map != null) {
            return _readAnyString(map, const [
              'idguia',
              'numeroGuia',
              'NumeroGuia',
            ]);
          }
          return item?.toString() ?? '';
        })
        .map((guide) => guide.replaceAll(RegExp(r'[^0-9]'), '').trim())
        .where((guide) => guide.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

String _readAnyString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

int _readAnyInt(Map<String, dynamic> json, List<String> keys) {
  final text = _readAnyString(json, keys);
  if (text.isEmpty) return 0;
  return int.tryParse(text) ?? double.tryParse(text)?.round() ?? 0;
}

double _readAnyDouble(Map<String, dynamic> json, List<String> keys) {
  final text = _readAnyString(json, keys);
  if (text.isEmpty) return 0;
  return double.tryParse(text.replaceAll(',', '.')) ?? 0;
}

bool _readAnyBool(Map<String, dynamic> json, List<String> keys) {
  final text = _readAnyString(json, keys).toLowerCase();
  return text == 'true' || text == '1' || text == 'si';
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
