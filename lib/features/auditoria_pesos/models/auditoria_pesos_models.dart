class AuditoriaPesosException implements Exception {
  const AuditoriaPesosException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum AuditoriaPesosTab { auditoria, reportes }

enum AuditoriaWeightMode { bascula, volumetrico }

class AuditoriaGuide {
  const AuditoriaGuide({
    required this.raw,
    required this.numeroGuia,
    required this.idCiudadOrigenSistema,
    required this.nombreCiudadOrigenSistema,
    required this.idCiudadDestinoSistema,
    required this.nombreCiudadDestinoSistema,
    required this.idRemitente,
    required this.idDestinatario,
    required this.idCentroServicioOrigen,
    required this.idEstadoGuia,
    required this.idTipoEntrega,
    required this.idServicio,
    required this.pagoEnCasa,
    required this.formaPago,
    required this.fechaAdmisionSistema,
    required this.valorAdmisionSistema,
    required this.valorComercialSistema,
    required this.valorTotalSistema,
    required this.pesoSistema,
    required this.pesoVolumetricoSistema,
    required this.pesoEsVolumetricoSistema,
    required this.largoSistema,
    required this.anchoSistema,
    required this.altoSistema,
    required this.planillado,
    this.facturada,
    this.idCliente,
    this.idContrato,
    this.idAdmision,
  });

  final Map<String, dynamic> raw;
  final String numeroGuia;
  final String idCiudadOrigenSistema;
  final String nombreCiudadOrigenSistema;
  final String idCiudadDestinoSistema;
  final String nombreCiudadDestinoSistema;
  final String idRemitente;
  final String idDestinatario;
  final int idCentroServicioOrigen;
  final int idEstadoGuia;
  final String idTipoEntrega;
  final int idServicio;
  final int pagoEnCasa;
  final String formaPago;
  final String fechaAdmisionSistema;
  final double valorAdmisionSistema;
  final double valorComercialSistema;
  final double valorTotalSistema;
  final double pesoSistema;
  final double pesoVolumetricoSistema;
  final int pesoEsVolumetricoSistema;
  final double largoSistema;
  final double anchoSistema;
  final double altoSistema;
  final int planillado;
  final int? facturada;
  final String? idCliente;
  final String? idContrato;
  final String? idAdmision;

  double get pesoAuditableSistema {
    if (pesoEsVolumetricoSistema == 1) return pesoVolumetricoSistema;
    return pesoSistema;
  }

  factory AuditoriaGuide.fromJson(Map<String, dynamic> json) {
    return AuditoriaGuide(
      raw: Map<String, dynamic>.from(json),
      numeroGuia: _readString(json, 'NumeroGuia'),
      idCiudadOrigenSistema: _readString(json, 'IdCiudadOrigenSistema'),
      nombreCiudadOrigenSistema: _readString(json, 'NombreCiudadOrigenSistema'),
      idCiudadDestinoSistema: _readString(json, 'IdCiudadDestinoSistema'),
      nombreCiudadDestinoSistema: _readString(
        json,
        'NombreCiudadDestinoSistema',
      ),
      idRemitente: _readString(json, 'IdRemitente'),
      idDestinatario: _readString(json, 'IdDestinatario'),
      idCentroServicioOrigen: _readInt(json, 'IdCentroServicioOrigen'),
      idEstadoGuia: _readInt(json, 'IdEstadoGuia'),
      idTipoEntrega: _readString(json, 'IdTipoEntrega'),
      idServicio: _readInt(json, 'IdServicio'),
      pagoEnCasa: _readInt(json, 'PagoEnCasa'),
      formaPago: _readString(json, 'FormaPago'),
      fechaAdmisionSistema: _readString(json, 'FechaAdmisionSistema'),
      valorAdmisionSistema: _readDouble(json, 'ValorAdmisionSistema'),
      valorComercialSistema: _readDouble(json, 'ValorComercialSistema'),
      valorTotalSistema: _readDouble(json, 'ValorTotalSistema'),
      pesoSistema: _readDouble(json, 'PesoSistema'),
      pesoVolumetricoSistema: _readDouble(json, 'PesoVolumetricoSistema'),
      pesoEsVolumetricoSistema: _readInt(json, 'PesoEsVolumetricoSistema'),
      largoSistema: _readDouble(json, 'LargoSistema'),
      anchoSistema: _readDouble(json, 'AnchoSistema'),
      altoSistema: _readDouble(json, 'AltoSistema'),
      planillado: _readInt(json, 'Planillado'),
      facturada: _readNullableInt(json, 'Facturada'),
      idCliente: _readNullableString(json, 'IdCliente'),
      idContrato: _readNullableString(json, 'IdContrato'),
      idAdmision: _readNullableString(json, 'IdAdmision'),
    );
  }
}

class AuditoriaPhoto {
  const AuditoriaPhoto({
    required this.title,
    required this.position,
    this.name = '',
    this.size = 0,
    this.type = '',
    this.base64File = '',
    this.numeroGuia = '',
  });

  final String title;
  final int position;
  final String name;
  final int size;
  final String type;
  final String base64File;
  final String numeroGuia;

  bool get hasImage => base64File.trim().isNotEmpty;

  AuditoriaPhoto copyWith({
    String? name,
    int? size,
    String? type,
    String? base64File,
    String? numeroGuia,
  }) {
    return AuditoriaPhoto(
      title: title,
      position: position,
      name: name ?? this.name,
      size: size ?? this.size,
      type: type ?? this.type,
      base64File: base64File ?? this.base64File,
      numeroGuia: numeroGuia ?? this.numeroGuia,
    );
  }

  AuditoriaPhoto cleared() {
    return AuditoriaPhoto(title: title, position: position);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'type': type,
      'base64File': base64File,
      'numeroGuia': numeroGuia,
    };
  }
}

class AuditoriaSaveResult {
  const AuditoriaSaveResult({required this.message});

  final String message;

  factory AuditoriaSaveResult.fromJson(Map<String, dynamic> json) {
    return AuditoriaSaveResult(message: _readString(json, 'Mensaje'));
  }
}

class AuditoriaPhotoUploadResult {
  const AuditoriaPhotoUploadResult({
    required this.success,
    required this.nameFile,
    required this.message,
  });

  final int success;
  final String nameFile;
  final String message;

  factory AuditoriaPhotoUploadResult.fromJson(Map<String, dynamic> json) {
    return AuditoriaPhotoUploadResult(
      success: _readInt(json, 'success'),
      nameFile: _readString(json, 'namefile'),
      message: _readString(json, 'message'),
    );
  }
}

class AuditoriaReportSummary {
  const AuditoriaReportSummary({
    required this.idAuditor,
    required this.nombreAuditor,
    required this.idCentroServicioAuditor,
    required this.cantidadAuditorias,
    required this.cantidadAprobadas,
    required this.cantidadRechazadas,
    required this.cantidadPorAprobar,
    required this.cantidadNoAplican,
    required this.totalComision,
    required this.totalGanancia,
    required this.nombreRepresentanteLegal,
    this.fechaInicial = '',
    this.fechaFinal = '',
  });

  final int idAuditor;
  final String nombreAuditor;
  final int idCentroServicioAuditor;
  final int cantidadAuditorias;
  final int cantidadAprobadas;
  final int cantidadRechazadas;
  final int cantidadPorAprobar;
  final int cantidadNoAplican;
  final int totalComision;
  final int totalGanancia;
  final String nombreRepresentanteLegal;
  final String fechaInicial;
  final String fechaFinal;

  AuditoriaReportSummary copyWith({String? fechaInicial, String? fechaFinal}) {
    return AuditoriaReportSummary(
      idAuditor: idAuditor,
      nombreAuditor: nombreAuditor,
      idCentroServicioAuditor: idCentroServicioAuditor,
      cantidadAuditorias: cantidadAuditorias,
      cantidadAprobadas: cantidadAprobadas,
      cantidadRechazadas: cantidadRechazadas,
      cantidadPorAprobar: cantidadPorAprobar,
      cantidadNoAplican: cantidadNoAplican,
      totalComision: totalComision,
      totalGanancia: totalGanancia,
      nombreRepresentanteLegal: nombreRepresentanteLegal,
      fechaInicial: fechaInicial ?? this.fechaInicial,
      fechaFinal: fechaFinal ?? this.fechaFinal,
    );
  }

  factory AuditoriaReportSummary.fromJson(Map<String, dynamic> json) {
    return AuditoriaReportSummary(
      idAuditor: _readInt(json, 'IdAuditor'),
      nombreAuditor: _readString(json, 'NombreAuditor'),
      idCentroServicioAuditor: _readInt(json, 'IdCentroServicioAuditor'),
      cantidadAuditorias: _readInt(json, 'CantidadAuditorias'),
      cantidadAprobadas: _readInt(json, 'CantidadAprobadas'),
      cantidadRechazadas: _readInt(json, 'CantidadRechazadas'),
      cantidadPorAprobar: _readInt(json, 'CantidadPorAprobar'),
      cantidadNoAplican: _readInt(json, 'CantidadNoAplican'),
      totalComision: _readInt(json, 'TotalComision'),
      totalGanancia: _readInt(json, 'TotalGanancia'),
      nombreRepresentanteLegal: _readString(json, 'NombreRepresentanteLegal'),
    );
  }
}

class AuditoriaReportDetail {
  const AuditoriaReportDetail({
    required this.idAuditoria,
    required this.nombreAuditor,
    required this.idCentroServicioAuditor,
    required this.numeroGuia,
    required this.fechaAuditoria,
    required this.fechaGestion,
    required this.estadoAuditoria,
    required this.valorTotal,
    required this.valorComision,
    required this.observacion,
  });

  final int idAuditoria;
  final String nombreAuditor;
  final int idCentroServicioAuditor;
  final String numeroGuia;
  final String fechaAuditoria;
  final String fechaGestion;
  final String estadoAuditoria;
  final int valorTotal;
  final int valorComision;
  final String observacion;

  factory AuditoriaReportDetail.fromJson(Map<String, dynamic> json) {
    return AuditoriaReportDetail(
      idAuditoria: _readInt(json, 'IdAuditoria'),
      nombreAuditor: _readString(json, 'NombreAuditor'),
      idCentroServicioAuditor: _readInt(json, 'IdCentroServicioAuditor'),
      numeroGuia: _readString(json, 'NumeroGuia'),
      fechaAuditoria: _readString(json, 'FechaAuditoria'),
      fechaGestion: _readString(json, 'FechaGestion'),
      estadoAuditoria: _readString(json, 'EstadoAuditoria'),
      valorTotal: _readInt(json, 'ValorTotal'),
      valorComision: _readInt(json, 'ValorComision'),
      observacion: _readString(json, 'Observacion'),
    );
  }
}

String auditoriaFormatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value?.toString().trim() ?? '';
}

String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readNullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

double _readDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0;
}
