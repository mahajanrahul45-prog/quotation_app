import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static const String _keyQuotations = 'saved_quotations';
  static const String _keyLogoPath = 'page_logo_path';

  /// Save or update quotation
  static Future<void> saveQuotation(Map<String, dynamic> quotation) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_keyQuotations) ?? [];

    // if existing quotation number found, update instead of adding
    int index = saved.indexWhere((q) {
      final data = jsonDecode(q);
      return data['quotationNumber'] == quotation['quotationNumber'];
    });

    if (index >= 0) {
      saved[index] = jsonEncode(quotation);
    } else {
      saved.add(jsonEncode(quotation));
    }

    await prefs.setStringList(_keyQuotations, saved);
  }

  /// Get all saved quotations
  static Future<List<Map<String, dynamic>>> getQuotations() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_keyQuotations) ?? [];
    return saved.map((q) => jsonDecode(q) as Map<String, dynamic>).toList();
  }

  /// Save logo path
  static Future<void> saveLogoPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoPath, path);
  }

  /// Get logo path
  static Future<String?> getLogoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLogoPath);
  }

  /// Remove logo
  static Future<void> removeLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogoPath);
  }
}
