import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Versioned, integrity-checked workspace archive; also reads original backups.
class WorkspaceBackup {
  static const format = 'quotation_workspace';
  static String encode(Map<String, dynamic> values) {
    final payload = jsonEncode(values);
    return jsonEncode({
      'format': format,
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    });
  }

  static Map<String, dynamic> decode(String contents) {
    final root = jsonDecode(contents);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Select a quotation app backup JSON file.');
    }
    if (root['format'] == format) {
      if (root['version'] != 1) {
        throw const FormatException('This backup version is not supported.');
      }
      final payload = root['payload'];
      if (payload is! String ||
          sha256.convert(utf8.encode(payload)).toString() != root['sha256']) {
        throw const FormatException('Backup is damaged or has been modified.');
      }
      final values = jsonDecode(payload);
      if (values is! Map<String, dynamic> || values.isEmpty) {
        throw const FormatException('Backup contains no workspace data.');
      }
      return values;
    }
    // The original exporter always included these four sections.
    if (![
      'models',
      'customers',
      'quotations',
      'settings',
    ].every(root.containsKey)) {
      throw const FormatException('This is not a quotation app backup.');
    }
    final values = <String, dynamic>{};
    for (final key in ['models', 'customers', 'quotations']) {
      final list = root[key];
      if (list is! List || !list.every((item) => item is String)) {
        throw FormatException('Invalid backup section: $key.');
      }
      values[key] = list.cast<String>();
    }
    final settings = root['settings'];
    if (settings is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup settings.');
    }
    const allowed = {
      'watermarkOpacity',
      'logoPath',
      'company_name',
      'company_address',
      'company_phone',
      'company_contact',
      'company_email',
      'company_website',
      'company_gstin',
      'header_logo_on_left',
      'page_setup_watermark',
    };
    for (final entry in settings.entries) {
      if (!allowed.contains(entry.key)) {
        throw const FormatException('Unrecognized legacy backup setting.');
      }
      final value = entry.value;
      if (value == null) continue;
      final valid = entry.key == 'watermarkOpacity'
          ? value is num
          : entry.key == 'header_logo_on_left'
          ? value is bool
          : value is String;
      if (!valid) throw FormatException('Invalid setting: ${entry.key}.');
      values[entry.key] = value;
    }
    return values;
  }
}
