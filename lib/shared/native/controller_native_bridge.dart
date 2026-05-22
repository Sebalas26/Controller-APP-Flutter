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
      print('takePackagePhoto - MissingPluginException: $e');
      return '';
    } on PlatformException catch (e) {
      print('takePackagePhoto - PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'PERMISSION_DENIED') {
        print('Permiso de cámara denegado. Verifica los permisos de la app.');
      } else if (e.code == 'CAMERA_ERROR' || e.code == 'CAMERA_LAUNCH_ERROR') {
        print('Error al abrir cámara: ${e.message}');
      }
      return '';
    } catch (e) {
      print('takePackagePhoto - Unexpected error: $e');
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
}
