import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/storage/cloud_payload_codec.dart';

void main() {
  test('Cloud compression works without native dart:io in a browser', () {
    final payload = {
      '__cloudJson': {
        'heading': 'LIFT SERVICE REPORT',
        'points': [
          {'id': 'alarm', 'text': 'Emergency alarm', 'active': true},
        ],
        'workDone': 'Routine maintenance completed.',
      },
    };
    final encoded = CloudPayloadCodec.encode(payload);
    expect(base64Decode(encoded).take(2).toList(), [0x1f, 0x8b]);
    expect(CloudPayloadCodec.decode(encoded), payload);
  });
  test('Existing standard gzip cloud data remains readable', () {
    const fixture =
        'H4sIAAAAAAAC/6tWKsjPzCspVrKKrlYqSa0oUbJScsnPL1LIL0gtSizJzM9T0lFKTC7JLEtVsiopKk2tjdVRykhNTMnMSwcq9fF0C1EIdg0K83R2VQhyDfAPClGqBQA1UUa2VAAAAA==';
    expect(CloudPayloadCodec.decode(fixture), {
      'points': [
        {'text': 'Door operation', 'active': true},
      ],
      'heading': 'LIFT SERVICE REPORT',
    });
  });
  test('Browser codec preserves long and non-ASCII remarks', () {
    final value = {
      'remarks': List.filled(1000, 'Lift checked — सेवा पूर्ण').join('\n'),
      'active': false,
    };
    expect(CloudPayloadCodec.decode(CloudPayloadCodec.encode(value)), value);
  });
}
