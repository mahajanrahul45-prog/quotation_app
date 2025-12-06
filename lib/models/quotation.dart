// lib/models/quotation.dart
import 'dart:convert';

class Quotation {
  final int quotationNumber;
  final String customerName;
  final DateTime date;
  final List<Map<String, dynamic>> products; // product rows as maps
  final double totalAmount;
  /// NEW: status of quotation: Active, Won, Lost, Abandoned
  String status;

  Quotation({
    required this.quotationNumber,
    required this.customerName,
    required this.date,
    required this.products,
    required this.totalAmount,
    this.status = 'Active', // default for old data & new ones
  });



  // ✅ Create from Map
factory Quotation.fromMap(Map<String, dynamic> map) {
  return Quotation(
    quotationNumber: map['quotationNumber'] as int,
    customerName: map['customerName'] as String,
    date: DateTime.parse(map['date'] as String),
    products: List<Map<String, dynamic>>.from(
      (map['products'] as List),
    ),
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
      'totalAmount': totalAmount,
       'status': status, // 🔴 important: save status too
    };
  }


  
  // ✅ JSON helpers
String toJson() => jsonEncode(toMap());

factory Quotation.fromJson(String source) =>
    Quotation.fromMap(jsonDecode(source) as Map<String, dynamic>);

}
