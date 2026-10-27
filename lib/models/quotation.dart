// lib/models/quotation.dart
import 'dart:convert';

class Quotation {
  final int quotationNumber;
  final String customerName;
  final DateTime date;
  final List<List<Map<String, dynamic>>> productTables;
  final List<bool> tableTotalVisibility;
  final double totalAmount;

  /// NEW: status of quotation: Active, Won, Lost, Abandoned
  String status;

  Quotation({
    required this.quotationNumber,
    required this.customerName,
    required this.date,
    required List<Map<String, dynamic>> products,
    List<List<Map<String, dynamic>>>? productTables,
    List<bool>? tableTotalVisibility,
    required this.totalAmount,
    this.status = 'Active', // default for old data & new ones
  }) : productTables = _normalizeTables(productTables ?? [products]),
       tableTotalVisibility = _normalizeTableVisibility(
         tableTotalVisibility,
         _normalizeTables(productTables ?? [products]).length,
       );

  List<Map<String, dynamic>> get products =>
      productTables.expand((table) => table).toList();

  static List<List<Map<String, dynamic>>> _normalizeTables(
    List<List<Map<String, dynamic>>> tables,
  ) {
    if (tables.isEmpty) {
      return [[]];
    }

    return tables.map((table) {
      return List<Map<String, dynamic>>.generate(table.length, (index) {
        final row = Map<String, dynamic>.from(table[index]);
        row['serial'] = index + 1;
        row['notes'] = row['notes'] ?? '';
        return row;
      });
    }).toList();
  }

  static List<bool> _normalizeTableVisibility(
    List<bool>? visibility,
    int tableCount,
  ) {
    if (tableCount <= 0) return [true];
    if (visibility == null || visibility.isEmpty) {
      return List<bool>.filled(tableCount, true);
    }

    return List<bool>.generate(tableCount, (index) {
      if (index < visibility.length) return visibility[index];
      return true;
    });
  }

  // ✅ Create from Map
  factory Quotation.fromMap(Map<String, dynamic> map) {
    final rawProductTables = map['productTables'];
    final List<List<Map<String, dynamic>>> parsedTables =
        rawProductTables is List
        ? rawProductTables
              .map<List<Map<String, dynamic>>>(
                (table) => List<Map<String, dynamic>>.from(
                  (table as List).map(
                    (row) => Map<String, dynamic>.from(row as Map),
                  ),
                ),
              )
              .toList()
        : [
            List<Map<String, dynamic>>.from(
              (map['products'] as List).map(
                (row) => Map<String, dynamic>.from(row as Map),
              ),
            ),
          ];

    return Quotation(
      quotationNumber: map['quotationNumber'] as int,
      customerName: map['customerName'] as String,
      date: DateTime.parse(map['date'] as String),
      products: parsedTables.first,
      productTables: parsedTables,
      tableTotalVisibility:
          (map['tableTotalVisibility'] as List?)
              ?.map((e) => e == true)
              .toList(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      // if old saved quotation has no "status", use "Active"
      status: (map['status'] ?? 'Active') as String,
    );
  }

  // Convert to Map (for JSON)
  Map<String, dynamic> toMap() {
    return {
      'quotationNumber': quotationNumber,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'products': products,
      'productTables': productTables,
      'tableTotalVisibility': tableTotalVisibility,
      'totalAmount': totalAmount,
      'status': status, // 🔴 important: save status too
    };
  }

  // ✅ JSON helpers
  String toJson() => jsonEncode(toMap());

  factory Quotation.fromJson(String source) =>
      Quotation.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
