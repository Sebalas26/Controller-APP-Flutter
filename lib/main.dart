import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/controller_app.dart';
import 'shared/firebase/controller_firebase_messaging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ControllerFirebaseMessagingService.initialize();
  final prefs = await SharedPreferences.getInstance();
  runApp(ControllerApp(preferences: prefs));
}
