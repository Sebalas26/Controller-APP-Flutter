class AnularGuiaException implements Exception {
  const AnularGuiaException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum AnularGuiaStep {
  informacion,
  guia,
  confirmarNumero,
  cambiarNumero,
  confirmarCodigo,
}

class AnularGuide {
  const AnularGuide({
    required this.numeroGuia,
    required this.telefonoRemitente,
    required this.telefonoDestinatario,
    required this.nombreRemitente,
    required this.apellidoRemitente,
    required this.nombreDestinatario,
    required this.apellidoDestinatario,
    required this.idCentroServicioOrigen,
    required this.fechaAdmision,
    required this.estadoGuia,
  });

  static const estadoAdmitida = 1;

  final int numeroGuia;
  final String telefonoRemitente;
  final String telefonoDestinatario;
  final String nombreRemitente;
  final String apellidoRemitente;
  final String nombreDestinatario;
  final String apellidoDestinatario;
  final int idCentroServicioOrigen;
  final String fechaAdmision;
  final int estadoGuia;

  String get nombreCompletoRemitente {
    return [
      nombreRemitente,
      apellidoRemitente,
    ].where((value) => value.trim().isNotEmpty).join(' ').trim();
  }

  String get nombreCompletoDestinatario {
    return [
      nombreDestinatario,
      apellidoDestinatario,
    ].where((value) => value.trim().isNotEmpty).join(' ').trim();
  }

  factory AnularGuide.fromJson(Map<String, dynamic> json) {
    final remitente = anularAsMap(json['Remitente']);
    final destinatario = anularAsMap(json['Destinatario']);
    return AnularGuide(
      numeroGuia: anularReadInt(json, 'NumeroGuia'),
      telefonoRemitente: anularReadString(remitente, 'Telefono'),
      telefonoDestinatario: anularReadString(destinatario, 'Telefono'),
      nombreRemitente: anularReadString(remitente, 'Nombre'),
      apellidoRemitente: anularReadString(remitente, 'Apellido1'),
      nombreDestinatario: anularReadString(destinatario, 'Nombre'),
      apellidoDestinatario: anularReadString(destinatario, 'Apellido1'),
      idCentroServicioOrigen: anularReadInt(json, 'IdCentroServicioOrigen'),
      fechaAdmision: anularReadString(json, 'FechaAdmision'),
      estadoGuia: anularReadInt(json, 'EstadoGuia'),
    );
  }
}

class AnulacionReason {
  const AnulacionReason({required this.id, required this.description});

  final int id;
  final String description;

  factory AnulacionReason.fromJson(Map<String, dynamic> json) {
    return AnulacionReason(
      id: anularReadInt(json, 'IdMotivoAnulacion'),
      description: anularReadString(json, 'Descripcion'),
    );
  }
}

class RepresentativePhone {
  const RepresentativePhone({
    required this.phone,
    required this.serviceCenterId,
  });

  final String phone;
  final int serviceCenterId;

  factory RepresentativePhone.fromJson(Map<String, dynamic> json) {
    return RepresentativePhone(
      phone: anularReadString(json, 'CelularPersonaResponsable'),
      serviceCenterId: anularReadInt(json, 'IdCentroServicio'),
    );
  }
}

class AnularGuideResult {
  const AnularGuideResult({
    required this.numeroGuia,
    required this.guiaExiste,
    required this.fueAnulada,
    required this.mensaje,
  });

  final int numeroGuia;
  final bool guiaExiste;
  final bool fueAnulada;
  final String mensaje;

  factory AnularGuideResult.fromJson(Map<String, dynamic> json) {
    return AnularGuideResult(
      numeroGuia: anularReadInt(json, 'NumeroGuia'),
      guiaExiste: anularReadBool(json, 'GuiaExiste'),
      fueAnulada: anularReadBool(json, 'FueAnulada'),
      mensaje: anularReadString(json, 'Mensaje'),
    );
  }
}

Map<String, dynamic> anularAsMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, child) => MapEntry(key.toString(), child));
  }
  return const {};
}

List<Map<String, dynamic>> anularAsMapList(dynamic value) {
  if (value is List) {
    return value.map(anularAsMap).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

String anularReadString(Map<String, dynamic> json, String key) {
  return (json[key] ?? '').toString().trim();
}

int anularReadInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

bool anularReadBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'si';
}
