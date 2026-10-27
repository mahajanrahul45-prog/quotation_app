import 'dart:convert';
import 'cloud_preferences.dart';
import '../models/company_model.dart';

class CompanyStorage {

  static const String _key = 'companies';

  // ================= LOAD ALL COMPANIES =================
  static Future<List<Company>> loadCompanies() async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    return list
        .map((e) => Company.fromJson(jsonDecode(e)))
        .toList();
  }

  // ================= SAVE NEW COMPANY =================
  static Future<void> saveCompany(Company company) async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    list.add(jsonEncode(company.toJson()));
    await prefs.setStringList(_key, list);
  }

  // ================= UPDATE EXISTING COMPANY =================
  // 🔹 FIXES YOUR ERROR
  static Future<void> updateCompany(int index, Company company) async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    // Safety check
    if (index < 0 || index >= list.length) return;

    list[index] = jsonEncode(company.toJson());
    await prefs.setStringList(_key, list);
  }

  // ================= DELETE COMPANY =================
  static Future<void> deleteCompany(int index) async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    await prefs.setStringList(_key, list);
  }
}
