import 'dart:convert';
import 'package:archive/archive.dart';

/// Standard gzip + base64 on Android, Windows and browsers. The wire format
/// matches the native dart:io codec used by existing Firestore payloads.
class CloudPayloadCodec {
  static String encode(Object? value) {
    final compressed = GZipEncoder().encode(utf8.encode(jsonEncode(value)));
    if (compressed == null) throw StateError('Could not compress online data.');
    return base64Encode(compressed);
  }

  static dynamic decode(String encoded) => jsonDecode(
    utf8.decode(GZipDecoder().decodeBytes(base64Decode(encoded), verify: true)),
  );
}
