import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class ControllerFirebaseMessagingService {
  ControllerFirebaseMessagingService({FirebaseMessaging? messaging})
    : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) return;

    try {
      await Firebase.initializeApp();
    } on Object {
      try {
        if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      } on Object {
        // Tests and unsupported platforms can keep running without Firebase.
      }
    }
  }

  Stream<String> get onTokenRefresh {
    final messaging = _messagingInstance;
    if (messaging == null) return const Stream<String>.empty();
    return messaging.onTokenRefresh.where((token) => token.trim().isNotEmpty);
  }

  Future<String> getTokenFirebase() async {
    final messaging = _messagingInstance;
    if (messaging == null) return '';
    await _prepareMessaging();

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await messaging.getToken();
        if (token != null && token.trim().isNotEmpty) return token.trim();
      } on Exception catch (error, stackTrace) {
        debugPrint('Error al obtener token Firebase: $error');
        debugPrint('$stackTrace');
      } catch (error, stackTrace) {
        debugPrint('Error inesperado al obtener token Firebase: $error');
        debugPrint('$stackTrace');
      }
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }

    try {
      await messaging.deleteToken();
      return (await messaging.getToken())?.trim() ?? '';
    } on Object {
      return '';
    }
  }

  FirebaseMessaging? get _messagingInstance {
    if (_messaging != null) return _messaging;
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } on Object {
      return null;
    }
  }

  Future<void> _prepareMessaging() async {
    final messaging = _messagingInstance;
    if (messaging == null) return;
    try {
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await _waitForApplePushToken(messaging);
    } on Object {
      // Token retrieval can still work even when permission APIs are unavailable.
    }
  }

  Future<void> _waitForApplePushToken(FirebaseMessaging messaging) async {
    if (!_shouldWaitForApplePushToken) return;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await messaging.getAPNSToken();
        if (token != null && token.trim().isNotEmpty) return;
      } on Object {
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
  }

  bool get _shouldWaitForApplePushToken {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
}
