part of '../login_data.dart';

class TorreDireccionesSyncService {
  TorreDireccionesSyncService({Dio? dio, ControllerCrypto? crypto})
    : _dio = dio ?? Dio(),
      _crypto = crypto ?? ControllerCrypto();

  static const _zipExtension = '.zip';
  static const _txtExtension = '.txt';
  static const _awsRegion = 'us-east-1';
  static const _awsService = 's3';

  final Dio _dio;
  final ControllerCrypto _crypto;

  Future<int> synchronize({
    required ControllerApiClient apiClient,
    required ControllerApiConfig config,
    required ControllerLocalDatabase localDatabase,
    required AppInformation appInformation,
    LoginProgress? onProgress,
  }) async {

    onProgress?.call('Consultando esquemas de Torre Direcciones...');
    final token = await apiClient.fetchTorreDireccionesToken(config);
    final schemas = await apiClient.fetchTorreDirectionSchemas(
      config: config,
      idToken: token,
    );
    await localDatabase.saveTorreSchemasAndCreateTables(schemas);
    if (schemas.isEmpty) return 0;

    final filteredSchemas = schemas
        .where((schema) => schema.hasServiceCenterFilter)
        .toList();

      final credentials = await _readS3Credentials(localDatabase);
      if (!credentials.isComplete) {
        throw const LoginException(
          'No se encontraron credenciales AWS de Torre Direcciones.',
        );
      }

      final workspace = await _syncDirectory();
      final downloads = Directory(path.join(workspace.path, 'torre_downloads'));
      await _resetDirectory(downloads);

      final tableNames = schemas.map((schema) => schema.tableName).toSet();
      final idCentroServicio = '_${appInformation.idCentroServicio}';
      var loadedTables = 0;
      for (final schema in filteredSchemas) {
        final zipName = '${schema.tableName}$idCentroServicio$_zipExtension';
        onProgress?.call('Sincronizando Torre ${schema.tableName}...');
        if(await _syncS3Schema(downloads, zipName, idCentroServicio, tableNames, credentials, localDatabase)) {
          loadedTables++;
        }
      }
      if(await _syncS3Schema(downloads, "Sincronizacion.zip", idCentroServicio, tableNames, credentials, localDatabase)) {
          loadedTables++;
        }
    onProgress?.call('Torre Direcciones sincronizada ($loadedTables tablas).');
    return schemas.length;
  }

  Future<bool> _syncS3Schema(
    Directory downloads,
    String zipName,
    String idCentroServicio,
    Set<String> tableNames,
    _TorreS3Credentials credentials,
    ControllerLocalDatabase localDatabase,
  ) async {
    final destination = File(path.join(downloads.path, zipName));
    final downloaded = await _downloadS3Object(
      credentials: credentials,
      objectKey: zipName,
      destination: destination,
    );
    if (!downloaded) false;
    final statements = await _insertStatementsFromZip(
      zipFile: destination,
      idCentroServicio: idCentroServicio,
      validTableNames: tableNames,
    );
    await localDatabase.executeSyncStatements(statements);
    return true;
  }

  Future<_TorreS3Credentials> _readS3Credentials(
    ControllerLocalDatabase localDatabase,
  ) async {
    const encryptionKeyCode = 'EncryptionKey';
    const accessKeyCode = 'KeyAWSTorres';
    const secretKeyCode = 'SecretKeyAWSTorres';
    const bucketCode = 'BucketNameTorres';

    final encryptionKey = await localDatabase.frameworkParameter(
      encryptionKeyCode,
    );
    final encryptedAccessKey = await localDatabase.frameworkParameter(
      accessKeyCode,
    );
    final encryptedSecretKey = await localDatabase.frameworkParameter(
      secretKeyCode,
    );
    final encryptedBucket = await localDatabase.frameworkParameter(bucketCode);

    if (encryptionKey.trim().isEmpty) return const _TorreS3Credentials.empty();

    String decrypt(String value) {
      if (value.trim().isEmpty) return '';
      return _crypto.decryptFrameworkSecret(
        encryptionKeyBase64: encryptionKey,
        cipherText: value,
      );
    }

    return _TorreS3Credentials(
      accessKey: decrypt(encryptedAccessKey),
      secretKey: decrypt(encryptedSecretKey),
      bucketName: decrypt(encryptedBucket),
    );
  }

  Future<bool> _downloadS3Object({
    required _TorreS3Credentials credentials,
    required String objectKey,
    required File destination,
  }) async {
    final host = '${credentials.bucketName}.s3.amazonaws.com';
    final uri = Uri.https(host, _canonicalUri(objectKey));
    final headers = _signedS3Headers(
      credentials: credentials,
      host: host,
      canonicalUri: uri.path,
    );
    try {
      if (await destination.exists()) 
        await destination.delete();
      await _dio.downloadUri(
        uri,
        destination.path,
        options: Options(headers: headers),
      );
      return true;
    } on DioException catch (error) {
      return false;
    }
  }

  Future<List<String>> _insertStatementsFromZip({
    required File zipFile,
    required String idCentroServicio,
    required Set<String> validTableNames,
  }) async {
    final statements = <String>[];
    if (!await zipFile.exists()) return statements;

    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive.files) {
        final name = entry.name.replaceAll('\\', '/');
        if (!entry.isFile || !name.toLowerCase().endsWith(_txtExtension)) {
          continue;
        }
        final tableName = _tableNameForTorreEntry(name, idCentroServicio);
        if (!validTableNames.contains(tableName)) continue;

        final tempFile = File(
          path.join(
            (await _syncDirectory()).path,
            'torre_${DateTime.now().microsecondsSinceEpoch}.txt',
          ),
        );
        final output = OutputFileStream(tempFile.path);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
        try {
          final bytes = await tempFile.readAsBytes();
          statements.addAll(_buildInsertStatements(tableName, bytes));
        } finally {
          if (await tempFile.exists()) await tempFile.delete();
        }
      }
    } finally {
      await input.close();
    }
    return statements;
  }

  List<String> _buildInsertStatements(String tableName, List<int> bytes) {
    final lines = const LineSplitter().convert(_decodeUtf16Le(bytes));
    const batchSize = 1000;
    final statements = <String>[];
    final records = <String>[];

    void flush() {
      if (records.isEmpty) return;
      statements.add(
        'INSERT OR REPLACE INTO $tableName VALUES ${records.join(',')}',
      );
      records.clear();
    }

    for (final rawLine in lines) {
      var line = rawLine.replaceAll('\ufeff', '').trim();
      if (line.isEmpty) continue;
      if (line.endsWith(',')) line = line.substring(0, line.length - 1);
      if (!line.endsWith(')')) continue;
      records.add(line);
      if (records.length >= batchSize) flush();
    }
    flush();
    return statements;
  }

  Map<String, String> _signedS3Headers({
    required _TorreS3Credentials credentials,
    required String host,
    required String canonicalUri,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    const payloadHash = 'UNSIGNED-PAYLOAD';
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalHeaders =
        'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    final canonicalRequest = [
      'GET',
      canonicalUri,
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final credentialScope = '$dateStamp/$_awsRegion/$_awsService/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      crypto.sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');
    final signature = _hex(
      _hmac(
        _signingKey(credentials.secretKey, dateStamp),
        utf8.encode(stringToSign),
      ),
    );
    return {
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=${credentials.accessKey}/$credentialScope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    };
  }

  Uint8List _signingKey(String secretKey, String dateStamp) {
    final kDate = _hmac(utf8.encode('AWS4$secretKey'), utf8.encode(dateStamp));
    final kRegion = _hmac(kDate, utf8.encode(_awsRegion));
    final kService = _hmac(kRegion, utf8.encode(_awsService));
    return Uint8List.fromList(_hmac(kService, utf8.encode('aws4_request')));
  }

  List<int> _hmac(List<int> key, List<int> message) {
    return crypto.Hmac(crypto.sha256, key).convert(message).bytes;
  }

  String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _decodeUtf16Le(List<int> bytes) {
    var start = 0;
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) start = 2;
    final codeUnits = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(codeUnits);
  }

  String _tableNameForTorreEntry(String entryName, String idCentroServicio) {
    final base = path
        .basename(entryName)
        .replaceFirst(RegExp(r'\.txt$', caseSensitive: false), '');
    if (idCentroServicio.isNotEmpty && base.endsWith(idCentroServicio)) {
      return base.substring(0, base.length - idCentroServicio.length);
    }
    return base;
  }

  String _canonicalUri(String objectKey) {
    return '/${objectKey.split('/').map(Uri.encodeComponent).join('/')}';
  }

  String _dateStamp(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _amzDate(DateTime date) {
    return '${_dateStamp(date)}T'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}Z';
  }

  Future<Directory> _syncDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'controller_sync'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _resetDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
  }
}

class _TorreS3Credentials {
  const _TorreS3Credentials({
    required this.accessKey,
    required this.secretKey,
    required this.bucketName,
  });

  const _TorreS3Credentials.empty()
    : accessKey = '',
      secretKey = '',
      bucketName = '';

  final String accessKey;
  final String secretKey;
  final String bucketName;

  bool get isComplete =>
      accessKey.trim().isNotEmpty &&
      secretKey.trim().isNotEmpty &&
      bucketName.trim().isNotEmpty;
}
