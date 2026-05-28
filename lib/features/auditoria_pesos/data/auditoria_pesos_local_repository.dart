import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../login/login.dart';
import '../models/auditoria_pesos_models.dart';

class AuditoriaPesosLocalRepository {
  AuditoriaPesosLocalRepository({ControllerLocalDatabase? database})
    : _database = database ?? ControllerLocalDatabase();

  final ControllerLocalDatabase _database;

  Future<int> pesoMinimoVolumetrico() async {
    final value = await _database.frameworkParameter('PesoMinVolumetrico');
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0) return parsed;
    return 40;
  }

  Future<File> guardarReporteDetallado({
    required AuditoriaReportSummary? resumen,
    required List<AuditoriaReportDetail> detalle,
    required String fechaInicial,
    required String fechaFinal,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final reportsDirectory = Directory(path.join(directory.path, 'reportes'));
    if (!await reportsDirectory.exists()) {
      await reportsDirectory.create(recursive: true);
    }
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final file = File(
      path.join(reportsDirectory.path, 'auditoria_pesos_$timestamp.csv'),
    );
    final buffer = StringBuffer()
      ..writeln('AUDITORIA DE PESOS')
      ..writeln('Fecha inicial,$fechaInicial')
      ..writeln('Fecha final,$fechaFinal');

    if (resumen != null) {
      buffer
        ..writeln('Cantidad de auditorias,${resumen.cantidadAuditorias}')
        ..writeln('Auditorias aprobadas,${resumen.cantidadAprobadas}')
        ..writeln('Auditorias rechazadas,${resumen.cantidadRechazadas}')
        ..writeln('Auditorias por aprobar,${resumen.cantidadPorAprobar}')
        ..writeln('Reliquidaciones no aplican,${resumen.cantidadNoAplican}')
        ..writeln('Valor total,${resumen.totalComision}')
        ..writeln('Valor ganancia,${resumen.totalGanancia}');
    }

    buffer
      ..writeln()
      ..writeln(
        'Auditoria,Auditor,Centro servicio,Guia,Fecha auditoria,Fecha gestion,Estado,Valor total,Valor comision,Observacion',
      );
    for (final item in detalle) {
      buffer.writeln(
        [
          item.idAuditoria,
          item.nombreAuditor,
          item.idCentroServicioAuditor,
          item.numeroGuia,
          item.fechaAuditoria,
          item.fechaGestion,
          item.estadoAuditoria,
          item.valorTotal,
          item.valorComision,
          item.observacion,
        ].map(_csv).join(','),
      );
    }

    await file.writeAsString(buffer.toString());
    return file;
  }
}

String _csv(Object? value) {
  final text = (value ?? '').toString();
  if (!text.contains(',') && !text.contains('"') && !text.contains('\n')) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}
