//import 'dart:typed_data'; // Uint8List (binary bytes) returned by _generatePdf
//import 'dart:io';
import 'package:flutter/material.dart'; // Flutter UI
//import 'package:pdf/pdf.dart'; // pdf package primitives (PdfColors, formats)
//import 'package:pdf/widgets.dart' as pw; // pdf widgets (pw = pdf widgets namespace)
import 'package:printing/printing.dart'; // PdfPreview widget and printing helpers
//import '../data/customers_data.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import '../utils/quotation_pdf_helper.dart';

class QuotationPreviewPage extends StatelessWidget {
  final int quotationNumber;
  final List<Map<String, dynamic>> products;
  final double totalAmount;
  final Map<String, dynamic>? selectedCustomer; // ✅ added // optional customer info

  const QuotationPreviewPage({
    super.key,
    required this.quotationNumber,
    required this.products,
    required this.totalAmount,
    this.selectedCustomer, // ✅ added
  });

    @override
  Widget build(BuildContext context) {
    final String customerName = selectedCustomer?['name'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
      ),
      body: PdfPreview(
        useActions: true, // shows print / share buttons
        canChangePageFormat: true,
        build: (format) => buildQuotationPdfBytes(
          quotationNumber: quotationNumber,
          customerName: customerName,
          products: products,
          totalAmount: totalAmount,
        ),
      ),
    );
  }
}

