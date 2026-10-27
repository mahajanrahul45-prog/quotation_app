import '../models/maintenance_lifecycle.dart';
import 'dart:convert';
import 'cloud_preferences.dart';
import '../models/maintenance_quotation.dart';

class MaintenanceQuotationStorage {
  static const _key = 'maintenance_quotations';

  // =====================================================
  // 🔹 LOAD ALL SAVED MAINTENANCE QUOTATIONS
  // =====================================================
  static Future<List<MaintenanceQuotation>> load() async {
    final prefs = await CloudPreferences.getInstance();

    // 🔹 Read stored JSON list
    final list = prefs.getStringList(_key) ?? [];

    // 🔹 Convert JSON → Model
    return list
        .map((e) => MaintenanceQuotation.fromMap(jsonDecode(e)))
        .toList();
  }

  // =====================================================
  // 🔹 SAVE OR UPDATE MAINTENANCE QUOTATION
  // =====================================================
  static Future<void> save(MaintenanceQuotation q) async {
    final prefs = await CloudPreferences.getInstance();

    // 🔹 Load existing saved quotations
    final list = prefs.getStringList(_key) ?? [];

    final all = list
        .map((e) => MaintenanceQuotation.fromMap(jsonDecode(e)))
        .toList();
    if (q.endDate.isBefore(q.startDate) ||
        q.months <= 0 ||
        q.liftQty <= 0 ||
        !q.liftAmount.isFinite ||
        !q.totalAmount.isFinite ||
        !q.monthlyAmount.isFinite ||
        q.liftAmount < 0) {
      throw StateError(
        'Enter a valid contract period, quantity, duration and amount.',
      );
    }
    if (q.renewedFromSrNo != null && !all.any((e) => e.srNo == q.srNo)) {
      final source = all.where((e) => e.srNo == q.renewedFromSrNo).firstOrNull;
      if (source == null || MaintenanceLifecycle.superseded(source, all)) {
        throw StateError(
          'This contract has already been renewed or is no longer available. Refresh the list.',
        );
      }
      if (q.customerName != source.customerName ||
          (q.area ?? '') != (source.area ?? '') ||
          !MaintenanceLifecycle.day(
            q.startDate,
          ).isAfter(MaintenanceLifecycle.day(source.endDate)) ||
          q.renewedAt == null) {
        throw StateError(
          'The renewal must retain the customer and start after the previous contract ends.',
        );
      }
    }

    // =====================================================
    // 🔹 STEP 1 — CHECK IF THIS SR NO ALREADY EXISTS
    // =====================================================
    final idx = list.indexWhere((e) {
      final m = jsonDecode(e);
      return m['srNo'] == q.srNo;
    });

    // =====================================================
    // 🔹 STEP 2 — UPDATE OR INSERT
    // =====================================================
    if (idx >= 0) {
      // ✅ EDIT MODE → UPDATE EXISTING RECORD
      list[idx] = jsonEncode(q.toMap());
    } else {
      // ✅ NEW MODE → ADD NEW RECORD
      list.add(jsonEncode(q.toMap()));
    }

    // =====================================================
    // 🔹 STEP 3 — SAVE BACK TO SHARED PREFERENCES
    // =====================================================
    await prefs.setStringList(_key, list);
  }
}
