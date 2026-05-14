part of '../login_data.dart';

class PostLoginSyncService {
  PostLoginSyncService({
    required this.apiClient,
    required this.localDatabase,
    ControllerFileSyncService? fileSyncService,
  }) : _fileSyncService = fileSyncService ?? ControllerFileSyncService();

  final ControllerApiClient apiClient;
  final ControllerLocalDatabase localDatabase;
  final ControllerFileSyncService _fileSyncService;

  Future<LocalSyncStatus> synchronize({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    LoginProgress? onProgress,
  }) async {
    final startedAt = DateTime.now();
    var tableCount = 0;
    final initialStatus = LocalSyncStatus(
      completed: false,
      message: 'Sincronizacion iniciada',
      startedAt: startedAt,
    );
    await localDatabase.saveSyncStatus(initialStatus);

    try {
      onProgress?.call('Descargando esquemas locales...');
      final schemas = await apiClient.fetchSyncSchemas(
        config: config,
        appInformation: appInformation,
      );
      final productSchemas = await apiClient.fetchProductSchemas(
        config: config,
        appInformation: appInformation,
      );
      final allSchemas = [...schemas, ...productSchemas];
      await localDatabase.saveSchemasAndCreateTables(allSchemas);

      await _fileSyncService.synchronizeFromFiles(
        config: config,
        localDatabase: localDatabase,
        schemas: allSchemas,
        appInformation: appInformation,
        onProgress: onProgress,
      );
      tableCount = allSchemas
          .where((schema) => schema.tableName.trim().isNotEmpty)
          .length;

      final completed = LocalSyncStatus(
        completed: true,
        message: 'Sincronizacion completada',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        tables: tableCount,
      );
      await localDatabase.saveSyncStatus(completed);
      return completed;
    } on Object catch (error) {
      final failed = LocalSyncStatus(
        completed: false,
        message: 'Sincronizacion parcial: $error',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        tables: tableCount,
      );
      await localDatabase.saveSyncStatus(failed);
      return failed;
    }
  }
}
