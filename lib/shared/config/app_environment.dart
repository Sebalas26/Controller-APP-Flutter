import '../network/controller_api_config.dart';

enum AppEnvironment { pruebas, qa, produccion }

extension AppEnvironmentText on AppEnvironment {
  String get label {
    switch (this) {
      case AppEnvironment.pruebas:
        return 'Pruebas';
      case AppEnvironment.qa:
        return 'QA';
      case AppEnvironment.produccion:
        return 'Produccion';
    }
  }

  String get appName {
    switch (this) {
      case AppEnvironment.pruebas:
        return 'Controller App - Pruebas';
      case AppEnvironment.qa:
        return 'Controller App - QA';
      case AppEnvironment.produccion:
        return 'Controller App';
    }
  }
}

class EnvironmentConfig {
  const EnvironmentConfig({required this.environment, required this.urls});

  final AppEnvironment environment;
  final List<String> urls;

  String get recogidas => urls[0];
  String get controller => urls[1];
  String get autenticacion => urls[2];
  String get raps => urls[3];
  String get serviciosInter => urls[5];
  String get preenvio => urls[6];
  String get georreferenciacion => urls[9];
  String get pruebaEntregaAws => urls[10];
  String get pruebaEntregaToken => urls[11];
  String get productos => urls[12];
  String get mediosPagoLegacy => urls[13];
  String get loginIntegracion => urls[14];
  String get auditoriaPesos => urls[15];
  String get auditoriaPesosAuth => urls[16];
  String get prepago => urls[17];
  String get listaRestrictiva => urls[18];
  String get mensajeTexto => urls[19];
  String get admisionOffline => urls[21];
  String get serviciosAgiles => urls[22];
  String get yaap => urls[23];
  String get mediosPago => urls[24];
  String get apoyos => urls[25];
  String get asignacionGuias => urls[26];
  String get encripcion => urls[27];
  String get torreNotificaciones => urls[28];
  String get mediosPagoOnPremise => urls[30];
  String get geoDireccion => urls[31];
  String get geoRefToken => urls[32];
  String get armadoBloques => urls[33];
  String get entregaBloque => urls[34];

  String get syncFilesBaseUrl {
    switch (environment) {
      case AppEnvironment.pruebas:
        return 'https://sftp-controller-pruebas.s3.us-east-1.amazonaws.com/';
      case AppEnvironment.qa:
        return 'https://sftp-controller-qa.s3.us-east-1.amazonaws.com/';
      case AppEnvironment.produccion:
        return 'https://sftp-controller.s3.us-east-1.amazonaws.com/';
    }
  }

  String get healthUrl {
    switch (environment) {
      case AppEnvironment.pruebas:
        return 'https://apitesting.interrapidisimo.co/AdmisionesOffline/health';
      case AppEnvironment.qa:
        return 'https://qawww3.interrapidisimo.co/AdmisionesOffline/health';
      case AppEnvironment.produccion:
        return 'https://www3.interrapidisimo.com/AdmisionesOffline/health';
    }
  }

  String trackingUrl(String guideNumber) {
    switch (environment) {
      case AppEnvironment.pruebas:
        return 'https://apitesting.interrapidisimo.co/SitioSiguetuEnvioPruebas/shipment/$guideNumber';
      case AppEnvironment.qa:
        return 'https://qawww3.interrapidisimo.co:8082/SiguetuEnvioQA/shipment/$guideNumber';
      case AppEnvironment.produccion:
        return 'https://www3.interrapidisimo.com/SiguetuEnvio/shipment/$guideNumber';
    }
  }

  ControllerApiConfig toApiConfig() {
    return ControllerApiConfig(
      label: environment.label,
      controllerBaseUrl: controller,
      authenticationBaseUrl: autenticacion,
      loginIntegrationBaseUrl: loginIntegracion,
      syncFilesBaseUrl: syncFilesBaseUrl,
      serviciosInterBaseUrl: serviciosInter,
      serviciosAgilesBaseUrl: serviciosAgiles,
      yaapBaseUrl: yaap,
      preenvioBaseUrl: preenvio,
      geoDireccionBaseUrl: geoDireccion,
      geoRefTokenBaseUrl: geoRefToken,
      admisionOfflineBaseUrl: admisionOffline,
      deliveryProofBaseUrl: pruebaEntregaAws,
      deliveryProofTokenBaseUrl: pruebaEntregaToken,
      armadoBloquesBaseUrl: armadoBloques,
      entregaBloqueBaseUrl: entregaBloque,
      auditoriaPesosBaseUrl: auditoriaPesos,
      auditoriaAuthBaseUrl: auditoriaPesosAuth,
      mensajeTextoBaseUrl: mensajeTexto,
    );
  }

  static EnvironmentConfig of(AppEnvironment environment) {
    return EnvironmentConfig(
      environment: environment,
      urls: _environmentUrls[environment]!,
    );
  }

  static const Map<AppEnvironment, List<String>> _environmentUrls = {
    AppEnvironment.pruebas: [
      'https://apitesting.interrapidisimo.co/ftcambios/ApiRecogidasPruebas/api/',
      'https://apitesting.interrapidisimo.co/ftRezagos/apiControllerpruebas/api/',
      'https://apitesting.interrapidisimo.co/FtMisMensajeros/apiSeguridadPruebas/api/',
      'https://apitesting.interrapidisimo.co/ApiRapsPruebas/api/',
      'https://apitesting.interrapidisimo.co/ApiNegocioPruebas/api/parametrosgeneralesformatos/',
      'https://apitesting.interrapidisimo.co/FtAppAgencias012/ApiServinterPruebas/api/',
      'https://apitesting.interrapidisimo.co/ftGeoManual/ApiPreEnviosPruebas/api/',
      'https://oyu32ms0qc.execute-api.us-east-1.amazonaws.com/Desarrollo/apilambdausuariocuentaget',
      'https://qmlnwyik2b.execute-api.us-east-1.amazonaws.com/Desarrollo/autorizador',
      'https://apitesting.interrapidisimo.co/ApiIntegracionesPruebas/api/',
      'https://79bfuqxgpi.execute-api.us-east-1.amazonaws.com/desarrollo/',
      'https://6k7au4f1n3.execute-api.us-east-1.amazonaws.com/Desarrollo/',
      'https://apitesting.interrapidisimo.co/FtAppAgencias012/apiProductosPruebasTran/api/',
      'https://apitesting.interrapidisimo.co/FtMediosPago/ApiMedioPagoPruebas/api/',
      'https://apitesting.interrapidisimo.co/ApiLogin/api/',
      'https://k10bpj0uqe.execute-api.us-east-1.amazonaws.com/Desarrollo/',
      'https://jqxbwc8uu4.execute-api.us-east-1.amazonaws.com/Desarrollo/',
      'https://apiinterpaydev.interrapidisimo.co/api/Seguridad/',
      'https://f3hud8izmu.us-east-1.awsapprunner.com/api/',
      'https://apitesting.interrapidisimo.co/ServicioGestionNotificaciones/api/',
      'https://apitesting.interrapidisimo.co/ftprepago/ApiControllerPruebas/api/',
      'https://apitesting.interrapidisimo.co/AdmisionesOffline/api/',
      'https://apitesting.interrapidisimo.co/FTServiciosAgiles/apiContingenciasPruebas/api/',
      'https://servicios-interapp-dev.interrapidisimo.co/Desarrollo/api/integrations/',
      'https://nejmpfomnf.execute-api.us-east-1.amazonaws.com/api/',
      'https://apitesting.interrapidisimo.co/ftmismensajeros/ApiCanalVentas/api/',
      'https://apitesting.interrapidisimo.co/ftmismensajeros/ApiPruebaEntregaPruebas/api/',
      'https://apitesting.interrapidisimo.co/ApiEncripcionPruebas/api/',
      'https://apitorrenotificaciones-dev.interrapidisimo.co/api/',
      'https://ota2sfziul.execute-api.us-east-1.amazonaws.com/QA/',
      'https://apitesting.interrapidisimo.co/ApiMediosPagoOnPremise/api/MediosPago/',
      'https://pfq6hcwfr8.execute-api.us-east-1.amazonaws.com/api/',
      'https://elq350nbbc.execute-api.us-east-1.amazonaws.com/Desarrollo/',
      'https://apitesting.interrapidisimo.co/FTServiciosAgiles/apiControllerPruebas/api/',
      'https://apitesting.interrapidisimo.co/ApiGestionEntregaBloque/api/v1/',
    ],
    AppEnvironment.qa: [
      'https://qawww3.interrapidisimo.co/ApiRecogidasQA/api/',
      'https://qawww3.interrapidisimo.co/ApicontrollerQA/api/',
      'https://qawww3.interrapidisimo.co/SeguridadApiwafQA/api/',
      'https://qawww3.interrapidisimo.co:90/ApiRaps/api/',
      'https://qapos.interrapidisimo.co/ApiNegocioQA/api/parametrosgeneralesformatos',
      'https://qawww3.interrapidisimo.co/ApiServInterQA/api/',
      'https://qawww3.interrapidisimo.co/ApiPreenvioQA/api/',
      'https://o54d2atg73.execute-api.us-east-1.amazonaws.com/QA/usuariocuentaget',
      'https://hykp91hh4e.execute-api.us-east-1.amazonaws.com/QA/lambdaautorizacionpec',
      'https://qawww3.interrapidisimo.co/ApiIntegracionQA/api/',
      'https://9jjzavn2vg.execute-api.us-east-1.amazonaws.com/qa/',
      'https://nr85ss6v30.execute-api.us-east-1.amazonaws.com/QA/',
      'https://qawww3.interrapidisimo.co/apiProductoQA/api/',
      'https://qawww3.interrapidisimo.co/ApiMedioPagoQA/api/',
      'https://qawww3.interrapidisimo.co/ApiLogin/api/',
      'https://gesy1z8b49.execute-api.us-east-1.amazonaws.com/QA/',
      'https://t3jyjto1ii.execute-api.us-east-1.amazonaws.com/QA/',
      'https://apiinterpayqa.interrapidisimo.co/api/Seguridad/',
      'https://apilistarestrictivaqa.interrapidisimo.co/api/',
      'https://qawww3.interrapidisimo.co/ServicioGestionNotificacionesQA/api/',
      'https://apiinterpayqa.interrapidisimo.co/api/',
      'https://qawww3.interrapidisimo.co/AdmisionesOffline/api/',
      'https://qawww3.interrapidisimo.co/apiContingenciasQA/api/',
      'https://servicios-interapp-qa.interrapidisimo.co/QA/api/integrations/',
      'https://mediospagoqa.interrapidisimo.co/api/',
      'https://qawww3.interrapidisimo.co/ApiCanalVentas/api/',
      'https://qawww3.interrapidisimo.co/ApiPruebaEntregaQA/api/',
      'https://qawww3.interrapidisimo.co/ApiEncripcionQA/api/',
      'https://apitorrenotificaciones-qa.interrapidisimo.co/api/',
      'https://ota2sfziul.execute-api.us-east-1.amazonaws.com/QA/',
      'https://qawww3.interrapidisimo.co/ApiMediosPagoOnPremiseQA/api/MediosPago/',
      'https://apidireccionesqa.interrapidisimo.co/api/',
      'https://ota2sfziul.execute-api.us-east-1.amazonaws.com/QA/',
      'https://qawww3.interrapidisimo.co/ApicontrollerQA/api/',
      'https://qawww3.interrapidisimo.co/ApiGestionEntregaBloque/api/v1/',
    ],
    AppEnvironment.produccion: [
      'https://www3.interrapidisimo.com/ApiRecogidas/api/',
      'https://www3.interrapidisimo.com/Apicontroller/api/',
      'https://www3.interrapidisimo.com/ApiSeguridadAutenticacion/api/',
      'https://www3.interrapidisimo.com:1443/ApiRaps/api/',
      'https://pos.interrapidisimo.com/ApiNegocio/api/parametrosgeneralesformatos',
      'https://www3.interrapidisimo.com/ApiServInter/api/',
      'https://www3.interrapidisimo.com/ApiPreenvio/api/',
      'https://saf0kq4m20.execute-api.us-east-1.amazonaws.com/Prod/usuariocuentaget',
      'https://1g4lkza6o4.execute-api.us-east-1.amazonaws.com/Prod/LambdaAutorizacionPEC',
      'https://www3.interrapidisimo.com/ApiIntegracion/api/',
      'https://q85igmkqlb.execute-api.us-east-1.amazonaws.com/Produccion/',
      'https://k3v0kegu88.execute-api.us-east-1.amazonaws.com/Produccion/',
      'https://www3.interrapidisimo.com/apiProducto/api/',
      'https://www3.interrapidisimo.com/ApiMediosPago/api/',
      'https://www3.interrapidisimo.com/ApiLogin/api/',
      'https://1gnybpq0z6.execute-api.us-east-1.amazonaws.com/Produccion/',
      'https://qz0atnyodf.execute-api.us-east-1.amazonaws.com/Produccion/',
      'https://apiinterpay.interrapidisimo.com/api/Seguridad/',
      'https://listasrestrictivasprod.interrapidisimo.com/api/',
      'https://www3.interrapidisimo.com/ServicioGestionNotificaciones/api/',
      'https://apiinterpay.interrapidisimo.com/api/',
      'https://www3.interrapidisimo.com/AdmisionesOffline/api/',
      'https://www3.interrapidisimo.com/apiContingencias/api/',
      'https://servicios-interapp-prod.interrapidisimo.com/PROD/api/integrations/',
      'https://mediospagopro.interrapidisimo.com/api/',
      'https://www3.interrapidisimo.com/ApiCanalVentas/api/',
      'https://www3.interrapidisimo.com/ApiPruebaEntrega/api/',
      'https://www3.interrapidisimo.com/ApiEncripcion/api/',
      'https://apitorrenotificaciones-prod.interrapidisimo.com/api/',
      'https://pzooe26ibi.execute-api.us-east-1.amazonaws.com/ProdTransversal/',
      'https://www3.interrapidisimo.com/ApiMediosPagoOnPremise/api/MediosPago/',
      'https://apidireccionesprod.interrapidisimo.com/api/',
      'https://pzooe26ibi.execute-api.us-east-1.amazonaws.com/ProdTransversal/',
      'https://www3.interrapidisimo.com/Apicontroller/api/',
      'https://www3.interrapidisimo.com/ApiGestionEntregaBloque/api/v1/',
    ],
  };
}

class RestPaths {
  static const autenticaUsuario = 'Seguridad/AuthenticaUsuarioControllerApp';
  static const versionApp =
      'ParametrosFramework/ConsultarParametrosFramework/VPStoreAppControl';
  static const estadoGuia = 'AdmisionMensajeria/ObtenerGuiaEstado';
  static const obtenerRecogidas =
      'Recogidas/ObtenerRecogidasDisponibles/{idLocalidad}';
  static const guiasEnZona =
      'OperacionUrbanaController/ObtenerGuiasMensajeroEnZona/{idMensajero}';
  static const reasignarGuias = 'AsignacionGuias/ReasignarGuiasMensajero';
  static const mediosPago = 'ObtenerMediosPagosAPP';
  static const notificaciones =
      'NotificacionesController/RegistrarDispositivoMovil';
  static const bloquesPendientes = 'BloquesEntrega/ObtenerBloquesEnGestion';
}
