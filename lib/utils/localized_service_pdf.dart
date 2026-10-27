import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/service_report.dart';
import 'quotation_pdf_helper.dart';
import 'service_report_language.dart';

/// Flutter shapes Devanagari conjuncts and vowel marks before PDF embedding.
/// Each text cell is rendered at 288 dpi; tables still paginate normally.
class _ShapedPdfText {
  static Future<void>? _font;
  final _cache = <String, pw.MemoryImage>{};
  final _heights = <String, double>{};
  Future<pw.Widget> render(
    String text,
    double width, {
    double size = 10,
    bool bold = false,
    int color = 0xff202a32,
  }) async {
    _font ??= (FontLoader(
      'NotoService',
    )..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'))).load();
    await _font;
    final key = '$text|$width|$size|$bold|$color';
    if (!_cache.containsKey(key)) {
      const scale = 4.0;
      final paragraph =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(
                    textDirection: ui.TextDirection.ltr,
                    fontFamily: 'NotoService',
                    fontSize: size * scale,
                    fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
                  ),
                )
                ..pushStyle(ui.TextStyle(color: ui.Color(color)))
                ..addText(text))
              .build();
      paragraph.layout(ui.ParagraphConstraints(width: width * scale));
      final height = paragraph.height.ceil() + 4;
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
      final picture = recorder.endRecording();
      final image = await picture.toImage((width * scale).ceil(), height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      _cache[key] = pw.MemoryImage(bytes!.buffer.asUint8List());
      _heights[key] = height / scale;
      image.dispose();
      picture.dispose();
      paragraph.dispose();
    }
    return pw.Image(
      _cache[key]!,
      width: width,
      height: _heights[key],
      fit: pw.BoxFit.contain,
    );
  }
}

Future<Uint8List> buildLocalizedServiceReportPdf({
  required PdfPageFormat format,
  required ServiceReport report,
}) async {
  final language = ServiceReportLanguage(report.languageCode);
  String t(String value) => language.text(value);
  String value(String text) =>
      text.trim().isEmpty ? '____________________' : text;
  final renderer = _ShapedPdfText();
  final headerBuilder = await buildQuotationHeaderOnly();
  final width = format.width - 64;
  const ink = PdfColor.fromInt(0xff18344f),
      line = PdfColor.fromInt(0xffd2dde6),
      pale = PdfColor.fromInt(0xffedf3f7);
  Future<pw.Widget> cell(
    String text,
    double cellWidth, {
    bool bold = false,
  }) async => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: await renderer.render(text, cellWidth - 16, bold: bold),
  );
  Future<pw.Widget> section(int number, String heading) async => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
    child: await renderer.render(
      '${number.toString().padLeft(2, '0')}  ${t(heading)}',
      width,
      size: 11,
      bold: true,
      color: 0xff18344f,
    ),
  );
  Future<pw.Widget> pair(String left, String right) async => pw.Table(
    border: pw.TableBorder.all(color: line, width: .6),
    columnWidths: {
      0: const pw.FlexColumnWidth(),
      1: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        children: [await cell(left, width / 2), await cell(right, width / 2)],
      ),
    ],
  );
  final title = await renderer.render(
    t(report.heading),
    width,
    size: 16,
    bold: true,
    color: 0xff18344f,
  );
  final footer = await renderer.render(
    t('LIFT SERVICE REPORT | SERVICE RECORD'),
    width * .75,
    size: 8,
    color: 0xff626c74,
  );
  final body = <pw.Widget>[
    await section(1, 'REPORT & BUILDING DETAILS'),
    await pair(
      '${t('Report No.')}: ${report.srNo == 0 ? t('DRAFT') : report.srNo}',
      '${t('Date')}: ${value(report.date)}',
    ),
    await pair(
      '${t('Customer / Building Name')}: ${value(report.buildingName)}',
      '${t('Location')}: ${value(report.location)}',
    ),
    await pair(
      '${t('Lift quantity')}: ${report.liftQty}',
      '${t('Service month')}: ${language.month(value(report.serviceMonth))}',
    ),
    await pair(
      '${t('Lift serviced')}: ${value(report.liftServiceDate)}',
      '${t('Service person')}: ${value(report.servicePersonName)}',
    ),
    await section(2, 'BASIC SERVICE CHECKLIST'),
  ];
  final pointWidth = width * .4,
      statusWidth = width * .2,
      remarkWidth = width * .4;
  if (report.checklist.isEmpty) {
    body.add(await cell(t('No checklist recorded for this report.'), width));
  } else {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: pale),
        children: [
          await cell(t('Inspection point'), pointWidth, bold: true),
          await cell(t('Status'), statusWidth, bold: true),
          await cell(t('Remarks'), remarkWidth, bold: true),
        ],
      ),
    ];
    for (final point in report.checklist) {
      rows.add(
        pw.TableRow(
          children: [
            await cell(t(point.point), pointWidth),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 9,
                    height: 9,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: ink, width: .7),
                    ),
                    child: point.ok
                        ? pw.Text('X', style: const pw.TextStyle(fontSize: 7))
                        : null,
                  ),
                  pw.SizedBox(width: 5),
                  await renderer.render(
                    t(point.ok ? 'OK' : 'Not marked OK'),
                    statusWidth - 30,
                    size: 9,
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                await cell(
                  point.remarks.trim().isEmpty ? '-' : point.remarks,
                  remarkWidth,
                ),
                if (point.photoBase64.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: pw.Image(
                      pw.MemoryImage(base64Decode(point.photoBase64)),
                      width: remarkWidth - 16,
                      height: 90,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    body.add(
      pw.Table(
        border: pw.TableBorder.all(color: line, width: .6),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(3),
        },
        children: rows,
      ),
    );
  }
  body.addAll([
    await section(3, 'WORK DONE / REMARKS'),
    pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: line, width: .6),
      ),
      child: await renderer.render(
        report.workDone.trim().isEmpty
            ? t('No work remarks recorded.')
            : (ServiceReportLanguage.hindi.containsKey(report.workDone) ||
                      ServiceReportLanguage.hindi.containsValue(report.workDone)
                  ? t(report.workDone)
                  : report.workDone),
        width - 20,
      ),
    ),
    await section(4, 'LIFT STATUS & NEXT VISIT'),
    await pair(
      '${t('Lift status')}: ${t(value(report.liftStatus))}',
      '${t('Next service month')}: ${language.month(value(report.nextServiceMonth))}',
    ),
  ]);
  Uint8List? signature;
  if (report.customerSignatureBase64.isNotEmpty) {
    try {
      signature = base64Decode(report.customerSignatureBase64);
    } catch (_) {
      /* Legacy image fallback. */
    }
  }
  if (!kIsWeb && signature == null && report.customerSignaturePath.isNotEmpty) {
    final file = File(report.customerSignaturePath);
    if (await file.exists()) signature = await file.readAsBytes();
  }
  final blankSignature = await renderer.render(
    '${t('Signature')}: ____________________',
    width / 2 - 20,
  );
  body.add(
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          await section(5, 'ACKNOWLEDGEMENT'),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: .6),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pale),
                children: [
                  await cell(t('SERVICE PERSON'), width / 2, bold: true),
                  await cell(
                    t('CUSTOMER / REPRESENTATIVE'),
                    width / 2,
                    bold: true,
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  await cell(
                    '${t('Name')}: ${value(report.servicePersonName)}',
                    width / 2,
                  ),
                  await cell(
                    '${t('Name')}: ${value(report.customerPersonName)}',
                    width / 2,
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.SizedBox(height: 45, child: blankSignature),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: signature == null
                        ? pw.SizedBox(height: 45, child: blankSignature)
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
  );
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        children: [
          headerBuilder(),
          pw.SizedBox(height: 8),
          title,
          pw.SizedBox(height: 8),
          pw.Divider(color: line),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: line),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              footer,
              pw.Text(
                language.isHindi
                    ? '${context.pageNumber} / ${context.pagesCount}'
                    : 'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ],
      ),
      build: (_) => body,
    ),
  );
  return pdf.save();
}
