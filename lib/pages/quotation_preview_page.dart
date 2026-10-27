import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/quotation_pdf_helper.dart';

class QuotationPreviewPage extends StatelessWidget {
  final int quotationNumber;
  final List<Map<String, dynamic>> products;
  final List<List<Map<String, dynamic>>>? productTables;
  final List<bool>? tableTotalVisibility;
  final double totalAmount;
  final Map<String, dynamic>? selectedCustomer;

  const QuotationPreviewPage({
    super.key,
    required this.quotationNumber,
    required this.products,
    this.productTables,
    this.tableTotalVisibility,
    required this.totalAmount,
    this.selectedCustomer,
  });

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('quotations')) return const AccessDenied();
    // ✅ DEFINE HERE (inside build)
    final String customerName = selectedCustomer?['name'] ?? 'Quotation';
    final String area = selectedCustomer?['area'] ?? '';

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),

        // =====================================================
        // 🔹 CUSTOM WHATSAPP SHARE BUTTON
        // =====================================================
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              // 🔹 Generate PDF
              final bytes = await buildQuotationPdfBytes(
                quotationNumber: quotationNumber,
                customerName: customerName,
                area: area,
                products: products,
                productTables: productTables,
                tableTotalVisibility: tableTotalVisibility,
                totalAmount: totalAmount,
              );

              // 🔹 Create folder: Quotations
              final dir = await getApplicationDocumentsDirectory();
              final folder = Directory('${dir.path}/Quotations');

              if (!await folder.exists()) {
                await folder.create(recursive: true);
              }

              // 🔹 Create file name: CustomerName.pdf
              final file = File(
                '${folder.path}/${customerName.replaceAll(' ', '_')}.pdf',
              );

              await file.writeAsBytes(bytes);

              // =====================================================
              // 🔹 MODERN SHARE METHOD (NO DEPRECATED)
              // =====================================================
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  text: 'Quotation for $customerName',
                ),
              );
            },
          ),
        ],
      ),

      body: PdfPreview(
        pdfFileName: '${customerName.replaceAll(' ', '_')}.pdf',
        build: (format) async {
          return await buildQuotationPdfBytes(
            quotationNumber: quotationNumber,
            customerName: customerName,
            area: area,
            products: products,
            productTables: productTables,
            tableTotalVisibility: tableTotalVisibility,
            totalAmount: totalAmount,
          );
        },
      ),
    );
  }
}
