import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:elevator_quotation_app/models/service_checklist.dart';
import 'package:elevator_quotation_app/models/service_report.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/storage/cloud_payload_codec.dart';
import 'package:elevator_quotation_app/utils/service_report_pdf_builder.dart';
import 'package:elevator_quotation_app/widgets/inspection_photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String photo;
  setUp(() async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = Colors.blue);
    final picture = recorder.endRecording();
    final image = await picture.toImage(40, 40);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    photo = base64Encode(data.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    CloudPreferences.setMockInitialValues({});
  });
  tearDown(CloudPreferences.clearMock);
  testWidgets(
    'Photo icon offers camera and library on Android',
    (tester) async {
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectionPhoto(
              photoBase64: '',
              point: 'Door operation',
              languageCode: 'en',
              onChanged: (_) => changed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from library'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsNothing);
      expect(changed, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  test('Photo survives report serialization and compressed cloud payload', () {
    final report = ServiceReport.fromJson({
      'checklist': [
        ServiceInspection(
          id: 'door',
          point: 'Door operation',
          photoBase64: photo,
        ).toJson(),
      ],
    });
    final restored = ServiceReport.fromJson(
      Map<String, dynamic>.from(
        CloudPayloadCodec.decode(CloudPayloadCodec.encode(report.toJson()))
            as Map,
      ),
    );
    expect(restored.checklist.single.photoBase64, photo);
    expect(
      ServiceInspection.fromJson({'id': 'old', 'point': 'Motor'}).photoBase64,
      isEmpty,
    );
  });
  testWidgets('Photo preview, removal and upload icon fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var value = photo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => InspectionPhoto(
              photoBase64: value,
              point: 'Machine room cleanliness',
              languageCode: 'en',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Replace photo'), findsOneWidget);
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    expect(value, isEmpty);
    expect(find.text('Add photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('English and Hindi PDF builders include inspection photos', (
    tester,
  ) async {
    for (final language in ['en', 'hi']) {
      final report = ServiceReport.fromJson({
        'languageCode': language,
        'checklist': [
          ServiceInspection(
            id: 'door',
            point: 'Door operation',
            photoBase64: photo,
          ).toJson(),
        ],
      });
      final bytes = await tester.runAsync(
        () => buildServiceReportPdfBytes(
          format: PdfPageFormat.a4,
          report: report,
        ),
      );
      expect(bytes!.length, greaterThan(1000));
      expect(
        RegExp(
          r'/Subtype\s*/Image/Width 40/Height 40',
        ).hasMatch(latin1.decode(bytes)),
        isTrue,
      );
    }
  });
}
