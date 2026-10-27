import 'package:elevator_quotation_app/storage/cloud_payload_codec.dart';

void main() {
  const oldPayload =
      'H4sIAAAAAAAC/6tWKsjPzCspVrKKrlYqSa0oUbJScsnPL1LIL0gtSizJzM9T0lFKTC7JLEtVsiopKk2tjdVRykhNTMnMSwcq9fF0C1EIdg0K83R2VQhyDfAPClGqBQA1UUa2VAAAAA==';
  final old = CloudPayloadCodec.decode(oldPayload) as Map;
  if (old['heading'] != 'LIFT SERVICE REPORT') {
    throw StateError('Old payload not readable');
  }
  final value = {
    'active': true,
    'remarks': 'Inspection complete',
    'points': ['Door operation', 'Emergency alarm'],
  };
  final decoded =
      CloudPayloadCodec.decode(CloudPayloadCodec.encode(value)) as Map;
  if (decoded['active'] != true ||
      decoded['remarks'] != value['remarks'] ||
      decoded['points'].length != 2) {
    throw StateError('JavaScript cloud compression failed');
  }
  // CLI verification output, not application logging.
  // ignore: avoid_print
  print('JavaScript gzip save/read and legacy payload compatibility passed.');
}
