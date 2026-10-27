import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/pages/saved_service_reports_page.dart';
import 'package:elevator_quotation_app/utils/app_theme.dart';
import 'service_report_checklist_test.dart' show sampleReport;

void main() {
  setUp(() {
    final first = sampleReport()..buildingName = 'Zeta Heights'..location = 'Pune, Maharashtra'..servicePersonName = 'Rahul Mahajan';
    final second = sampleReport()..srNo = 2..buildingName = 'Adarsh Apartments'..liftStatus = 'Out of service'..languageCode = 'hi';
    CloudPreferences.setMockInitialValues({'service_reports': jsonEncode([first.toJson(), second.toJson()])});
    AccountSession.instance.update(const AccessProfile(uid: 'tech', email: 'tech@example.com', role: 'user', masterUid: 'master', enabled: true, permissions: {'service': true}));
  });
  tearDown(() { CloudPreferences.clearMock(); AccountSession.instance.update(null); });
  testWidgets('Search and status filters leave saved records intact', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SavedServiceReportsPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zeta'); await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved_service_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved_service_2')), findsNothing);
    await tester.tap(find.byTooltip('Clear search')); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status_All statuses'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Out of service').last); await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved_service_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved_service_1')), findsNothing);
    await tester.enterText(find.byType(TextField), 'not found'); await tester.pumpAndSettle();
    expect(find.text('No matching reports'), findsOneWidget);
    final prefs = await CloudPreferences.getInstance();
    expect((jsonDecode(prefs.getString('service_reports')!) as List).length, 2);
  });
  testWidgets('Deleting a filtered report preserves other reports', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SavedServiceReportsPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zeta'); await tester.pumpAndSettle();
    final actions = find.descendant(of: find.byKey(const ValueKey('saved_service_1')), matching: find.byType(PopupMenuButton<String>));
    await tester.ensureVisible(actions); await tester.tap(actions); await tester.pumpAndSettle();
    await tester.tap(find.text('Delete report')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete report')); await tester.pumpAndSettle();
    final prefs = await CloudPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('service_reports')!) as List;
    expect(saved.length, 1); expect(saved.single['srNo'], 2);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('Professional report cards fit at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => (FontLoader('NotoService')..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'))).load());
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: MaterialApp(theme: AppTheme.lightTheme.copyWith(textTheme: AppTheme.lightTheme.textTheme.apply(fontFamily: 'NotoService')), home: const SavedServiceReportsPage())));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('saved_service_2'));
      await tester.ensureVisible(card); await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(); final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('tmp/pdfs').createSync(recursive: true);
        File('tmp/pdfs/saved_service_reports_${width.toInt()}.png').writeAsBytesSync(data!.buffer.asUint8List()); image.dispose();
      });
    });
  }
}
