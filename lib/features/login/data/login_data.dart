import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../shared/firebase/controller_firebase_messaging_service.dart';
import '../../../shared/native/controller_native_bridge.dart';
import '../../../shared/network/controller_api_config.dart';
import '../../../shared/network/controller_http_client.dart';
import '../../../shared/security/controller_crypto.dart';
import '../../../shared/security/controller_id_key_provider.dart';

part 'datasources/controller_api_client.dart';
part 'datasources/controller_local_database.dart';
part 'models/login_models.dart';
part 'repositories/controller_login_repository.dart';
part 'services/controller_file_sync_service.dart';
part 'services/post_login_sync_service.dart';
part 'services/torre_direcciones_sync_service.dart';

typedef LoginProgress = void Function(String message);
