// lib/storage/quotation_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quotation.dart';

class QuotationStorage {
    static const _key = 'quotations';

  // Save one quotation (append) Accepts a Quotation object.
  static Future<void> saveQuotation(Quotation q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadQuotations();
    final existingIndex =
        list.indexWhere((e) => e.quotationNumber == q.quotationNumber);
    if (existingIndex >= 0) {
      list[existingIndex] = q; // update existing
    } else {
      list.add(q); // add new
    }
    await prefs.setStringList(
        _key, list.map((e) => jsonEncode(e.toJson())).toList());
  }

  // Load all saved quotations (most recent last)
  static Future<List<Quotation>> loadQuotations() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> stored = prefs.getStringList(_key) ?? [];
    // ✅ Decode each JSON string into a Map before converting
    return stored.map((s) => Quotation.fromJson(jsonDecode(s))).toList();
  }

  // Replace full list (useful for delete or edit)
  static Future<void> saveAll(List<Quotation> list) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = list.map((q) => q.toJson()).toList();
    await prefs.setStringList(_key, jsonList);
  }

  // Clear all (careful)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
  // 🚀 NEW METHOD: Returns all quotations as List<Map> for dashboard
static Future<List<Map<String, dynamic>>> getAllQuotations() async {
  final prefs = await SharedPreferences.getInstance();

  final List<String> stored = prefs.getStringList(_key) ?? [];

  return stored.map((s) {
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {'_error': 'decode failed', 'raw': s};
    }
  }).toList();
}

}
