// lib/utils/quotation_number_helper.dart

/// Builds quotation number like:
/// QTN NO./2025/001
///
/// year = financial year start (e.g. 2025)
/// number = running quotation number (e.g. 1)
String buildQuotationNumber({
  required int year,
  required int number,
}) {
  // Pad number to 3 digits → 001, 002, 010
  final padded = number.toString().padLeft(3, '0');

  return 'QTN NO./$year/$padded';
}
int getFinancialYear(DateTime date) {
  // April (4) is start of Indian financial year
  return (date.month >= 4) ? date.year : date.year - 1;
}
