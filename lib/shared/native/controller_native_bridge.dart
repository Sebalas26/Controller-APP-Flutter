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
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<String> compressImageBase64ToJpeg(
    String imageBase64, {
    int maxDimension = 960,
    int quality = 50,
  }) async {
    try {
      return await _channel.invokeMethod<String>('compressImageBase64ToJpeg', {
            'imageBase64': imageBase64,
            'maxDimension': maxDimension,
            'quality': quality,
          }) ??
          '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }
}
