import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'widgets/home_support_widgets.dart';

class NativeRoutesPage extends StatelessWidget {
  const NativeRoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas Android')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FormCard(
            children: [
              DashboardTile(
                title: 'Activities',
                value: '57',
                icon: Icons.phone_android_outlined,
              ),
              DashboardTile(
                title: 'Layouts XML',
                value: '329',
                icon: Icons.dashboard_customize_outlined,
              ),
              DashboardTile(
                title: 'Drawables',
                value: '720',
                icon: Icons.image_outlined,
              ),
              DashboardTile(
                title: 'Java/Kotlin',
                value: '1564',
                icon: Icons.code_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...nativeActivityRoutes.map(
            (route) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray300),
                ),
                child: ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: Text(route.shortName),
                  subtitle: Text(
                    route.path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NativeActivityRoute {
  const NativeActivityRoute(this.path);

  final String path;

  String get shortName {
    final parts = path.split('.');
    return parts.isEmpty ? path : parts.last;
  }
}

const nativeActivityRoutes = [
  NativeActivityRoute('.features.entregas.ui.enrutamiento.InterMapActivity'),
  NativeActivityRoute('.features.bloques.ui.DatosDomiciliarioInterAppActivity'),
  NativeActivityRoute('.features.bloques.ui.BlocksMainActivity'),
  NativeActivityRoute(
    '.features.entregas.ui.enrutamiento.EnrutamientoGuiasActivity',
  ),
  NativeActivityRoute('.features.estadoCuenta.ui.DetalleEntregasActivity'),
  NativeActivityRoute('.features.estadoCuenta.ui.DetalleEstadoCuentaActivity'),
  NativeActivityRoute('.features.estadoCuenta.ui.EstadoCuentaActivity'),
  NativeActivityRoute(
    '.features.mismensajeros.presentation.MisMensajerosActivity',
  ),
  NativeActivityRoute('.features.login.presentation.ChangePasswordActivity'),
  NativeActivityRoute('.features.asignacionguias.ui.GuiasAnterioresActivity'),
  NativeActivityRoute('.features.asignacionguias.ui.AsignacionGuiasActivity'),
  NativeActivityRoute('.vistas.entregas.firma.CapturaFirmaActivity'),
  NativeActivityRoute('.features.bloques.ui.yaap.EntregasYaapActivity'),
  NativeActivityRoute('.features.bloques.ui.yaap.ValidacionYaapActivity'),
  NativeActivityRoute('.vistas.entregas.prepago.PrePagoEntregasActivity'),
  NativeActivityRoute('.vistas.prepago.PrePagoActivity'),
  NativeActivityRoute('.vistas.auditoria_pesos.AuditoriaPesosActivity'),
  NativeActivityRoute('.vistas.home.VideoBannerActivity'),
  NativeActivityRoute(
    '.vistas.entregas.multientrega.FirmaSelloMultientregaActivity',
  ),
  NativeActivityRoute('.vistas.entregas.multientrega.MultientregaActivity'),
  NativeActivityRoute('.vistas.venta.pagoqr.VentaPagoQRActivity'),
  NativeActivityRoute('.vistas.anulaciones.AnularEnvioActivity'),
  NativeActivityRoute('.vistas.medios_pago.MediosPagoActivity'),
  NativeActivityRoute('.features.login.ui.LoginActivity'),
  NativeActivityRoute('.vistas.NavigationActivity'),
  NativeActivityRoute('.vistas.gestion_auditor.DevolucionRatificadaAuditor'),
  NativeActivityRoute(
    '.vistas.explorador.mensajeria.ExploradorEntregasMensajeria',
  ),
  NativeActivityRoute(
    '.vistas.explorador.mensajeria.ExploradorEntregasMensajeriaOffline',
  ),
  NativeActivityRoute('.vistas.explorador.masivos.ExploradorEntregasMasivos'),
  NativeActivityRoute('.vistas.explorador.auditor.ExploradorEntregasAuditor'),
  NativeActivityRoute('.vistas.gestion_mensajero.DevolucionMensajero'),
  NativeActivityRoute('.vistas.gestion_mensajero.DevolucionMensajeroOffline'),
  NativeActivityRoute('.vistas.gestion_masivos.DevolucionMasivos'),
  NativeActivityRoute(
    '.vistas.admision_mensajeria.admision_impresion.AdmisionImpresion',
  ),
  NativeActivityRoute('.vistas.cierre_caja.CierreCajaActivity'),
  NativeActivityRoute('.vistas.reporte_cajas.ReporteCajas'),
  NativeActivityRoute('.comun.utils.CaptureActivityPortrait'),
  NativeActivityRoute(
    '.vistas.admision_mensajeria.admision_automatica.AdmisionAutomaticaViewPager',
  ),
  NativeActivityRoute(
    '.vistas.sincronizacion_offline.SincronizacionAdmisionesOffline',
  ),
  NativeActivityRoute('.vistas.explorador.Explorador'),
  NativeActivityRoute('.vistas.gestion_auditor.EntregaMaestraAuditor'),
  NativeActivityRoute('.vistas.gestion_auditor.EntregaCorrectaAuditor'),
  NativeActivityRoute('.vistas.gestion_mensajero.EntregaCorrectaMensajero'),
  NativeActivityRoute('.vistas.gestion_masivos.EntregaCorrectaMasivos'),
  NativeActivityRoute('.vistas.gestion_masivos.IntentoEntregaMasivos'),
  NativeActivityRoute('.vistas.recogidas.RecogidasGestionReservaActivity'),
  NativeActivityRoute('.vistas.entregas.mensajero.DevolucionProblematica'),
  NativeActivityRoute('.vistas.preenvios.PreenviosMainActivity'),
  NativeActivityRoute('.vistas.admision_mensajeria.AdmisionResumenVenta'),
  NativeActivityRoute('.vistas.admision_mensajeria.AdmisionVentaExitosaZebra'),
  NativeActivityRoute('.vistas.reportes.ReporteDiarioActivity'),
  NativeActivityRoute('.vistas.reimpresion.ReimpresionActivityKT'),
  NativeActivityRoute(
    '.vistas.firma_virtual.CapturaFirmaVirtualEntregaCorrecta',
  ),
  NativeActivityRoute(
    '.vistas.firma_virtual.CapturaFirmaVirtualEntregaCorrectaOffline',
  ),
  NativeActivityRoute(
    'interrapidisimo.controllerapp.sistemas_de_pago.mis_pagos.presentation.MisPagosActivity',
  ),
  NativeActivityRoute(
    'interrapidisimo.controllerapp.sistemas_de_pago.link_de_pago.presentation.LinkdePagoModuleActivity',
  ),
  NativeActivityRoute(
    '.features.notificationcenter.ui.notifications.NotificationListActivity',
  ),
];
