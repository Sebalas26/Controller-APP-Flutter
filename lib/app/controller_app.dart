import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/home/home.dart';
import '../features/login/login.dart';
import '../shared/config/app_environment.dart';
import '../shared/firebase/controller_firebase_messaging_service.dart';
import '../shared/native/controller_native_bridge.dart';
import '../shared/network/controller_api_config.dart';
import '../shared/theme/app_theme.dart';

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
