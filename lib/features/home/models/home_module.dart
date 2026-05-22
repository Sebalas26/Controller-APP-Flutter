import 'package:flutter/material.dart';

class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.icon,
    required this.legacyRoute,
    this.primary = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final String legacyRoute;
  final bool primary;
}

const appModules = [
  AppModule(
    id: 'vender',
    title: 'Vender',
    icon: Icons.point_of_sale_outlined,
    legacyRoute:
        '.vistas.admision_mensajeria.admision_automatica.AdmisionAutomaticaViewPager',
    primary: true,
  ),
  AppModule(
    id: 'entregar',
    title: 'Entregar',
    icon: Icons.local_shipping_outlined,
    legacyRoute: '.vistas.explorador.mensajeria.ExploradorEntregasMensajeria',
    primary: true,
  ),
  AppModule(
    id: 'recoger',
    title: 'Recoger',
    icon: Icons.inventory_2_outlined,
    legacyRoute: '.vistas.recogidas.RecogidasGestionReservaActivity',
    primary: true,
  ),
  AppModule(
    id: 'asignar',
    title: 'Asignar envios',
    icon: Icons.assignment_ind_outlined,
    legacyRoute: '.features.asignacionguias.ui.AsignacionGuiasActivity',
  ),
  AppModule(
    id: 'mis_pagos',
    title: 'Mis Pagos',
    icon: Icons.payments_outlined,
    legacyRoute:
        'interrapidisimo.controllerapp.sistemas_de_pago.mis_pagos.presentation.MisPagosActivity',
  ),
  AppModule(
    id: 'estado_cuenta',
    title: 'Estado Cuenta',
    icon: Icons.account_balance_wallet_outlined,
    legacyRoute: '.features.estadoCuenta.ui.EstadoCuentaActivity',
  ),
  AppModule(
    id: 'mis_mensajeros',
    title: 'Mis Mensajeros',
    icon: Icons.supervisor_account_outlined,
    legacyRoute: '.features.mismensajeros.presentation.MisMensajerosActivity',
  ),
  AppModule(
    id: 'yaap',
    title: 'Yaap',
    icon: Icons.verified_user_outlined,
    legacyRoute: '.features.bloques.ui.yaap.ValidacionYaapActivity',
  ),
  AppModule(
    id: 'reimprimir',
    title: 'Reimprimir',
    icon: Icons.print_outlined,
    legacyRoute: '.vistas.reimpresion.ReimpresionActivityKT',
  ),
  AppModule(
    id: 'anular',
    title: 'Anular',
    icon: Icons.block_outlined,
    legacyRoute: '.vistas.anulaciones.AnularEnvioActivity',
  ),
  AppModule(
    id: 'bloques',
    title: 'Bloques',
    icon: Icons.all_inbox_outlined,
    legacyRoute: '.features.bloques.ui.BlocksMainActivity',
  ),
  AppModule(
    id: 'enrutamiento',
    title: 'Enrutamiento',
    icon: Icons.alt_route_outlined,
    legacyRoute: '.features.entregas.ui.enrutamiento.EnrutamientoGuiasActivity',
  ),
  AppModule(
    id: 'auditoria',
    title: 'Auditoria',
    icon: Icons.fact_check_outlined,
    legacyRoute: '.vistas.auditoria_pesos.AuditoriaPesosActivity',
  ),
  AppModule(
    id: 'prepago',
    title: 'PrePago',
    icon: Icons.credit_card_outlined,
    legacyRoute: '.vistas.prepago.PrePagoActivity',
  ),
];
