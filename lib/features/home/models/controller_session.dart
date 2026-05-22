import '../../login/login.dart';
import '../../../shared/config/app_environment.dart';

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
