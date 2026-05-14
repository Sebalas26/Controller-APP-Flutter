import 'package:controller_app_flutter/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders migrated login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(ControllerApp(preferences: preferences));

    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
