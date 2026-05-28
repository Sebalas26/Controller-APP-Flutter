import 'package:flutter/material.dart';

class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.icon,
    required this.legacyRoute,
    this.homeTitle,
    this.nativeNames = const [],
    this.primary = false,
    this.showNew = false,
    this.enabled = true,
  });

  final String id;
  final String title;
  final IconData icon;
  final String legacyRoute;
  final String? homeTitle;
  final List<String> nativeNames;
  final bool primary;
  final bool showNew;
  final bool enabled;

  String get homeLabel => homeTitle ?? title;

  bool matchesNativeName(String name) {
    final normalized = normalizeModuleName(name);
    return nativeNames.any((item) => normalizeModuleName(item) == normalized);
  }

  AppModule copyWith({bool? primary, bool? showNew, bool? enabled}) {
    return AppModule(
      id: id,
      title: title,
      icon: icon,
      legacyRoute: legacyRoute,
      homeTitle: homeTitle,
      nativeNames: nativeNames,
      primary: primary ?? this.primary,
      showNew: showNew ?? this.showNew,
      enabled: enabled ?? this.enabled,
    );
  }
}

AppModule? appModuleByNativeName(String name) {
  for (final module in appModules) {
    if (module.matchesNativeName(name)) return module;
  }
  return null;
}

String normalizeModuleName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('�', 'i')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ');
}

const appModules = [
  AppModule(
    id: 'vender',
    title: 'Vender',
    homeTitle: 'Admitir\nEnvíos',
    icon: Icons.inventory_2_outlined,
    legacyRoute:
        '.vistas.admision_mensajeria.admision_automatica.AdmisionAutomaticaViewPager',
    nativeNames: ['Vender'],
    primary: true,
  ),
  AppModule(
    id: 'entregar',
    title: 'Entregar',
    homeTitle: 'Entregas\nAsignadas',
    icon: Icons.near_me_outlined,
    legacyRoute: '.vistas.explorador.mensajeria.ExploradorEntregasMensajeria',
    nativeNames: ['Entregar'],
    primary: true,
  ),
  AppModule(
    id: 'recoger',
    title: 'Recoger',
    homeTitle: 'Hacer\nRecogidas',
    icon: Icons.inventory_2_outlined,
    legacyRoute: '.vistas.recogidas.RecogidasGestionReservaActivity',
    nativeNames: ['Recoger'],
  ),
  AppModule(
    id: 'asignar',
    title: 'Asignar envios',
    homeTitle: 'Asignar\nenvíos',
    icon: Icons.assignment_ind_outlined,
    legacyRoute: '.features.asignacionguias.ui.AsignacionGuiasActivity',
    nativeNames: ['Asignar envíos', 'Asignar envios', 'Asignar env�os'],
  ),
  AppModule(
    id: 'canales',
    title: 'Canales',
    homeTitle: 'Canales de\nVenta',
    icon: Icons.storefront_outlined,
    legacyRoute: 'UrlCanalVenta',
    nativeNames: ['Canales'],
  ),
  AppModule(
    id: 'mis_pagos',
    title: 'Mis Pagos',
    homeTitle: 'Mis\nPagos',
    icon: Icons.payments_outlined,
    legacyRoute:
        'interrapidisimo.controllerapp.sistemas_de_pago.mis_pagos.presentation.MisPagosActivity',
    nativeNames: ['Mis Pagos'],
  ),
  AppModule(
    id: 'estado_cuenta',
    title: 'Estado Cuenta',
    homeTitle: 'Estado\nCuenta',
    icon: Icons.account_balance_wallet_outlined,
    legacyRoute: '.features.estadoCuenta.ui.EstadoCuentaActivity',
    nativeNames: ['Estado Cuenta'],
  ),
  AppModule(
    id: 'mis_mensajeros',
    title: 'Mis Mensajeros',
    homeTitle: 'Consultar\nMensajeros',
    icon: Icons.supervisor_account_outlined,
    legacyRoute: '.features.mismensajeros.presentation.MisMensajerosActivity',
    nativeNames: ['Mis Mensajeros'],
    showNew: true,
  ),
  AppModule(
    id: 'reimprimir',
    title: 'Reimprimir',
    homeTitle: 'Hacer\nImpresión',
    icon: Icons.print_outlined,
    legacyRoute: '.vistas.reimpresion.ReimpresionActivityKT',
    nativeNames: ['Reimprimir'],
  ),
  AppModule(
    id: 'anular',
    title: 'Anular',
    homeTitle: 'Anular\nenvío',
    icon: Icons.cancel_presentation_outlined,
    legacyRoute: '.vistas.anulaciones.AnularEnvioActivity',
    nativeNames: ['Anular'],
    showNew: true,
  ),
  AppModule(
    id: 'bloques',
    title: 'Bloques',
    homeTitle: 'Entregas a\nInterAPP',
    icon: Icons.bolt_outlined,
    legacyRoute: '.features.bloques.ui.BlocksMainActivity',
    nativeNames: ['Yaap', 'Bloques'],
    primary: true,
    showNew: true,
  ),
  AppModule(
    id: 'tarjeta',
    title: 'Tarjeta',
    homeTitle: 'Tarjeta\nComercial',
    icon: Icons.credit_card_outlined,
    legacyRoute: '.vistas.tarjeta_comercial.TabTarjetaFragment',
    nativeNames: ['Tarjeta'],
  ),
  AppModule(
    id: 'enrutamiento',
    title: 'Enrutamiento',
    icon: Icons.alt_route_outlined,
    legacyRoute: '.features.entregas.ui.enrutamiento.EnrutamientoGuiasActivity',
    nativeNames: ['Enrutamiento'],
  ),
  AppModule(
    id: 'auditoria',
    title: 'Auditoria',
    homeTitle: 'Auditoría\nde pesos',
    icon: Icons.fact_check_outlined,
    legacyRoute: '.vistas.auditoria_pesos.AuditoriaPesosActivity',
    nativeNames: ['Auditoria', 'Auditoría'],
  ),
  AppModule(
    id: 'prepago',
    title: 'PrePago',
    icon: Icons.credit_card_outlined,
    legacyRoute: '.vistas.prepago.PrePagoActivity',
    nativeNames: ['PrePago', 'Prepago'],
  ),
];
