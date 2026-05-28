part of '../login_data.dart';

class ControllerLoginRepository {
  ControllerLoginRepository({
    required this.apiClient,
    required this.localDatabase,
    required this.nativeBridge,
    required this.firebaseMessagingService,
    ControllerCrypto? crypto,
  }) : _crypto = crypto ?? ControllerCrypto();

  final ControllerApiClient apiClient;
  final ControllerLocalDatabase localDatabase;
  final ControllerNativeBridge nativeBridge;
  final ControllerFirebaseMessagingService firebaseMessagingService;
  final ControllerCrypto _crypto;

  Future<LoginStartResult> authenticate({
    required ControllerApiConfig config,
    required String username,
    required String password,
    required bool rememberUser,
    LoginProgress? onProgress,
  }) async {
    onProgress?.call('Validando version instalada...');
    await _validateVersion(config);

    final androidId = await nativeBridge.androidId();
    final aesSecret = await nativeBridge.aesPasswordSecret();
    onProgress?.call('Obteniendo token Firebase...');
    final firebaseToken = await firebaseMessagingService.getTokenFirebase();
    await localDatabase.saveFirebaseToken(firebaseToken);
    final request = CredentialRequest(
      user: _crypto.base64Utf8(username),
      password: _crypto.base64Utf8(password),
      path: '',
      mac: androidId,
      applicationName: ControllerApiClient.appName,
      firebaseToken: firebaseToken,
    );

    try {
      onProgress?.call('Autenticando usuario...');
      final credential = await apiClient.authenticate(
        config: config,
        request: request,
      );
      _validateLoginStatus(credential);

      if (credential.locations.isEmpty) {
        throw const LoginException(
          'El usuario no tiene ubicaciones asignadas.',
        );
      }

      return LoginStartResult.online(
        LoginDraft(
          config: config,
          username: username,
          password: password,
          androidId: androidId,
          aesSecret: aesSecret,
          firebaseToken: firebaseToken,
          credential: credential,
        ),
      );
    } on DioException {
      onProgress?.call('Sin red, validando acceso local...');
      final session = await localDatabase.validateOfflineLogin(
        username: username,
        password: password,
        aesSecret: aesSecret,
        environmentLabel: config.label,
        rememberUser: rememberUser,
      );
      return LoginStartResult.offline(session);
    }
  }

  Future<AuthenticatedSession> completeLogin({
    required LoginDraft draft,
    required AuthorizedLocation selectedLocation,
    required bool rememberUser,
    LoginProgress? onProgress,
  }) async {
    onProgress?.call('Guardando credenciales locales...');
    var appInformation = await localDatabase.saveLoginBootstrap(
      credential: draft.credential,
      location: selectedLocation,
      username: draft.username,
      plainPassword: draft.password,
      environmentLabel: draft.config.label,
      active: rememberUser,
      aesSecret: draft.aesSecret,
    );

    onProgress?.call('Registrando dispositivo...');
    var deviceId = '';
    var firebaseToken = draft.firebaseToken;
    try {
      if (firebaseToken.trim().isEmpty) {
        firebaseToken = await firebaseMessagingService.getTokenFirebase();
        await localDatabase.saveFirebaseToken(firebaseToken);
      }
      deviceId = await apiClient.registerMobileDevice(
        config: draft.config,
        appInformation: appInformation,
        androidId: draft.androidId,
        firebaseToken: firebaseToken,
      );
      await localDatabase.saveDeviceId(deviceId);
    } on Object {
      deviceId = '';
    }

    onProgress?.call('Consultando informacion del usuario...');
    final userInfo = await apiClient.getUserInfo(
      config: draft.config,
      identification: draft.credential.identificacion,
      appInformation: appInformation,
    );
    appInformation = await localDatabase.saveUserInfo(
      current: appInformation,
      userInfo: userInfo,
      active: rememberUser,
      deviceId: deviceId.isEmpty ? null : deviceId,
    );

    final syncStatus =
        await PostLoginSyncService(
          apiClient: apiClient,
          localDatabase: localDatabase,
        ).synchronize(
          config: draft.config,
          appInformation: appInformation,
          onProgress: onProgress,
        );

    return AuthenticatedSession(
      username: draft.username,
      environmentLabel: draft.config.label,
      rememberUser: rememberUser,
      loginDate: DateTime.now(),
      appInformation: appInformation,
      syncStatus: syncStatus,
      modules: draft.credential.modules,
      offline: false,
    );
  }

  Future<void> _validateVersion(ControllerApiConfig config) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = int.tryParse(packageInfo.buildNumber) ?? 0;
      final latestText = await apiClient.fetchLatestAppVersion(config);
      final latest = int.tryParse(latestText.replaceAll(RegExp(r'[^0-9]'), ''));
      if (latest != null && current > 0 && latest > current) {
        throw const LoginException(
          'Existe una version mas reciente. Actualiza la app para ingresar.',
        );
      }
    } on LoginException {
      rethrow;
    } on Object {
      return;
    }
  }

  void _validateLoginStatus(LoginCredential credential) {
    if (credential.mensajeResultado == 2) return;
    throw LoginException(_loginStatusMessage(credential.mensajeResultado));
  }

  String _loginStatusMessage(int status) {
    switch (status) {
      case 0:
        return 'Usuario o contrasena invalida.';
      case 1:
        return 'El usuario se encuentra bloqueado.';
      case 3:
        return 'El usuario no existe.';
      case 4:
        return 'La contrasena esta vencida.';
      case 5:
        return 'Empleado no existe o se encuentra inactivo.';
      case 6:
        return 'El usuario no tiene permisos para Controller APP.';
      case 7:
        return 'El usuario no tiene ubicacion asignada.';
      case 8:
        return 'No fue posible crear la sesion.';
      case 9:
        return 'El usuario debe cambiar la contrasena inicial.';
      default:
        return 'No fue posible iniciar sesion.';
    }
  }
}
