import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/pages/service_report_page.dart';
import 'package:elevator_quotation_app/utils/service_report_language.dart';
import 'package:elevator_quotation_app/utils/service_report_pdf_builder.dart';
import 'package:elevator_quotation_app/widgets/remarks_field.dart';
import 'service_report_checklist_test.dart' show sampleReport;

void main() {
  setUp(() {
    CloudPreferences.setMockInitialValues({});
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'tech',
        email: 'tech@example.com',
        role: 'user',
        masterUid: 'master',
        enabled: true,
        permissions: {'service': true},
      ),
    );
  });
  tearDown(() {
    CloudPreferences.clearMock();
    AccountSession.instance.update(null);
  });
  testWidgets(
    'New dates and months default correctly; saved values are preserved',
    (tester) async {
      final today = DateTime.now();
      await tester.pumpWidget(const MaterialApp(home: ServiceReportPage()));
      await tester.pumpAndSettle();
      final values = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text)
          .toList();
      expect(
        values.where((v) => v == '${today.day}/${today.month}/${today.year}'),
        hasLength(2),
      );
      final nextMonth = DateTime(today.year, today.month + 1);
      expect(
        values,
        contains(DateFormat('MMM yyyy').format(today).toUpperCase()),
      );
      expect(
        values,
        contains(DateFormat('MMM yyyy').format(nextMonth).toUpperCase()),
      );
      final report = sampleReport()
        ..date = '1/2/2024'
        ..liftServiceDate = '3/2/2024'
        ..serviceMonth = 'DEC 2024'
        ..nextServiceMonth = 'JAN 2025';
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceReportPage(
            key: const ValueKey('edit'),
            editReport: report,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final saved = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text);
      expect(
        saved,
        containsAll(['1/2/2024', '3/2/2024', 'DEC 2024', 'JAN 2025']),
      );
    },
  );
  for (final width in [320.0, 1200.0]) {
    testWidgets('Hindi switch preserves entered remarks and fits at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () =>
            (FontLoader('NotoService')..addFont(
                  rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'),
                ))
                .load(),
      );
      final report = sampleReport()..workDone = 'Custom entered remarks';
      report.checklist.first.remarks = 'Do not translate this';
      await tester.pumpWidget(
        MaterialApp(home: ServiceReportPage(editReport: report)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service_language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('हिंदी').last);
      await tester.pumpAndSettle();
      expect(find.text('सेवा रिपोर्ट संपादित करें'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('remarks_door')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('दरवाजे का संचालन'), findsOneWidget);
      expect(find.text('Do not translate this'), findsOneWidget);
      expect(find.byTooltip('बोलकर लिखें'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byType(RemarksField).last,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Custom entered remarks'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('service_language')),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('service_language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(find.text('Edit Service Report'), findsOneWidget);
      expect(report.workDone, 'Custom entered remarks');
    });
  }
  test('Bilingual wording uses English / Hindi and survives saving', () {
    const language = ServiceReportLanguage('en_hi');
    final hindi = ServiceReportLanguage.hindi['Service Report']!;
    final expected = 'Service Report / $hindi';
    expect(language.text('Service Report'), expected);
    expect(language.text(hindi), expected);
    expect(language.text(language.text('Service Report')), expected);
    expect(language.text('ABC Apartment'), 'ABC Apartment');
    final report = sampleReport()..languageCode = 'en_hi';
    expect(report.toJson()['languageCode'], 'en_hi');
  });
  test('Language is saved and custom words stay untouched', () {
    final report = sampleReport()..languageCode = 'hi';
    expect(report.toJson()['languageCode'], 'hi');
    const hi = ServiceReportLanguage('hi'), en = ServiceReportLanguage('en');
    expect(hi.text('Machine / motor'), 'मशीन / मोटर');
    expect(hi.text('ABC Apartment'), 'ABC Apartment');
    expect(en.month(hi.month('NOV 2026')), 'NOV 2026');
  });
  testWidgets('Bilingual PDF is shaped and generated using the real builder', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final report = sampleReport()
        ..languageCode = 'en_hi'
        ..buildingName = 'आदर्श अपार्टमेंट (नमूना)'
        ..servicePersonName = 'राहुल'
        ..customerPersonName = 'ग्राहक';
      report.checklist.first.remarks = 'दरवाजे का परीक्षण किया गया।';
      final bytes = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
      );
      final englishBytes = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
        includeHindi: false,
      );
      expect(englishBytes.length, greaterThan(10000));
      final bilingualBytes = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
        includeHindi: true,
      );
      expect(bilingualBytes.length, greaterThan(10000));
      expect(report.languageCode, 'en_hi');
      Directory('output/pdf').createSync(recursive: true);
      File('output/pdf/Hindi_Lift_Service_Report.pdf').writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(10000));
      report.checklist = List.generate(
        40,
        (index) => sampleReport().checklist.first,
      );
      final stress = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
      );
      Directory('tmp/pdfs').createSync(recursive: true);
      File('tmp/pdfs/hindi_checklist_stress.pdf').writeAsBytesSync(stress);
      expect(stress.length, greaterThan(10000));
    });
  });
}
