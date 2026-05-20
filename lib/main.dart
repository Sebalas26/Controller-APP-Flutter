import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/login/login.dart';
import 'features/entregas/entregas.dart';
import 'features/vender/vender.dart';
import 'shared/firebase/controller_firebase_messaging_service.dart';
import 'shared/native/controller_native_bridge.dart';
import 'shared/network/controller_api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ControllerFirebaseMessagingService.initialize();
  final prefs = await SharedPreferences.getInstance();
  runApp(ControllerApp(preferences: prefs));
}

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

class AppColors {
  static const black = Color(0xFF212529);
  static const deepBlack = Color(0xFF18191A);
  static const white = Color(0xFFFFFFFF);
  static const white2 = Color(0xFFFAFAFA);
  static const gray100 = Color(0xFFF9F9F9);
  static const gray200 = Color(0xFFEAEAEA);
  static const gray300 = Color(0xFFE1E6EF);
  static const gray500 = Color(0xFF979797);
  static const gray700 = Color(0xFF696F79);
  static const accent = Color(0xFF2569B3);
  static const accentLight = Color(0xFFE8EFF7);
  static const blue8 = Color(0xFFF0F5FF);
  static const orange = Color(0xFFE76100);
  static const red = Color(0xFFCF1111);
  static const green = Color(0xFF01623D);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.black,
        secondary: AppColors.accent,
        surface: AppColors.white,
      ),
      fontFamily: 'Montserrat',
      scaffoldBackgroundColor: AppColors.white2,
      useMaterial3: true,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white2,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.black,
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.black),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.gray200,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: AppColors.gray500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.black, width: 1.2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AppColors.accentLight,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.gray300),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
  String get prepago => urls[17];
  String get listaRestrictiva => urls[18];
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
      preenvioBaseUrl: preenvio,
      geoDireccionBaseUrl: geoDireccion,
      geoRefTokenBaseUrl: geoRefToken,
      admisionOfflineBaseUrl: admisionOffline,
      deliveryProofBaseUrl: pruebaEntregaAws,
      deliveryProofTokenBaseUrl: pruebaEntregaToken,
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

class ControllerSession {
  const ControllerSession({
    required this.username,
    required this.environment,
    required this.rememberUser,
    required this.loginDate,
    required this.appInformation,
    required this.syncStatus,
    required this.offline,
  });

  final String username;
  final AppEnvironment environment;
  final bool rememberUser;
  final DateTime loginDate;
  final AppInformation appInformation;
  final LocalSyncStatus? syncStatus;
  final bool offline;

  factory ControllerSession.fromAuthenticated(
    AuthenticatedSession session,
    AppEnvironment environment,
  ) {
    return ControllerSession(
      username: session.username,
      environment: environment,
      rememberUser: session.rememberUser,
      loginDate: session.loginDate,
      appInformation: session.appInformation,
      syncStatus: session.syncStatus,
      offline: session.offline,
    );
  }

  String get displayName {
    final localName = appInformation.displayName.trim();
    if (localName.isNotEmpty) return localName;
    return username.trim().isEmpty ? 'Usuario' : username.trim();
  }
}

class ControllerApp extends StatefulWidget {
  const ControllerApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<ControllerApp> createState() => _ControllerAppState();
}

class _ControllerAppState extends State<ControllerApp> {
  static const _environmentKey = 'environment';
  static const _rememberedUserKey = 'remembered_user';

  late AppEnvironment _environment;
  late final ControllerLocalDatabase _localDatabase;
  late final ControllerLoginRepository _loginRepository;
  late final ControllerFirebaseMessagingService _firebaseMessagingService;
  StreamSubscription<String>? _firebaseTokenSubscription;
  ControllerSession? _session;

  @override
  void initState() {
    super.initState();
    _localDatabase = ControllerLocalDatabase();
    _firebaseMessagingService = ControllerFirebaseMessagingService();
    _loginRepository = ControllerLoginRepository(
      apiClient: ControllerApiClient(),
      localDatabase: _localDatabase,
      nativeBridge: ControllerNativeBridge(),
      firebaseMessagingService: _firebaseMessagingService,
    );
    _firebaseTokenSubscription = _firebaseMessagingService.onTokenRefresh
        .listen((token) => unawaited(_localDatabase.saveFirebaseToken(token)));
    final storedEnvironment = widget.preferences.getString(_environmentKey);
    _environment = AppEnvironment.values.firstWhere(
      (item) => item.label == storedEnvironment,
      orElse: () => AppEnvironment.produccion,
    );
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    unawaited(_firebaseTokenSubscription?.cancel());
    super.dispose();
  }

  void _changeEnvironment(AppEnvironment value) {
    setState(() => _environment = value);
    unawaited(widget.preferences.setString(_environmentKey, value.label));
  }

  Future<void> _restoreSession() async {
    try {
      final restored = await _localDatabase.loadActiveSession(
        environmentLabel: _environment.label,
      );
      if (!mounted || restored == null) return;
      setState(() {
        _session = ControllerSession.fromAuthenticated(restored, _environment);
      });
    } on Object {
      return;
    }
  }

  ControllerApiConfig _apiConfigFor(AppEnvironment environment) {
    final config = EnvironmentConfig.of(environment);
    return config.toApiConfig();
  }

  Future<void> _login(AuthenticatedSession session, bool rememberUser) async {
    if (rememberUser) {
      unawaited(
        widget.preferences.setString(_rememberedUserKey, session.username),
      );
    } else {
      unawaited(widget.preferences.remove(_rememberedUserKey));
    }

    setState(() {
      _session = ControllerSession.fromAuthenticated(session, _environment);
    });
  }

  void _logout() {
    unawaited(_localDatabase.clearActiveSession());
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return MaterialApp(
      title: _environment.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: session == null
          ? LoginPage<AppEnvironment>(
              environment: _environment,
              environments: AppEnvironment.values,
              environmentLabel: (environment) => environment.label,
              rememberedUser:
                  widget.preferences.getString(_rememberedUserKey) ?? '',
              onEnvironmentChanged: _changeEnvironment,
              apiConfig: _apiConfigFor(_environment),
              loginRepository: _loginRepository,
              onLogin: _login,
            )
          : HomePage(
              session: session,
              environment: _environment,
              onEnvironmentChanged: _changeEnvironment,
              onLogout: _logout,
            ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.environment,
    required this.onEnvironmentChanged,
    required this.onLogout,
  });

  final ControllerSession session;
  final AppEnvironment environment;
  final ValueChanged<AppEnvironment> onEnvironmentChanged;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _guideController = TextEditingController();

  @override
  void dispose() {
    _guideController.dispose();
    super.dispose();
  }

  void _openModule(AppModule module) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModulePage(
          module: module,
          session: widget.session,
          config: EnvironmentConfig.of(widget.environment),
        ),
      ),
    );
  }

  Future<void> _launchTracking() async {
    final guide = _guideController.text.trim();
    if (guide.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el numero de guia.')),
      );
      return;
    }

    final url = Uri.parse(
      EnvironmentConfig.of(widget.environment).trackingUrl(guide),
    );
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(url.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryModules = appModules.where((item) => item.primary).toList();
    final functionalModules = appModules
        .where((item) => !item.primary)
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppNavigationDrawer(
        session: widget.session,
        environment: widget.environment,
        onEnvironmentChanged: widget.onEnvironmentChanged,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: Column(
          children: [
            HomeHeader(
              onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationsPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 15, 24, 0),
                      child: SearchGuideField(
                        controller: _guideController,
                        onSubmit: _launchTracking,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionTitle(
                      icon: Icons.check_circle_outline,
                      text: 'Principales',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: primaryModules.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.05,
                            ),
                        itemBuilder: (context, index) {
                          final module = primaryModules[index];
                          return ModuleCard(
                            module: module,
                            large: true,
                            onTap: () => _openModule(module),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _HomeBanner(environment: widget.environment),
                    const SizedBox(height: 18),
                    const SectionTitle(
                      icon: Icons.more_horiz,
                      text: 'Funcionales',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: functionalModules.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.95,
                            ),
                        itemBuilder: (context, index) {
                          final module = functionalModules[index];
                          return ModuleCard(
                            module: module,
                            onTap: () => _openModule(module),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            HomeFooter(
              userName: widget.session.displayName,
              environment: widget.environment,
              syncStatus: widget.session.syncStatus,
              offline: widget.session.offline,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.white2,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenuPressed,
            icon: const Icon(Icons.menu, color: AppColors.black),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Controller App',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'Prospero',
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: onNotificationsPressed,
                icon: const Icon(
                  Icons.notifications_none,
                  color: AppColors.black,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Usuario activo',
            onPressed: () {},
            icon: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchGuideField extends StatelessWidget {
  const SearchGuideField({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 20,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Ingresa numero guia',
                fillColor: AppColors.white,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Buscar guia',
            onPressed: onSubmit,
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.black),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.black, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
    this.large = false,
  });

  final AppModule module;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: large ? AppColors.gray200 : AppColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(large ? 16 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(module.icon, size: large ? 46 : 30, color: AppColors.black),
              const SizedBox(height: 12),
              Text(
                module.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: large ? 15 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBanner extends StatelessWidget {
  const _HomeBanner({required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      child: PageView(
        controller: PageController(viewportFraction: 0.82),
        children: [
          BannerPanel(
            title: 'Sigue tu envio',
            subtitle: environment.label,
            icon: Icons.search,
            color: AppColors.blue8,
          ),
          const BannerPanel(
            title: 'Pagos y recaudos',
            subtitle: 'Nequi, Link de pago, Inter Pay',
            icon: Icons.payments_outlined,
            color: AppColors.accentLight,
          ),
        ],
      ),
    );
  }
}

class BannerPanel extends StatelessWidget {
  const BannerPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 44, color: AppColors.black),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeFooter extends StatelessWidget {
  const HomeFooter({
    super.key,
    required this.userName,
    required this.environment,
    required this.syncStatus,
    required this.offline,
  });

  final String userName;
  final AppEnvironment environment;
  final LocalSyncStatus? syncStatus;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(color: AppColors.black),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            offline
                ? 'Offline'
                : syncStatus?.completed == true
                ? 'Sync OK'
                : environment.label,
            style: const TextStyle(color: AppColors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.session,
    required this.environment,
    required this.onEnvironmentChanged,
    required this.onLogout,
  });

  final ControllerSession session;
  final AppEnvironment environment;
  final ValueChanged<AppEnvironment> onEnvironmentChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/logo_interrapidisimo.png',
                    height: 34,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    session.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    environment.appName,
                    style: const TextStyle(color: AppColors.gray700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notificaciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue_outlined),
              title: const Text('Ambientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EnvironmentPage(
                      environment: environment,
                      onEnvironmentChanged: onEnvironmentChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('Rutas Android'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NativeRoutesPage()),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.module,
    required this.session,
    required this.config,
  });

  final AppModule module;
  final ControllerSession session;
  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModuleHeader(module: module, config: config),
            const SizedBox(height: 12),
            _bodyFor(module),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(AppModule module) {
    switch (module.id) {
      case 'vender':
        return VenderPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        );
      case 'entregar':
        return EntregasPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        );
      case 'recoger':
        return const PickupBody();
      case 'asignar':
        return const AssignmentBody();
      case 'mis_pagos':
        return PaymentsBody(config: config);
      case 'estado_cuenta':
        return const AccountStatusBody();
      case 'mis_mensajeros':
        return const CouriersBody();
      case 'yaap':
        return const YaapBody();
      case 'reimprimir':
        return const ReprintBody();
      case 'anular':
        return const CancelGuideBody();
      case 'bloques':
        return const BlocksBody();
      case 'enrutamiento':
        return const RoutingBody();
      case 'auditoria':
        return const AuditBody();
      case 'prepago':
        return const PrepagoBody();
      default:
        return GenericWorkflowBody(module: module);
    }
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.module, required this.config});

  final AppModule module;
  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(module.icon, color: AppColors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.environment.label,
                    style: const TextStyle(color: AppColors.gray700),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: module.legacyRoute,
              child: const Icon(Icons.info_outline, color: AppColors.gray700),
            ),
          ],
        ),
      ),
    );
  }
}

class AdmissionBody extends StatelessWidget {
  const AdmissionBody({super.key, required this.config});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Numero de preenvio'),
        const TextField(keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        const FieldLabel('Ciudad de destino'),
        const TextField(),
        const SizedBox(height: 14),
        const FieldLabel('Piezas y peso'),
        const Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: '# piezas'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Peso kg'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SummaryStrip(
          items: [
            SummaryItem('Base', config.controller),
            const SummaryItem('Modo', 'Online / Offline'),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Cotizar'),
        ),
      ],
    );
  }
}

class DeliveryBody extends StatelessWidget {
  const DeliveryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['En zona', 'Entregadas', 'Devoluciones'],
      children: [
        GuideList(status: 'En zona', icon: Icons.location_on_outlined),
        GuideList(status: 'Entregada', icon: Icons.check_circle_outline),
        GuideList(status: 'Devolucion', icon: Icons.assignment_return_outlined),
      ],
    );
  }
}

class PickupBody extends StatelessWidget {
  const PickupBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Disponibles', 'Reservadas', 'Efectivas'],
      children: [
        GuideList(status: 'Disponible', icon: Icons.inbox_outlined),
        GuideList(status: 'Reservada', icon: Icons.bookmark_border),
        GuideList(status: 'Efectiva', icon: Icons.task_alt_outlined),
      ],
    );
  }
}

class AssignmentBody extends StatefulWidget {
  const AssignmentBody({super.key});

  @override
  State<AssignmentBody> createState() => _AssignmentBodyState();
}

class _AssignmentBodyState extends State<AssignmentBody> {
  final _courierController = TextEditingController();
  final _guideController = TextEditingController();
  final _guides = <String>[];

  @override
  void dispose() {
    _courierController.dispose();
    _guideController.dispose();
    super.dispose();
  }

  void _addGuide() {
    final guide = _guideController.text.trim();
    if (guide.isEmpty) return;
    setState(() {
      _guides.add(guide);
      _guideController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Seleccionar mensajero'),
        TextField(
          controller: _courierController,
          decoration: const InputDecoration(
            hintText: 'Seleccionar apoyo',
            suffixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Ingresar guias'),
        TextField(
          controller: _guideController,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _addGuide(),
          decoration: InputDecoration(
            hintText: 'Numero guia',
            suffixIcon: IconButton(
              tooltip: 'Agregar guia',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _addGuide,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Total asignado: ${_guides.length}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ..._guides.map(
          (guide) => GuideTile(
            guide: guide,
            status: 'Pendiente',
            icon: Icons.local_shipping_outlined,
            onDelete: () => setState(() => _guides.remove(guide)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _guides.isEmpty ? null : () {},
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Asignar planilla'),
        ),
      ],
    );
  }
}

class PaymentsBody extends StatefulWidget {
  const PaymentsBody({super.key, required this.config});

  final EnvironmentConfig config;

  @override
  State<PaymentsBody> createState() => _PaymentsBodyState();
}

class _PaymentsBodyState extends State<PaymentsBody> {
  String _method = 'Nequi';
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Nequi', 'Link de pago', 'Efectivo', 'Inter Pay']
              .map(
                (method) => ChoiceChip(
                  label: Text(method),
                  selected: method == _method,
                  onSelected: (_) => setState(() => _method = method),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Valor a cobrar'),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: r'$ '),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Telefono'),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        SummaryStrip(
          items: [
            SummaryItem('Medio', _method),
            SummaryItem('Base', widget.config.mediosPago),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.send_outlined),
          label: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}

class AccountStatusBody extends StatelessWidget {
  const AccountStatusBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: const [
        DashboardTile(
          title: 'Saldo por centro de servicio',
          value: r'$ 0',
          icon: Icons.account_balance_wallet_outlined,
        ),
        DashboardTile(
          title: 'Guias entregadas',
          value: '0',
          icon: Icons.check_circle_outline,
        ),
        DashboardTile(
          title: 'Pendiente por legalizar',
          value: '0',
          icon: Icons.pending_actions_outlined,
        ),
      ],
    );
  }
}

class CouriersBody extends StatelessWidget {
  const CouriersBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Buscar apoyo'),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Nombre, telefono o identificacion',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Nuevo Mensajero'),
        ),
        const SizedBox(height: 12),
        const GuideTile(
          guide: 'Apoyo disponible',
          status: 'Activo',
          icon: Icons.person_outline,
        ),
      ],
    );
  }
}

class YaapBody extends StatelessWidget {
  const YaapBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Pendiente', 'Verificado', 'Rechazado'],
      children: [
        GuideList(status: 'Pendiente', icon: Icons.pending_outlined),
        GuideList(status: 'Verificado', icon: Icons.verified_outlined),
        GuideList(status: 'Rechazado', icon: Icons.cancel_outlined),
      ],
    );
  }
}

class ReprintBody extends StatelessWidget {
  const ReprintBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Numero de guia'),
        const TextField(keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: const [
            FilterChip(label: Text('Zebra'), selected: true, onSelected: null),
            FilterChip(
              label: Text('Woosim'),
              selected: false,
              onSelected: null,
            ),
            FilterChip(label: Text('Sewoo'), selected: false, onSelected: null),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.print_outlined),
          label: const Text('Reimprimir'),
        ),
      ],
    );
  }
}

class CancelGuideBody extends StatelessWidget {
  const CancelGuideBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Numero de guia'),
        const TextField(keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        const FieldLabel('Motivo anulacion'),
        DropdownButtonFormField<String>(
          initialValue: 'Cliente solicita anulacion',
          items: const [
            DropdownMenuItem(
              value: 'Cliente solicita anulacion',
              child: Text('Cliente solicita anulacion'),
            ),
            DropdownMenuItem(
              value: 'Error en admision',
              child: Text('Error en admision'),
            ),
            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.block_outlined),
          label: const Text('Anular guia'),
        ),
      ],
    );
  }
}

class BlocksBody extends StatelessWidget {
  const BlocksBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Pendientes', 'En gestion', 'Cerrados'],
      children: [
        GuideList(status: 'Pendiente bloque', icon: Icons.all_inbox_outlined),
        GuideList(status: 'En gestion', icon: Icons.inventory_outlined),
        GuideList(status: 'Cerrado', icon: Icons.task_alt_outlined),
      ],
    );
  }
}

class RoutingBody extends StatelessWidget {
  const RoutingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const DashboardTile(
          title: 'Guias ruta',
          value: '0',
          icon: Icons.alt_route_outlined,
        ),
        const DashboardTile(
          title: 'Enrutamientos diarios',
          value: '20',
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Abrir mapa'),
        ),
      ],
    );
  }
}

class AuditBody extends StatelessWidget {
  const AuditBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Por aprobar', 'Rechazadas', 'No aplican'],
      children: [
        GuideList(status: 'Por aprobar', icon: Icons.pending_actions_outlined),
        GuideList(status: 'Rechazada', icon: Icons.cancel_outlined),
        GuideList(status: 'No aplica', icon: Icons.info_outline),
      ],
    );
  }
}

class PrepagoBody extends StatelessWidget {
  const PrepagoBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const DashboardTile(
          title: 'Cuenta prepago',
          value: r'$ 0',
          icon: Icons.credit_card_outlined,
        ),
        const SizedBox(height: 12),
        const FieldLabel('Codigo de seguridad'),
        const TextField(keyboardType: TextInputType.number, maxLength: 6),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Validar codigo'),
        ),
      ],
    );
  }
}

class GenericWorkflowBody extends StatelessWidget {
  const GenericWorkflowBody({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Buscar'),
        TextField(decoration: InputDecoration(hintText: module.title)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: Icon(module.icon),
          label: Text(module.title),
        ),
      ],
    );
  }
}

class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class SummaryItem {
  const SummaryItem(this.label, this.value);

  final String label;
  final String value;
}

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.items});

  final List<SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => Container(
              width: 155,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blue8,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class TabWorkflow extends StatelessWidget {
  const TabWorkflow({super.key, required this.tabs, required this.children});

  final List<String> tabs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: FormCard(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: AppColors.black,
            unselectedLabelColor: AppColors.gray700,
            indicatorColor: AppColors.black,
            tabs: tabs.map((tab) => Tab(text: tab)).toList(),
          ),
          SizedBox(height: 420, child: TabBarView(children: children)),
        ],
      ),
    );
  }
}

class GuideList extends StatelessWidget {
  const GuideList({super.key, required this.status, required this.icon});

  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        for (final guide in const ['1000000001', '1000000002', '1000000003'])
          GuideTile(guide: guide, status: status, icon: icon),
      ],
    );
  }
}

class GuideTile extends StatelessWidget {
  const GuideTile({
    super.key,
    required this.guide,
    required this.status,
    required this.icon,
    this.onDelete,
  });

  final String guide;
  final String status;
  final IconData icon;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.black),
          title: Text(
            guide,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(status),
          trailing: onDelete == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
        ),
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.black),
          title: Text(title),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unread = true;

  @override
  Widget build(BuildContext context) {
    final status = _unread ? 'Sin leer' : 'Leida';

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  selected: _unread,
                  label: const Text('Sin leer'),
                  onSelected: (_) => setState(() => _unread = true),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected: !_unread,
                  label: const Text('Leidos'),
                  onSelected: (_) => setState(() => _unread = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gray300),
                  ),
                  child: ListTile(
                    leading: Icon(
                      _unread
                          ? Icons.mark_email_unread_outlined
                          : Icons.drafts_outlined,
                    ),
                    title: Text('Actualizacion guia ${1000 + index}'),
                    subtitle: Text(status),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EnvironmentPage extends StatefulWidget {
  const EnvironmentPage({
    super.key,
    required this.environment,
    required this.onEnvironmentChanged,
  });

  final AppEnvironment environment;
  final ValueChanged<AppEnvironment> onEnvironmentChanged;

  @override
  State<EnvironmentPage> createState() => _EnvironmentPageState();
}

class _EnvironmentPageState extends State<EnvironmentPage> {
  late AppEnvironment _selected = widget.environment;
  String? _status;
  bool _loading = false;

  Future<void> _pingHealth() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    final config = EnvironmentConfig.of(_selected);
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ).get<dynamic>(config.healthUrl);
      if (!mounted) return;
      setState(() => _status = 'HTTP ${response.statusCode}');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message ?? 'No fue posible conectar.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = EnvironmentConfig.of(_selected);
    final urls = <SummaryItem>[
      SummaryItem('Recogidas', config.recogidas),
      SummaryItem('Controller', config.controller),
      SummaryItem('Autenticacion', config.autenticacion),
      SummaryItem('Medios pago', config.mediosPago),
      SummaryItem('YAAP', config.yaap),
      SummaryItem('Notificaciones', config.torreNotificaciones),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ambientes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<AppEnvironment>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Ambiente'),
            items: AppEnvironment.values
                .map(
                  (environment) => DropdownMenuItem(
                    value: environment,
                    child: Text(environment.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selected = value);
              widget.onEnvironmentChanged(value);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _pingHealth,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety_outlined),
            label: Text(_status ?? 'Probar health'),
          ),
          const SizedBox(height: 16),
          FormCard(
            children: urls
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          item.value,
                          style: const TextStyle(
                            color: AppColors.gray700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          FormCard(
            children: const [
              Text(
                'Endpoints portados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              SelectableText(RestPaths.autenticaUsuario),
              SelectableText(RestPaths.versionApp),
              SelectableText(RestPaths.estadoGuia),
              SelectableText(RestPaths.reasignarGuias),
              SelectableText(RestPaths.mediosPago),
              SelectableText(RestPaths.bloquesPendientes),
            ],
          ),
        ],
      ),
    );
  }
}

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
