part of '../login_data.dart';

class ControllerFileSyncService {
  ControllerFileSyncService({Dio? dio}) : _dio = dio ?? Dio();

  static const _genericZip = 'Sincronizacion.zip';
  static const _productZip = 'Producto_PRD.zip';
  static const _zipExtension = '.zip';
  static const _textExtension = '.txt';

  final Dio _dio;

  Future<void> synchronizeFromFiles({
    required ControllerApiConfig config,
    required ControllerLocalDatabase localDatabase,
    required List<SyncSchema> schemas,
    required AppInformation appInformation,
    LoginProgress? onProgress,
  }) async {
    final workspace = await _syncDirectory();
    final downloads = Directory(path.join(workspace.path, 'downloads'));
    final extracted = Directory(path.join(workspace.path, 'extracted'));
    await _resetDirectory(downloads);
    await _resetDirectory(extracted);

    final zipNames = _zipNamesForInitialSync(schemas, appInformation);
    onProgress?.call('Descargando archivos de sincronizacion...');
    for (final zipName in zipNames) {
      await _downloadWithRetry(
        _joinUrl(config.syncFilesBaseUrl, zipName),
        File(path.join(downloads.path, zipName)),
      );
    }

    await _extractIfExists(
      File(path.join(downloads.path, _genericZip)),
      extracted,
    );
    await _extractIfExists(
      File(path.join(downloads.path, _productZip)),
      extracted,
    );

    var tableCount = 0;
    for (final schema in schemas) {
      if (schema.tableName.trim().isEmpty) continue;
      tableCount++;
      onProgress?.call('Sincronizando ${schema.tableName}...');
      final filePlan = _filePlanFor(schema, appInformation);
      if (filePlan.zipName.isNotEmpty) {
        await _extractIfExists(
          File(path.join(downloads.path, filePlan.zipName)),
          extracted,
        );
      }
      final dataFile = File(path.join(extracted.path, filePlan.textName));
      if (!await dataFile.exists()) continue;
      await localDatabase.insertSyncFile(
        file: dataFile,
        filterSuffix: filePlan.filterSuffix,
      );
      await localDatabase.markTableSynchronized(schema.tableName);
    }

    onProgress?.call('Sincronizacion local completada ($tableCount tablas).');
  }

  Future<Directory> _syncDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'controller_sync'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _resetDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }

  Future<void> _downloadWithRetry(String url, File destination) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        if (await destination.exists()) {
          await destination.delete();
        }
        await _dio.download(url, destination.path);
        return;
      } on Object catch (error) {
        lastError = error;
        if (attempt == 5) break;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw LoginException('No fue posible descargar $url: $lastError');
  }

  Future<void> _extractIfExists(File zipFile, Directory destination) async {
    if (!await zipFile.exists()) return;

    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final basePath = path.canonicalize(destination.path);
      for (final entry in archive.files) {
        final entryName = _sanitizeZipEntryName(entry.name);
        if (entryName.isEmpty) continue;
        final outputPath = path.canonicalize(
          path.join(destination.path, entryName),
        );
        final output = File(outputPath);
        final isInsideDestination =
            outputPath == basePath || path.isWithin(basePath, outputPath);
        if (!isInsideDestination) {
          throw const LoginException('Entrada ZIP insegura en sincronizacion.');
        }
        if (entry.isFile) {
          await output.parent.create(recursive: true);
          final stream = OutputFileStream(output.path);
          try {
            entry.writeContent(stream);
          } finally {
            await stream.close();
          }
        } else {
          await Directory(output.path).create(recursive: true);
        }
      }
    } finally {
      await input.close();
    }
  }

  Set<String> _zipNamesForInitialSync(
    List<SyncSchema> schemas,
    AppInformation appInformation,
  ) {
    final names = <String>{_genericZip};
    for (final schema in schemas) {
      if (schema.filter.trim().isNotEmpty) {
        final filter = _establishFilter(schema.tableName, '%s', appInformation);
        if (filter.isNotEmpty) {
          names.add('${schema.tableName}_$filter$_zipExtension');
        }
      }
      if (schema.tableName == 'Producto_PRD') {
        names.add(_productZip);
      }
    }
    return names;
  }

  _SyncFilePlan _filePlanFor(SyncSchema schema, AppInformation appInformation) {
    if (schema.filter.trim().isEmpty) {
      return _SyncFilePlan(
        textName: '${schema.tableName}$_textExtension',
        zipName: '',
        filterSuffix: '',
      );
    }

    final filter = _establishFilter(schema.tableName, '%s', appInformation);
    if (filter.isEmpty) {
      return _SyncFilePlan(
        textName: '${schema.tableName}$_textExtension',
        zipName: '',
        filterSuffix: '',
      );
    }

    final suffix = '_${_obtainFilter(schema.tableName, appInformation)}';
    return _SyncFilePlan(
      textName: '${schema.tableName}_$filter$_textExtension',
      zipName: '${schema.tableName}_$filter$_zipExtension',
      filterSuffix: suffix == '_' ? '' : suffix,
    );
  }

  String _establishFilter(
    String tableName,
    String filter,
    AppInformation appInformation,
  ) {
    switch (tableName) {
      case 'ServicioTrayecto_TAR':
      case 'TrayectoCasillero_OPN':
      case 'PrecioServicioExcepcionTrayecto_TAR':
      case 'Trayecto_TAR':
        return appInformation.idCiudad;
      case 'CentroServicioServicio_PUA':
      case 'HorarioRecogidaCentroSvc_PUA':
      case 'ClienteContado_CLI':
      case 'CentroServicioServicioDia_PUA':
        return appInformation.idCentroServicio;
      case 'ParametrosFramework':
      case 'Localidad_PAR':
      case 'CentroServicioSrvComi_COM':
        return '';
      default:
        return filter;
    }
  }

  String _obtainFilter(String tableName, AppInformation appInformation) {
    switch (tableName) {
      case 'ServicioTrayecto_TAR':
      case 'Trayecto_TAR':
      case 'TrayectoCasillero_OPN':
      case 'PrecioServicioExcepcionTrayecto_TAR':
        return appInformation.idCiudad;
      case 'CentroServicioServicio_PUA':
      case 'HorarioRecogidaCentroSvc_PUA':
      case 'ClienteContado_CLI':
      case 'CentroServicioServicioDia_PUA':
        return appInformation.idCentroServicio;
      default:
        return '';
    }
  }

  String _joinUrl(String baseUrl, String fileName) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$normalized$fileName';
  }

  String _sanitizeZipEntryName(String name) {
    final normalized = name.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .toList();
    return path.joinAll(parts);
  }
}

class _SyncFilePlan {
  const _SyncFilePlan({
    required this.textName,
    required this.zipName,
    required this.filterSuffix,
  });

  final String textName;
  final String zipName;
  final String filterSuffix;
}
