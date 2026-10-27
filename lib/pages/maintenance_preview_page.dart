import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/maintenance_quotation.dart';
import '../utils/maintenance_pdf_helper.dart';

class MaintenancePreviewPage extends StatelessWidget {
  final MaintenanceQuotation quotation;

  const MaintenancePreviewPage({super.key, required this.quotation});

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('maintenance')) {
      return const AccessDenied();
    }
    final String customerName = quotation.customerName;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Maintenance Print Preview'),

        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final bytes = await buildMaintenancePdfBytes(quotation);

              // 🔹 Create folder: Maintenance
              final dir = await getApplicationDocumentsDirectory();
              final folder = Directory('${dir.path}/Maintenance');

              if (!await folder.exists()) {
                await folder.create(recursive: true);
              }

              final file = File(
                '${folder.path}/${customerName.replaceAll(' ', '_')}.pdf',
              );

              await file.writeAsBytes(bytes);

              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  text: 'Maintenance quotation for $customerName',
                ),
              );
            },
          ),
        ],
      ),

      body: PdfPreview(
        pdfFileName: '${customerName.replaceAll(' ', '_')}.pdf',
        build: (format) async {
          return await buildMaintenancePdfBytes(quotation);
        },
      ),
    );
  }
}
