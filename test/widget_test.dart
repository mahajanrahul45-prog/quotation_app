// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elevator_quotation_app/auth/login_page.dart';

void main() {
  testWidgets('Online sign-in requires email and password', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLoginSuccess: (_) async {},
          onThemeToggle: () {},
          isDarkMode: false,
        ),
      ),
    );

    // Verify that our counter starts at 0.
    expect(find.text('Welcome back'), findsOneWidget);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.text('Login'));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('Enter email'), findsOneWidget);
    expect(find.text('Enter password'), findsOneWidget);
  });
}
