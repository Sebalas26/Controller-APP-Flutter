import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

class ControllerNativeBridge {
  static const _channel = MethodChannel('controller_app/native');

  Future<String> androidId() async {
    try {
      return await _channel.invokeMethod<String>('getAndroidId') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> aesPasswordSecret() async {
    try {
      return await _channel.invokeMethod<String>('getAesPasswordSecret') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> aesKeySecret() async {
    try {
      return await _channel.invokeMethod<String>('getAesKeySecret') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> aesSaltSecret() async {
    try {
      return await _channel.invokeMethod<String>('getAesSaltSecret') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> takePackagePhoto() async {
    try {
      return await _channel.invokeMethod<String>('takePackagePhoto') ?? '';
    } on MissingPluginException catch (e) {
      debugPrint('takePackagePhoto - MissingPluginException: $e');
      return '';
    } on PlatformException catch (e) {
      debugPrint(
        'takePackagePhoto - PlatformException: ${e.code} - ${e.message}',
      );
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint('Permiso de camara denegado. Verifica los permisos.');
      } else if (e.code == 'CAMERA_ERROR' || e.code == 'CAMERA_LAUNCH_ERROR') {
        debugPrint('Error al abrir camara: ${e.message}');
      }
      return '';
    } catch (e) {
      debugPrint('takePackagePhoto - Unexpected error: $e');
      return '';
    }
  }

  Future<String> scanQrCode() async {
    try {
      return await _channel.invokeMethod<String>('scanQrCode') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> compressImageBase64ToJpeg(
    String imageBase64, {
    int maxDimension = 480,
    int quality = 35,
    int maxBase64Length = 45 * 1024,
  }) async {
    try {
      return await _channel.invokeMethod<String>('compressImageBase64ToJpeg', {
            'imageBase64': imageBase64,
            'maxDimension': maxDimension,
            'quality': quality,
            'maxBase64Length': maxBase64Length,
          }) ??
          '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> yaapUser() async {
    try {
      return await _channel.invokeMethod<String>('getYaapUser') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> yaapPasswordPruebas() async {
    try {
      return await _channel.invokeMethod<String>('getYaapPasswordPruebas') ??
          '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> yaapPasswordQa() async {
    try {
      return await _channel.invokeMethod<String>('getYaapPasswordQa') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> yaapPasswordProduccion() async {
    try {
      return await _channel.invokeMethod<String>('getYaapPasswordProduccion') ??
          '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<bool> hasBluetoothPrinter() async {
    try {
      return await _channel.invokeMethod<bool>('hasBluetoothPrinter') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> printPdfFile(String filePath, {required String jobName}) async {
    try {
      return await _channel.invokeMethod<bool>('printPdfFile', {
            'filePath': filePath,
            'jobName': jobName,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('printPdfFile - PlatformException: ${e.code} - ${e.message}');
      return false;
    }
  }

  Future<bool> openPdfFile(String filePath) async {
    try {
      return await _channel.invokeMethod<bool>('openPdfFile', {
            'filePath': filePath,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('openPdfFile - PlatformException: ${e.code} - ${e.message}');
      return false;
    }
  }
}
