import 'package:flutter/foundation.dart';
import '../utils/service_report_language.dart';
import '../widgets/service_language_scope.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../models/service_report.dart';
import '../utils/service_report_pdf_builder.dart'; // we’ll create this

class ServiceReportPreviewPage extends StatefulWidget {
  final ServiceReport report;

  const ServiceReportPreviewPage({super.key, required this.report});

  @override
  State<ServiceReportPreviewPage> createState() =>
      _ServiceReportPreviewPageState();
}

class _ServiceReportPreviewPageState extends State<ServiceReportPreviewPage> {
  ServiceReport get report => widget.report;
  late bool _includeHindi;

  @override
  void initState() {
    super.initState();
    _includeHindi = report.languageCode != 'en';
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('service')) return const AccessDenied();
    final language = ServiceReportLanguage(report.languageCode);
    return ServiceLanguageScope(
      code: report.languageCode,
      child: AppScaffold(
        appBar: AppBar(
          title: Text(language.text('Service Report Preview')),
          actions: [
            IconButton(
              tooltip: language.text('Download PDF'),
              icon: const Icon(Icons.download),
              onPressed: () => _download(context),
            ),
          ],
        ),

        // ✅ REAL PDF PREVIEW
        body: Column(
          children: [
            SwitchListTile(
              key: const ValueKey('pdf_include_hindi'),
              title: const Text('Show Hindi in PDF'),
              subtitle: Text(
                _includeHindi ? 'English / Hindi' : 'English only',
              ),
              value: _includeHindi,
              onChanged: (value) => setState(() => _includeHindi = value),
            ),
            Expanded(
              child: PdfPreview(
                key: ValueKey(_includeHindi),
                build: (PdfPageFormat format) {
                  return buildServiceReportPdfBytes(
                    format: format,
                    report: report,
                    includeHindi: _includeHindi,
                  );
                },

                // Optional buttons
                canChangePageFormat: true,
                canChangeOrientation: true,
                allowPrinting: true,
                allowSharing: true,
                pdfFileName: 'Lift_Service_Report_${report.srNo}.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    try {
      final bytes = await buildServiceReportPdfBytes(
        format: PdfPageFormat.a4,
        report: report,
        includeHindi: _includeHindi,
      );
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save lift service report',
        fileName: 'Lift_Service_Report_${report.srNo}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (saved == null) return;
      // Mobile pickers save the supplied bytes; desktop pickers return a path.
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await File(saved).writeAsBytes(bytes);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service report PDF saved.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save PDF: $e')));
      }
    }
  }
}
