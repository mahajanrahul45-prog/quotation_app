class MaintenanceQuotation {
  final int srNo;
  final int? renewedFromSrNo;
  final DateTime? renewedAt;
  final DateTime offerDate; // 🔹 NEW
  final String customerName;
  final String? area; // 👈 ADD THIS
  final DateTime startDate;
  final DateTime endDate;
  final int liftQty;
  final int months;
  final double liftAmount;
  final double monthlyAmount;
  final double totalAmount;
  final String status;

  MaintenanceQuotation({
    required this.srNo,
    this.renewedFromSrNo,
    this.renewedAt,
    required this.offerDate, // 🔹 NEW
    required this.customerName,
    this.area, // 👈 ADD
    required this.startDate,
    required this.endDate,
    required this.liftQty,
    required this.months,
    required this.liftAmount,
    required this.monthlyAmount,
    required this.totalAmount,
    required this.status, // ✅ ADD
  });

  Map<String, dynamic> toMap() => {
    'srNo': srNo,
    'renewedFromSrNo': renewedFromSrNo,
    'renewedAt': renewedAt?.toIso8601String(),

    // 🔹 SAVE OFFER DATE
    'offerDate': offerDate.toIso8601String(),

    // 🔹 CUSTOMER DETAILS
    'customer': customerName,
    'area': area, // ✅ ADD THIS
    // 🔹 PERIOD
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),

    // 🔹 AMOUNTS
    'liftQty': liftQty,
    'months': months,
    'liftAmount': liftAmount,
    'monthlyAmount': monthlyAmount,
    'totalAmount': totalAmount,

    // ✅ ADD THIS
    'status': status,
  };

  factory MaintenanceQuotation.fromMap(Map<String, dynamic> m) {
    return MaintenanceQuotation(
      srNo: (m['srNo'] as num).toInt(),
      renewedFromSrNo: (m['renewedFromSrNo'] as num?)?.toInt(),
      renewedAt: DateTime.tryParse(m['renewedAt']?.toString() ?? ''),

      // 🔹 LOAD OFFER DATE
      offerDate: m['offerDate'] != null
          ? DateTime.parse(m['offerDate'])
          : DateTime.now(),

      // 🔹 CUSTOMER DETAILS
      customerName: m['customer'],
      area: m['area'], // ✅ ADD THIS
      // 🔹 PERIOD
      startDate: DateTime.parse(m['startDate']),
      endDate: DateTime.parse(m['endDate']),

      // 🔹 AMOUNTS
      liftQty: m['liftQty'],
      months: m['months'],
      liftAmount: (m['liftAmount'] as num).toDouble(),
      monthlyAmount: (m['monthlyAmount'] as num).toDouble(),
      totalAmount: (m['totalAmount'] as num).toDouble(),
      // ✅ ADD THIS (SAFE DEFAULT)
      status: m['status'] ?? 'New',
    );
  }
}
