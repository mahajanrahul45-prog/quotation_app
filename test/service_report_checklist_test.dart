import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:elevator_quotation_app/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/models/service_checklist.dart';
import 'package:elevator_quotation_app/models/service_report.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/storage/cloud_payload_codec.dart';
import 'package:elevator_quotation_app/utils/service_report_pdf_builder.dart';
import 'package:elevator_quotation_app/pages/service_report_page.dart';

ServiceReport sampleReport() => ServiceReport(
  srNo: 1,
  date: '08/10/2026',
  buildingName: 'ABC Apartment (sample)',
  location: 'Pune, Maharashtra',
  liftQty: 1,
  serviceMonth: 'OCT 2026',
  liftServiceDate: '08/10/2026',
  customerPersonName: '',
  customerSignaturePath: '',
  customerSignatureBase64: '',
  servicePersonName: '',
  checklist: ServiceBodyTemplate.defaults().newInspections().map((p) {
    p.ok = true;
    return p;
  }).toList(),
  workDone: defaultServiceWork,
  liftStatus: 'Working Satisfactorily',
  nextServiceMonth: 'NOV 2026',
);

void main() {
  test('New cloud compression interoperates with old native gzip', () {
    final data = {
      'points': [
        {'text': 'Door operation', 'active': true},
      ],
    };
    expect(
      jsonDecode(
        utf8.decode(gzip.decode(base64Decode(CloudPayloadCodec.encode(data)))),
      ),
      data,
    );
    expect(
      CloudPayloadCodec.decode(
        base64Encode(gzip.encode(utf8.encode(jsonEncode(data)))),
      ),
      data,
    );
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('Service form keeps field labels separated at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ServiceReportPage(editReport: sampleReport()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final status = find.byKey(const ValueKey('service_lift_status'));
      final month = find.byKey(const ValueKey('service_next_month'));
      await tester.scrollUntilVisible(
        month,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(month).top - tester.getRect(status).bottom,
        greaterThanOrEqualTo(20),
      );
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('tmp/pdfs').createSync(recursive: true);
        File(
          'tmp/pdfs/service_form_${width.toInt()}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
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
  test(
    'Reports keep checklist, per-point remarks and visit details; legacy reports stay unassessed',
    () {
      final report = sampleReport();
      report.checklist.first.remarks = 'Adjusted door alignment';
      final decoded = ServiceReport.fromJson(
        jsonDecode(jsonEncode(report.toJson())),
      );
      expect(decoded.checklist.first.ok, true);
      expect(decoded.checklist.first.remarks, 'Adjusted door alignment');
      expect(decoded.nextServiceMonth, 'NOV 2026');
      expect(decoded.workDone, defaultServiceWork);
      expect(decoded.liftStatus, 'Working Satisfactorily');
      final old = ServiceReport.fromJson({
        'srNo': 7,
        'buildingName': 'Old building',
      });
      expect(old.checklist, isEmpty);
      expect(old.liftStatus, 'Not assessed');
      expect(old.workDone, isEmpty);
    },
  );
  test('Online body settings retain activation and custom points', () async {
    final template = ServiceBodyTemplate.defaults();
    template.points.first.active = false;
    template.points.add(
      ServiceChecklistPoint(id: 'custom', text: 'Pit cleanliness'),
    );
    await template.save();
    final loaded = await ServiceBodyTemplate.load();
    expect(
      loaded.newInspections().map((p) => p.point),
      isNot(contains('Door operation')),
    );
    expect(loaded.newInspections().last.point, 'Pit cleanliness');
    expect(loaded.newInspections().every((p) => !p.ok), true);
  });
  testWidgets('Returning from saved report body refreshes an open new report', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ServiceReportPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved Service Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Service Page Body'));
    await tester.pumpAndSettle();
    final point = find.widgetWithText(ListTile, 'Intercom');
    final checkbox = find.descendant(
      of: point,
      matching: find.byType(Checkbox),
    );
    await tester.scrollUntilVisible(
      checkbox,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(checkbox);
    await tester.scrollUntilVisible(
      find.text('Save body settings'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save body settings'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Intercom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Service-only user saves activation and sees it back on the report',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ServiceReportPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Configure service checklist'));
      await tester.pumpAndSettle();
      final point = find.widgetWithText(ListTile, 'Emergency alarm');
      final checkbox = find.descendant(
        of: point,
        matching: find.byType(Checkbox),
      );
      await tester.scrollUntilVisible(
        checkbox,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(checkbox);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Save body settings'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save body settings'));
      await tester.pumpAndSettle();
      expect(find.text('Service report body'), findsNothing);
      expect(find.text('Emergency alarm'), findsOneWidget);
      final loaded = await ServiceBodyTemplate.load();
      expect(loaded.points.firstWhere((p) => p.id == 'alarm').active, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Active inspection points appear in service-only form on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final template = ServiceBodyTemplate(
        points: [
          ServiceChecklistPoint(id: 'active', text: 'Door operation'),
          ServiceChecklistPoint(
            id: 'hidden',
            text: 'Hidden inspection',
            active: false,
          ),
        ],
      );
      await template.save();
      await tester.pumpWidget(const MaterialApp(home: ServiceReportPage()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Door operation'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Hidden inspection'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
    },
  );
  test(
    'Generate professional sample and multi-page stress PDF with the real builder',
    () async {
      final report = sampleReport();
      final bytes = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
      );
      final dir = Directory('output/pdf')..createSync(recursive: true);
      File(
        '${dir.path}/Professional_Lift_Service_Report.pdf',
      ).writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(1000));
      report.checklist = List.generate(
        40,
        (i) => ServiceInspection(
          id: '$i',
          point: 'Inspection point ${i + 1}',
          ok: i.isEven,
          remarks:
              'Checked operation and recorded condition for this inspection point.',
        ),
      );
      final stress = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
      );
      Directory('tmp/pdfs').createSync(recursive: true);
      File('tmp/pdfs/checklist_stress.pdf').writeAsBytesSync(stress);
      expect(stress.length, greaterThan(bytes.length));
    },
  );
}
