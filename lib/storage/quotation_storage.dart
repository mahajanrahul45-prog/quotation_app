// lib/storage/quotation_storage.dart
import 'dart:convert';
import 'cloud_preferences.dart';
import '../models/quotation.dart';

class QuotationStorage {
  static const String _key = 'quotations';

  /// Save or update one quotation
  static Future<void> saveQuotation(Quotation q) async {
    final prefs = await CloudPreferences.getInstance();
    final list = await loadQuotations();

    final index = list.indexWhere(
      (e) => e.quotationNumber == q.quotationNumber,
    );

    if (index >= 0) {
      list[index] = q; // update existing
    } else {
      list.add(q); // insert new
    }

    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Load all quotations
  static Future<List<Quotation>> loadQuotations() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];

    return stored
        .map((s) => Quotation.fromJson(jsonDecode(s)))
        .toList();
  }

  /// ✅ DELETE quotation by number (FIXED)
  static Future<void> deleteQuotation(int quotationNumber) async {
    final prefs = await CloudPreferences.getInstance();

    final stored = prefs.getStringList(_key) ?? [];

    final filtered = stored.where((item) {
      final map = jsonDecode(item) as Map<String, dynamic>;
      return map['quotationNumber'] != quotationNumber;
    }).toList();

    await prefs.setStringList(_key, filtered);
  }

  /// Replace full list (used after bulk edits)
  static Future<void> saveAll(List<Quotation> list) async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.setStringList(
      _key,
      list.map((q) => jsonEncode(q.toJson())).toList(),
    );
  }

  /// Clear everything
  static Future<void> clearAll() async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Used by dashboard
  static Future<List<Map<String, dynamic>>> getAllQuotations() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];

    return stored.map((s) {
      try {
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        return {'_error': 'decode_failed'};
      }
    }).toList();
  }
}
