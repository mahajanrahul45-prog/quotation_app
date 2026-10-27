import 'localized_service_pdf.dart';
import 'service_report_language.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/service_report.dart';
import 'quotation_pdf_helper.dart';

Future<Uint8List> buildServiceReportPdfBytes({
  required PdfPageFormat format,
  required ServiceReport report,
  bool? includeHindi,
}) async {
  if (includeHindi != null) {
    report = ServiceReport.fromJson(report.toJson());
    report.languageCode = includeHindi ? 'en_hi' : 'en';
    final language = ServiceReportLanguage(report.languageCode);
    report.heading = language.text(report.heading);
    report.workDone = language.text(report.workDone);
    report.liftStatus = language.text(report.liftStatus);
    report.serviceMonth = language.month(report.serviceMonth);
    report.nextServiceMonth = language.month(report.nextServiceMonth);
    for (final point in report.checklist) {
      point.point = language.text(point.point);
    }
  }

  if (report.languageCode == 'hi' ||
      report.languageCode == 'en_hi' ||
      RegExp(r'[\u0900-\u097f]').hasMatch(jsonEncode(report.toJson()))) {
    return buildLocalizedServiceReportPdf(format: format, report: report);
  }
  final headerBuilder = await buildQuotationHeaderOnly();
  final pdf = pw.Document();
  const ink = PdfColor.fromInt(0xff18344f);
  const line = PdfColor.fromInt(0xffd2dde6);
  const pale = PdfColor.fromInt(0xffedf3f7);
  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      ),
    ),
  );
  pw.Widget cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
  String value(String text) =>
      text.trim().isEmpty ? '____________________' : text;
  pw.Widget pair(String left, String right) => pw.Table(
    border: pw.TableBorder.all(color: line, width: .6),
    columnWidths: {
      0: const pw.FlexColumnWidth(),
      1: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(children: [cell(left), cell(right)]),
    ],
  );
  Uint8List? signature;
  if (report.customerSignatureBase64.isNotEmpty) {
    try {
      signature = base64Decode(report.customerSignatureBase64);
    } catch (_) {
      /* Older reports may have only a local image. */
    }
  }
  if (signature == null && report.customerSignaturePath.isNotEmpty) {
    final file = File(report.customerSignaturePath);
    if (await file.exists()) signature = await file.readAsBytes();
  }
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      header: (context) => buildCommonPdfHeader(
        context: context,
        headerWidget: headerBuilder(),
        title: report.heading,
        showTitle: true,
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: line),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'LIFT SERVICE REPORT | SERVICE RECORD',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        section('01  REPORT & BUILDING DETAILS'),
        pair(
          'Report No.: ${report.srNo == 0 ? "DRAFT" : report.srNo}',
          'Date: ${value(report.date)}',
        ),
        pair(
          'Customer / Building Name: ${value(report.buildingName)}',
          'Location: ${value(report.location)}',
        ),
        pair(
          'Lift quantity: ${report.liftQty}',
          'Service month: ${value(report.serviceMonth)}',
        ),
        pair(
          'Lift serviced: ${value(report.liftServiceDate)}',
          'Service person: ${value(report.servicePersonName)}',
        ),
        section('02  BASIC SERVICE CHECKLIST'),
        if (report.checklist.isEmpty)
          cell('No checklist recorded for this report.'),
        if (report.checklist.isNotEmpty)
          pw.Table(
            border: pw.TableBorder.all(color: line, width: .6),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: pale),
                children: [
                  cell('Inspection point', bold: true),
                  cell('Status', bold: true),
                  cell('Remarks', bold: true),
                ],
              ),
              for (final point in report.checklist)
                pw.TableRow(
                  children: [
                    cell(point.point),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 9,
                            height: 9,
                            alignment: pw.Alignment.center,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: ink, width: .7),
                            ),
                            child: point.ok
                                ? pw.Text(
                                    'X',
                                    style: const pw.TextStyle(fontSize: 7),
                                  )
                                : null,
                          ),
                          pw.SizedBox(width: 5),
                          pw.Expanded(
                            child: pw.Text(
                              point.ok ? 'OK' : 'Not marked OK',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        cell(
                          point.remarks.trim().isEmpty ? '-' : point.remarks,
                        ),
                        if (point.photoBase64.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: pw.Image(
                              pw.MemoryImage(base64Decode(point.photoBase64)),
                              width: 140,
                              height: 90,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        section('03  WORK DONE / REMARKS'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: line, width: .6),
          ),
          child: pw.Text(
            report.workDone.trim().isEmpty
                ? 'No work remarks recorded.'
                : report.workDone,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ),
        section('04  LIFT STATUS & NEXT VISIT'),
        pair(
          'Lift status: ${value(report.liftStatus)}',
          'Next service month: ${value(report.nextServiceMonth)}',
        ),
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              section('05  ACKNOWLEDGEMENT'),
              pw.Table(
                border: pw.TableBorder.all(color: line, width: .6),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: pale),
                    children: [
                      cell('SERVICE PERSON', bold: true),
                      cell('CUSTOMER / REPRESENTATIVE', bold: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      cell('Name: ${value(report.servicePersonName)}'),
                      cell('Name: ${value(report.customerPersonName)}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.SizedBox(
                          height: 45,
                          child: pw.Text(
                            'Signature: ____________________',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: signature == null
                            ? pw.SizedBox(
                                height: 45,
                                child: pw.Text(
                                  'Signature: ____________________',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              )
                            : pw.Image(
                                pw.MemoryImage(signature),
                                height: 45,
                                fit: pw.BoxFit.contain,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return pdf.save();
}
