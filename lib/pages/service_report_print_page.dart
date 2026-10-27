import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import '../models/service_report.dart';
import '../utils/service_report_pdf_builder.dart';

class ServiceReportPrintPage extends StatelessWidget {
  final ServiceReport report;
  const ServiceReportPrintPage({super.key, required this.report});
  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('service')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Service Report PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Send PDF',
            onPressed: () => sharePdf(context, report),
          ),
        ],
      ),
      body: const Center(
        child: Text('Tap the share icon to send Service Report PDF'),
      ),
    );
  }

  static Future<void> sharePdf(
    BuildContext context,
    ServiceReport report,
  ) async {
    try {
      final bytes = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
      );
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: ['Lift_Service_Report_${report.srNo}.pdf'],
          text:
              'Service Report\nCustomer / Building Name: ${report.buildingName}\nDate: ${report.date}',
          subject: 'Service Report - ${report.buildingName}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not prepare PDF: $e')));
      }
    }
  }
}
