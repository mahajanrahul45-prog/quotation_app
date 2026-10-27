import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/auth/login_page.dart';
import 'package:elevator_quotation_app/pages/dashboard_page.dart';
import 'package:elevator_quotation_app/utils/app_theme.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    for (final dark in [false, true]) {
      testWidgets('Login and dashboard fit width $width, dark $dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        CloudPreferences.setMockInitialValues({});
        AccountSession.instance.update(
          const AccessProfile(
            uid: 'master',
            email: 'master@example.com',
            role: 'master',
            masterUid: 'master',
            enabled: true,
            permissions: {},
          ),
        );
        addTearDown(() {
          CloudPreferences.clearMock();
          AccountSession.instance.update(null);
        });
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: LoginPage(
              onLoginSuccess: (_) async {},
              onThemeToggle: () {},
              isDarkMode: dark,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        expect(find.text('Enter email'), findsOneWidget);
        expect(find.text('Enter password'), findsOneWidget);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: DashboardPage(toggleTheme: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Business overview'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();
        expect(find.text('Quotation Workspace'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
