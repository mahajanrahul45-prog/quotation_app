import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/widgets/remarks_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Future<void> notify(String method, dynamic arguments) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'locales':
          return ['en_IN:English India', 'hi_IN:Hindi India'];
        case 'listen':
          return true;
        default:
          return null;
      }
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'Dictation uses selected Hindi locale and replaces partial results without duplication',
    (tester) async {
      final text = TextEditingController(text: 'Checked');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemarksField(
              controller: text,
              label: 'Remarks',
              languageCode: 'hi',
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      await tester.pump();
      final listen = calls.firstWhere((c) => c.method == 'listen');
      expect(listen.arguments['localeId'], 'hi_IN');
      await notify('notifyStatus', 'listening');
      await tester.pump();
      await notify(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'दरवाजा', 'confidence': 1.0},
          ],
          'resultType': 0,
        }),
      );
      await tester.pump();
      expect(text.text, 'Checked दरवाजा');
      await notify(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'दरवाजा ठीक है', 'confidence': 1.0},
          ],
          'resultType': 2,
        }),
      );
      await tester.pump();
      expect(text.text, 'Checked दरवाजा ठीक है');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls.any((c) => c.method == 'cancel'), true);
      text.dispose();
    },
  );
  testWidgets('Switching fields routes words only to the current microphone', (
    tester,
  ) async {
    final first = TextEditingController(), second = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RemarksField(controller: first, label: 'First'),
              RemarksField(controller: second, label: 'Second'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.mic_none).first);
    await tester.pump();
    await tester.pump();
    await notify('notifyStatus', 'listening');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_none).last);
    await tester.pump();
    await tester.pump();
    await notify(
      'textRecognition',
      jsonEncode({
        'alternates': [
          {'recognizedWords': 'Motor inspected', 'confidence': 1.0},
        ],
        'resultType': 2,
      }),
    );
    await tester.pump();
    expect(first.text, isEmpty);
    expect(second.text, 'Motor inspected');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    first.dispose();
    second.dispose();
  });
}
