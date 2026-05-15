part of '../login_data.dart';

class PostLoginSyncService {
  PostLoginSyncService({
    required this.apiClient,
    required this.localDatabase,
    ControllerFileSyncService? fileSyncService,
    TorreDireccionesSyncService? torreDireccionesSyncService,
    PostLoginSuppliesSyncService? suppliesSyncService,
  }) : _fileSyncService = fileSyncService ?? ControllerFileSyncService(),
       _torreDireccionesSyncService =
           torreDireccionesSyncService ?? TorreDireccionesSyncService(),
       _suppliesSyncService =
           suppliesSyncService ?? PostLoginSuppliesSyncService();

  final ControllerApiClient apiClient;
  final ControllerLocalDatabase localDatabase;
  final ControllerFileSyncService _fileSyncService;
  final TorreDireccionesSyncService _torreDireccionesSyncService;
  final PostLoginSuppliesSyncService _suppliesSyncService;

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
      // final productSchemas = await apiClient.fetchProductSchemas(
      //   config: config,
      //   appInformation: appInformation,
      // );
      final allSchemas = [...schemas /*...productSchemas*/];
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
      var torreMessage = '';
      try {
        final torreTables = await _torreDireccionesSyncService.synchronize(
          apiClient: apiClient,
          config: config,
          localDatabase: localDatabase,
          appInformation: appInformation,
          onProgress: onProgress,
        );
        tableCount += torreTables;
      } on Object catch (error) {
        torreMessage = ' Torre Direcciones parcial: $error';
      }
      var suppliesMessage = '';
      try {
        final supplies = await _suppliesSyncService.synchronize(
          config: config,
          localDatabase: localDatabase,
          appInformation: appInformation,
          onProgress: onProgress,
        );
        suppliesMessage = ' Suministros disponibles: $supplies.';
      } on Object catch (error) {
        suppliesMessage = ' Suministros parcial: $error';
      }

      final completed = LocalSyncStatus(
        completed: true,
        message: 'Sincronizacion completada.$torreMessage$suppliesMessage',
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
