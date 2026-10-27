import 'dart:convert';
import '../storage/cloud_preferences.dart';

/// Uses the same account-scoped customer store as the customer forms.
class CustomersFirestore {
  static Future<void> saveCustomer(Map<String, dynamic> customer) async {
    final prefs = await CloudPreferences.getInstance();
    final list = (prefs.getStringList('customers') ?? [])
        .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
        .toList();
    final index = list.indexWhere(
      (c) => c['customerName'] == customer['customerName'],
    );
    if (index < 0) {
      list.add(customer);
    } else {
      list[index] = {...list[index], ...customer};
    }
    await prefs.setStringList('customers', list.map(jsonEncode).toList());
  }

  static Future<void> deleteCustomer(String customerName) async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList('customers') ?? [];
    await prefs.setStringList(
      'customers',
      list.where((s) => jsonDecode(s)['customerName'] != customerName).toList(),
    );
  }
}
