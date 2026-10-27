import 'dart:typed_data';
import 'package:flutter/widgets.dart';

Future<Uint8List?> captureBrowserPhoto(
  BuildContext context,
  String Function(String) translate,
) => throw UnsupportedError('Browser camera is only available on the web.');
