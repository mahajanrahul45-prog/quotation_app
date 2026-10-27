// lib/utils/quotation_pdf_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../storage/cloud_preferences.dart';
import 'quotation_number_helper.dart';

// =====================================================
// 🔹 NUMBER TO WORDS (Indian format)
// =====================================================
String numberToWords(double amount) {
  final units = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  final tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  String convert(int n) {
    if (n < 20) return units[n];
    if (n < 100) {
      return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${units[n % 10]}' : ''}';
    }
    if (n < 1000) {
      return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${convert(n % 100)}' : ''}';
    }
    if (n < 100000) {
      return '${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convert(n % 1000)}' : ''}';
    }
    if (n < 10000000) {
      return '${convert(n ~/ 100000)} Lakh${n % 100000 != 0 ? ' ${convert(n % 100000)}' : ''}';
    }
    return '${convert(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ${convert(n % 10000000)}' : ''}';
  }

  final int rupees = amount.round();
  return '${convert(rupees)} Only';
}



Uint8List? _cachedLogoBytes;
Uint8List? _cachedSignatureBytes;
String? _cachedLogoPath;
String? _cachedSignatureBase64;

// =====================================================
// 🔹 BUILD COMPANY SHORT CODE (MT from Mayara Technologies)
// =====================================================
String buildCompanyShortCode(String companyName) {
  if (companyName.trim().isEmpty) return '';

  final parts = companyName.trim().split(RegExp(r'\s+'));

  if (parts.length == 1) {
    return parts[0][0].toUpperCase();
  }

  // take first letter of first 2 words
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

Future<Map<String, dynamic>?> loadSelectedPrintBodyTemplate() async {
  final prefs = await CloudPreferences.getInstance();

  final selected = prefs.getString('selected_print_body');
  if (selected == null) return null;

  final list = prefs.getStringList('print_body_templates') ?? [];

  for (final item in list) {
    final map = jsonDecode(item);
    if (map['name'] == selected) return map;
  }

  return null;
}

/// Common function to build quotation PDF bytes.
/// Used in:
/// 1) Quotation page -> Export PDF
/// 2) QuotationPreviewPage (from quotation page)
/// 3) QuotationPreviewPage (from saved quotation page)
Future<Uint8List> buildQuotationPdfBytes({
  required int quotationNumber,
  required String customerName,
  required String area,
  required List<Map<String, dynamic>> products,
  List<List<Map<String, dynamic>>>? productTables,
  List<bool>? tableTotalVisibility,
  required double totalAmount,
}) async {
  final normalizedTables = (productTables == null || productTables.isEmpty)
      ? [products]
      : productTables;
  final normalizedTableVisibility = List<bool>.generate(
    normalizedTables.length,
    (index) => index < (tableTotalVisibility?.length ?? 0)
        ? tableTotalVisibility![index]
        : true,
  );

  // 1️⃣ Read Page Setup values from CloudPreferences
  final prefs = await CloudPreferences.getInstance();

  // =====================================================
  // 🔹 PAGE SETUP: SHOW / HIDE BANK DETAILS
  // =====================================================
  final bool showBankDetails = prefs.getBool('show_bank_details') ?? true;

  // =====================================================
  // 🔹 COLUMN VISIBILITY (SYNC WITH QUOTATION PAGE)
  // =====================================================
  final bool showModelNo = prefs.getBool('showModelNo') ?? false;
  final bool showQty = prefs.getBool('showQty') ?? false;
  final bool showUnit = prefs.getBool('showUnit') ?? false;
  final bool showAmount = prefs.getBool('showAmount') ?? true; // 🔹 NEW

  // 🔹 Load selected Print Body Template
  final bodyTemplate = await loadSelectedPrintBodyTemplate();

  final String subjectText = bodyTemplate?['subject'] ?? ''; // 🔹 NEW
  final String bodyText = bodyTemplate?['body'] ?? '';
  final String signatureText = bodyTemplate?['signature'] ?? '';
  final String signatureText2 = bodyTemplate?['signatureText2'] ?? '';
  final bool alignRight = bodyTemplate?['alignRight'] ?? true;

  final double signTextX = bodyTemplate?['signTextX'] ?? 0;
  final double signTextY = bodyTemplate?['signTextY'] ?? 0;

  final double signImageX = bodyTemplate?['signImageX'] ?? 0;
  final double signImageY = bodyTemplate?['signImageY'] ?? 0;

  final double signText2X = bodyTemplate?['signText2X'] ?? 0;
  final double signText2Y = bodyTemplate?['signText2Y'] ?? 0;

  //final String signatureText2 = bodyTemplate?['signatureText2'] ?? '';
  final String? signatureImageBase64 = bodyTemplate?['signatureImage'];

  final double signImageScale = bodyTemplate?['signImageScale'] ?? 1.0;

  // 🔹 Decode signature image (base64 → Uint8List)
  Uint8List? signatureImageBytes;
  if (bodyTemplate?['signatureImage'] != null &&
      bodyTemplate!['signatureImage'].toString().isNotEmpty) {
    try {
      if (_cachedSignatureBytes != null &&
          _cachedSignatureBase64 == signatureImageBase64) {
        signatureImageBytes = _cachedSignatureBytes;
      } else {
        try {
          signatureImageBytes = base64Decode(signatureImageBase64!);

          // 🔹 cache
          _cachedSignatureBytes = signatureImageBytes;
          _cachedSignatureBase64 = signatureImageBase64;
        } catch (_) {
          signatureImageBytes = null;
        }
      }
    } catch (_) {
      signatureImageBytes = null;
    }
  }

  // Company / header data
  final String? logoPath = prefs.getString('logoPath');
  final String companyName = prefs.getString('company_name') ?? '';
  final String companyAddr = prefs.getString('company_address') ?? '';
  final String companyPhone = prefs.getString('company_phone') ?? '';
  final String companyContact = prefs.getString('company_contact') ?? '';
  final String companyEmail = prefs.getString('company_email') ?? '';
  final String companyWebsite = prefs.getString('company_website') ?? '';
  final String companyGstin = prefs.getString('company_gstin') ?? '';
  final String companyAnthem = prefs.getString('company_anthem') ?? '';
  final String notes = prefs.getString('notes') ?? '';

  final bool logoOnLeft = prefs.getBool('header_logo_on_left') ?? true;

  // ================= COMPANY ANTHEM & FONT =================

  final bool fontBold = prefs.getBool('company_font_bold') ?? false;

  final bool fontItalic = prefs.getBool('company_font_italic') ?? false;

  final bool underlineCompany =
      prefs.getBool('company_font_underline') ?? false;

  // Watermark settingsfinal pw.Widget companyInfoWidget = pw.Column(
  final String watermarkText = prefs.getString('page_setup_watermark') ?? '';
  final double watermarkOpacity = prefs.getDouble('watermarkOpacity') ?? 0.1;
  final double watermarkAngleDeg =
      prefs.getDouble('watermark_angle_deg') ?? -35.0;
  final double watermarkAngleRad = watermarkAngleDeg * 3.1415926535 / 180.0;

  // 🔹 NEW: watermark size (from Page Setup slider)
  final double watermarkSize = prefs.getDouble('watermark_size') ?? 1.0;

  // Header logo size + offsets
  final double logoHeaderHeight = prefs.getDouble('logo_header_height') ?? 80.0;
  final double companyOffsetX = prefs.getDouble('company_offset_x') ?? 0.0;
  final double companyOffsetY = prefs.getDouble('company_offset_y') ?? 0.0;
  final double logoOffsetX = prefs.getDouble('logo_offset_x') ?? 0.0;
  final double logoOffsetY = prefs.getDouble('logo_offset_y') ?? 0.0;

  // Commercial Terms
  final String ctPrices = prefs.getString('ct_prices') ?? '';
  final String ctLegal = prefs.getString('ct_legal') ?? '';
  final String ctGst = prefs.getString('ct_gst') ?? '';
  final String ctFreight = prefs.getString('ct_freight') ?? '';
  final String ctValidity = prefs.getString('ct_validity') ?? '';
  final String ctInsurance = prefs.getString('ct_insurance') ?? '';
  final String ctDeliveryPeriod = prefs.getString('ct_delivery_period') ?? '';
  final String ctWarranty = prefs.getString('ct_warranty') ?? '';
  final String ctPaymentTerms = prefs.getString('ct_payment_terms') ?? '';
  final String ctServices = prefs.getString('ct_services') ?? '';

  // Bank details
  final String bankCompanyName = prefs.getString('bank_company_name') ?? '';
  final String bankName = prefs.getString('bank_name') ?? '';
  final String bankAccount = prefs.getString('bank_account') ?? '';
  final String bankBranch = prefs.getString('bank_branch') ?? '';
  final String bankNeftRtgs = prefs.getString('bank_neft_rtgs') ?? '';

  // Selected Template (1–6)
  final int pageTemplate = prefs.getInt('page_template') ?? 1;

  // 2️⃣ Load logo bytes from file (if exists)
  Uint8List? logoBytes;

  if (_cachedLogoBytes != null && _cachedLogoPath == logoPath) {
    // ✅ use cache
    logoBytes = _cachedLogoBytes;
  } else {
    try {
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          logoBytes = await logoFile.readAsBytes();

          // 🔹 cache it
          _cachedLogoBytes = logoBytes;
          _cachedLogoPath = logoPath;
        }
      }
    } catch (_) {
      logoBytes = null;
    }
  }

  // ----------------------------------------------------
  // 🔹 Helper: logo widgets (normal + large)
  // ----------------------------------------------------
  final pw.Widget logoSizedWidget = (logoBytes != null)
      ? pw.SizedBox(
          height: logoHeaderHeight,
          width: logoHeaderHeight * 1.5,
          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
        )
      : pw.SizedBox(height: logoHeaderHeight, width: logoHeaderHeight * 1.5);

  final pw.Widget logoLargeWidget = (logoBytes != null)
      ? pw.SizedBox(
          height: logoHeaderHeight * 1.2,
          width: logoHeaderHeight * 1.2 * 1.5,
          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
        )
      : pw.SizedBox(
          height: logoHeaderHeight * 1.2,
          width: logoHeaderHeight * 1.2 * 1.5,
        );

  // ----------------------------------------------------
  // 🔹 Helper: company info block (text)
  // ----------------------------------------------------
  final pw.Widget companyInfoWidget = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // ---------------- COMPANY NAME ----------------
      if (companyName.isNotEmpty)
        pw.Text(
          companyName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: fontBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: fontItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: underlineCompany
                ? pw.TextDecoration.underline
                : pw.TextDecoration.none,
          ),
        ),

      if (companyAddr.isNotEmpty)
        pw.Text(companyAddr, style: const pw.TextStyle(fontSize: 10)),

      if (companyPhone.isNotEmpty)
        pw.Text(
          'Phone: $companyPhone',
          style: const pw.TextStyle(fontSize: 10),
        ),

      if (companyContact.isNotEmpty)
        pw.Text(
          'Contact: $companyContact',
          style: const pw.TextStyle(fontSize: 10),
        ),

      if (companyEmail.isNotEmpty)
        pw.Text(
          'Email: $companyEmail',
          style: const pw.TextStyle(fontSize: 10),
        ),

      if (companyWebsite.isNotEmpty)
        pw.Text(
          'Website: $companyWebsite',
          style: const pw.TextStyle(fontSize: 10),
        ),

      if (companyGstin.isNotEmpty)
        pw.Text(
          'GSTIN: $companyGstin',
          style: const pw.TextStyle(fontSize: 10),
        ),

      // =====================================================
      // 🔹 COMPANY ANTHEM — ALWAYS LAST LINE
      // =====================================================
      if (companyAnthem.isNotEmpty) ...[
        //pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey400),
        //pw.SizedBox(height: 2),
        pw.Text(
          companyAnthem,
          style: pw.TextStyle(
            fontSize: 11,
            fontStyle: fontItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            fontWeight: fontBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.grey800,
          ),
        ),
      ],
    ],
  );

  // ----------------------------------------------------
  // 🔹 Helper: header template layout
  // ----------------------------------------------------
  pw.Widget buildHeader() {
    switch (pageTemplate) {
      case 2: // EXECUTIVE (Logo RIGHT, info LEFT)
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Transform.translate(
                offset: PdfPoint(companyOffsetX, companyOffsetY),
                child: companyInfoWidget,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Transform.translate(
              offset: PdfPoint(logoOffsetX, logoOffsetY),
              child: logoSizedWidget,
            ),
          ],
        );

      case 3: // CORPORATE (Logo CENTER, info CENTER)
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Transform.translate(
              offset: PdfPoint(logoOffsetX, logoOffsetY),
              child: logoSizedWidget,
            ),
            pw.SizedBox(height: 4),
            pw.Transform.translate(
              offset: PdfPoint(companyOffsetX, companyOffsetY),
              child: pw.Center(child: companyInfoWidget),
            ),
          ],
        );

      case 4: // PREMIUM (Logo TOP, info below)
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Transform.translate(
              offset: PdfPoint(logoOffsetX, logoOffsetY),
              child: logoSizedWidget,
            ),
            pw.SizedBox(height: 4),
            pw.Transform.translate(
              offset: PdfPoint(companyOffsetX, companyOffsetY),
              child: companyInfoWidget,
            ),
          ],
        );

      case 5: // MINIMAL (Centered logo + big company name)
        return pw.Column(
          children: [
            pw.Transform.translate(
              offset: PdfPoint(logoOffsetX, logoOffsetY),
              child: pw.Center(child: logoSizedWidget),
            ),
            pw.SizedBox(height: 4),
            if (companyName.isNotEmpty)
              pw.Transform.translate(
                offset: PdfPoint(companyOffsetX, companyOffsetY),
                child: pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        );

      case 6: // MODERN (Big left logo + info under)
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Transform.translate(
              offset: PdfPoint(logoOffsetX, logoOffsetY),
              child: logoLargeWidget,
            ),
            pw.SizedBox(height: 4),
            pw.Transform.translate(
              offset: PdfPoint(companyOffsetX, companyOffsetY),
              child: companyInfoWidget,
            ),
          ],
        );

      case 1: // CLASSIC – obey logoOnLeft
      default:
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: logoOnLeft
              ? [
                  // logo left
                  pw.Transform.translate(
                    offset: PdfPoint(logoOffsetX, logoOffsetY),
                    child: logoSizedWidget,
                  ),
                  pw.SizedBox(width: 12),
                  // company right
                  pw.Expanded(
                    child: pw.Transform.translate(
                      offset: PdfPoint(companyOffsetX, companyOffsetY),
                      child: companyInfoWidget,
                    ),
                  ),
                ]
              : [
                  // company left
                  pw.Expanded(
                    child: pw.Transform.translate(
                      offset: PdfPoint(companyOffsetX, companyOffsetY),
                      child: companyInfoWidget,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // logo right
                  pw.Transform.translate(
                    offset: PdfPoint(logoOffsetX, logoOffsetY),
                    child: logoSizedWidget,
                  ),
                ],
        );
    }
  }

  // ----------------------------------------------------
  // 🔹 Helper: watermark background for each page
  // ----------------------------------------------------
  pw.Widget buildWatermarkBackground(pw.Context context) {
    if (logoBytes != null) {
      // Logo as rotated watermark
      return pw.Center(
        child: pw.Opacity(
          opacity: watermarkOpacity.clamp(0.0, 1.0),
          child: pw.Transform.rotate(
            angle: watermarkAngleRad,
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: 300 * watermarkSize, // 🔹 size now controlled by slider
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
    } else if (watermarkText.isNotEmpty) {
      // Text watermark (fallback)
      return pw.Center(
        child: pw.Transform.rotate(
          angle: watermarkAngleRad,
          child: pw.Opacity(
            opacity: 0.07,
            child: pw.Text(
              watermarkText,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 80 * watermarkSize, // 🔹 scaled by slider
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ),
      );
    }

    return pw.SizedBox();
  }

  // ----------------------------------------------------
  // 🔹 Helper: termRow(label, value) for T&C and bank
  // ----------------------------------------------------
  pw.Widget termRow(String label, String value) {
    const double labelWidth = 100; // adjust if needed

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3, bottom: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: labelWidth,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // 3️⃣ Build PDF document (multi-page)
  final pdf = pw.Document();
  final String dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
  // ✅ Build formatted quotation number INSIDE function
  // =====================================================
  // 🔹 BUILD QTN NUMBER (MT/2025/001)
  // =====================================================
  final fy = getFinancialYear(DateTime.now());

  // 🔹 Company short code (MT)
  final String companyShortCode = buildCompanyShortCode(companyName);

  // 🔹 Final quotation number format
  final String formattedQuotationNo =
      '$companyShortCode/$fy/${quotationNumber.toString().padLeft(3, '0')}';

  // =====================================================
  // 🔹 SIGNATURE BLOCK (REUSABLE)
  // =====================================================
  pw.Widget buildSignatureBlock() {
    if (signatureText.isEmpty &&
        signatureImageBytes == null &&
        signatureText2.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Column(
      children: [
        pw.SizedBox(height: 30),

        pw.Row(
          mainAxisAlignment: alignRight
              ? pw.MainAxisAlignment.end
              : pw.MainAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: alignRight
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                // 🔹 Signature Text 1
                if (signatureText.isNotEmpty)
                  pw.Transform.translate(
                    offset: PdfPoint(signTextX, signTextY),
                    child: pw.Text(
                      signatureText,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                // 🔹 Signature Image
                if (signatureImageBytes != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Transform.translate(
                    offset: PdfPoint(signImageX, signImageY),
                    child: pw.Transform.scale(
                      scale: signImageScale,
                      child: pw.Image(
                        pw.MemoryImage(signatureImageBytes),
                        height: 60,
                      ),
                    ),
                  ),
                ],

                // 🔹 Signature Text 2
                if (signatureText2.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Transform.translate(
                    offset: PdfPoint(signText2X, signText2Y),
                    child: pw.Text(
                      signatureText2,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  pdf.addPage(
    pw.MultiPage(
      // Common page theme: margins + watermark background
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        buildBackground: buildWatermarkBackground,
      ),

      // Header shown at top of *every* page
      header: (pw.Context context) {
        final bool isFirstPage = context.pageNumber == 1;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // =============================
            // 🔹 COMPANY HEADER (ALL PAGES)
            // =============================
            buildHeader(),
            pw.SizedBox(height: 6),

            // 🔹 HEADER BREAK LINE — ALWAYS
            pw.Divider(color: PdfColors.grey700, thickness: 0.8),

            pw.SizedBox(height: 6),

            // =============================
            // 🔹 QUOTATION TITLE — FIRST PAGE ONLY
            // =============================
            if (isFirstPage) ...[
              pw.Center(
                child: pw.Text(
                  'QUOTATION',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
            ],

            // =============================
            // 🔹 DATE + QTN + CUSTOMER — FIRST PAGE ONLY
            // =============================
            if (isFirstPage) ...[
              // Date + QTN No row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.SizedBox(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: $dateStr'),
                      pw.SizedBox(height: 4),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'QTN NO: ',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            pw.TextSpan(
                              text: formattedQuotationNo,
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 4),

              // 🔹 TO / CUSTOMER / AREA
              if (customerName.isNotEmpty || area.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('To,', style: const pw.TextStyle(fontSize: 12)),
                    if (customerName.isNotEmpty)
                      pw.Text(
                        customerName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (area.isNotEmpty)
                      pw.Text(area, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 12),
                  ],
                ),
            ],
          ],
        );
      },

      // Main page content (auto flows across pages)
      build: (pw.Context context) {
        // =====================================================
        // 🔹 AUTO COLUMN WIDTHS (RESPONSIVE)
        // =====================================================
        final Map<int, pw.TableColumnWidth> columnWidths = {};

        int colIndex = 0;

        // S.No → very small
        columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8);

        // Model No → medium (if visible)
        if (showModelNo) {
          columnWidths[colIndex++] = const pw.FlexColumnWidth(1.6);
        }

        // Description → BIG (always)
        columnWidths[colIndex++] = const pw.FlexColumnWidth(4.5);

        // Qty → small
        if (showQty) {
          columnWidths[colIndex++] = const pw.FlexColumnWidth(1.0);
        }

        // Unit → medium
        if (showUnit) {
          columnWidths[colIndex++] = const pw.FlexColumnWidth(1.4);
        }

        // Total → medium (only if enabled)
        if (showAmount) {
          columnWidths[colIndex++] = const pw.FlexColumnWidth(1.6);
        }

        return [
          // =====================================================
          // 🔹 SUBJECT + BODY TEXT (from Print Page Body)
          // =====================================================

          // 🔹 SUBJECT
          if (subjectText.isNotEmpty) ...[
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'SUB: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.TextSpan(
                    text: subjectText,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
          ],

          // 🔹 BODY
          if (bodyText.isNotEmpty) ...[
            pw.Text(bodyText, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 10),
          ],

          ...List<pw.Widget>.generate(normalizedTables.length, (tableIndex) {
            final tableRows = normalizedTables[tableIndex];
            final tableSum = tableRows.fold<double>(
              0.0,
              (sum, row) => sum + ((row['total'] ?? 0.0) as num).toDouble(),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.TableHelper.fromTextArray(
                  headers: [
                    'S.No',
                    if (showModelNo) 'Model No',
                    pw.Center(
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (showQty) 'Qty',
                    if (showUnit) 'Unit',
                    if (showAmount) 'Total',
                  ],
                  data: tableRows.map((r) {
                    final serial = (r['serial'] ?? '').toString();
                    final modelNo = (r['modelNo'] ?? '').toString();
                    final desc = (r['modelDesc'] ?? '').toString();
                    final notesRow = (r['notes'] ?? '').toString();
                    final qty = (r['qty'] ?? '').toString();
                    final unit = (r['unit'] ?? '').toString();
                    final total = ((r['total'] ?? 0.0) as num).toDouble();

                    final List<dynamic> rowCells = [];
                    rowCells.add(serial);

                    if (showModelNo) {
                      rowCells.add(modelNo);
                    }

                    rowCells.add(
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: desc,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            if (notesRow.isNotEmpty)
                              pw.TextSpan(
                                text: '\n$notesRow',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );

                    if (showQty) {
                      rowCells.add(qty);
                    }

                    if (showUnit) {
                      rowCells.add(unit);
                    }

                    if (showAmount) {
                      rowCells.add(total.toStringAsFixed(2));
                    }

                    return rowCells;
                  }).toList(),
                  columnWidths: columnWidths,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    if (showModelNo) 1: pw.Alignment.center,
                    showModelNo ? 2 : 1: pw.Alignment.centerLeft,
                    if (showQty) (showModelNo ? 3 : 2): pw.Alignment.center,
                    if (showUnit)
                      (showModelNo ? (showQty ? 4 : 3) : (showQty ? 3 : 2)):
                          pw.Alignment.center,
                    if (showAmount)
                      (showModelNo
                              ? (showQty && showUnit
                                    ? 5
                                    : showQty || showUnit
                                    ? 4
                                    : 3)
                              : (showQty && showUnit
                                    ? 4
                                    : showQty || showUnit
                                    ? 3
                                    : 2)):
                          pw.Alignment.center,
                  },
                  border: pw.TableBorder.all(
                    color: PdfColors.black,
                    width: 0.6,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                ),
                if (normalizedTableVisibility[tableIndex]) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Table Total: ${tableSum.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                if (tableIndex != normalizedTables.length - 1)
                  pw.SizedBox(height: 10),
              ],
            );
          }),

          pw.SizedBox(height: 8),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // =====================================================
          // 🔹 TOTAL AMOUNT IN WORDS (BOLD)
          // =====================================================
          pw.Text(
            'In Words: ${numberToWords(totalAmount)}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold, // 🔥 BOLD
            ),
          ),
          pw.SizedBox(height: 8),

          // 🔹 Notes
          if (notes.isNotEmpty) ...[
            pw.Text(
              'Notes',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 8),
          ],

          // 🔹 Commercial Terms & Conditions
          if (ctPrices.isNotEmpty ||
              ctLegal.isNotEmpty ||
              ctGst.isNotEmpty ||
              ctFreight.isNotEmpty ||
              ctValidity.isNotEmpty ||
              ctInsurance.isNotEmpty ||
              ctDeliveryPeriod.isNotEmpty ||
              ctWarranty.isNotEmpty ||
              ctPaymentTerms.isNotEmpty ||
              ctServices.isNotEmpty) ...[
            pw.Text(
              'Commercial Terms And Conditions',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                fontSize: 11,
              ),
            ),
            pw.SizedBox(height: 4),
            if (ctPrices.isNotEmpty) termRow('Prices', ctPrices),
            if (ctLegal.isNotEmpty) termRow('Legal', ctLegal),
            if (ctGst.isNotEmpty) termRow('GST', ctGst),
            if (ctFreight.isNotEmpty) termRow('Frights', ctFreight),
            if (ctValidity.isNotEmpty) termRow('Validity', ctValidity),
            if (ctInsurance.isNotEmpty) termRow('Insurance', ctInsurance),
            if (ctDeliveryPeriod.isNotEmpty)
              termRow('Delivery Period', ctDeliveryPeriod),
            if (ctWarranty.isNotEmpty) termRow('Warranty', ctWarranty),
            if (ctPaymentTerms.isNotEmpty)
              termRow('Payment Terms', ctPaymentTerms),
            if (ctServices.isNotEmpty) termRow('Services', ctServices),
            pw.SizedBox(height: 8),
          ],

          // =====================================================
          // 🔹 SIGNATURE IMMEDIATELY AFTER COMMERCIAL TERMS
          // 🔹 WHEN BANK DETAILS ARE HIDDEN
          // =====================================================
          if (!showBankDetails) buildSignatureBlock(),

          // 🔹 Bank Details (ONLY IF ENABLED)
          if (showBankDetails &&
              (bankCompanyName.isNotEmpty ||
                  bankName.isNotEmpty ||
                  bankAccount.isNotEmpty ||
                  bankBranch.isNotEmpty ||
                  bankNeftRtgs.isNotEmpty)) ...[
            pw.Text(
              'Bank Details',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 4),
            if (bankCompanyName.isNotEmpty)
              termRow('Company Name', bankCompanyName),
            if (bankName.isNotEmpty) termRow('Bank Name', bankName),
            if (bankAccount.isNotEmpty) termRow('Account Number', bankAccount),
            if (bankBranch.isNotEmpty) termRow('Branch', bankBranch),
            if (bankNeftRtgs.isNotEmpty)
              termRow('NEFT/RTGS Code', bankNeftRtgs),
            // =====================================================
            // 🔹 SIGNATURE AFTER BANK DETAILS
            // 🔹 ONLY WHEN BANK DETAILS ARE SHOWN
            // =====================================================
            if (showBankDetails) buildSignatureBlock(),
          ],
        ];
      },
    ),
  );

  final bytes = await pdf.save();

  return bytes;
}

// =====================================================
// 🔹 SHARED HEADER — USED BY ALL PDFs
// =====================================================
Future<pw.Widget Function()> buildQuotationHeaderOnly() async {
  final prefs = await CloudPreferences.getInstance();

  final String? logoPath = prefs.getString('logoPath');
  final String companyName = prefs.getString('company_name') ?? '';
  final String companyAddr = prefs.getString('company_address') ?? '';
  final String companyPhone = prefs.getString('company_phone') ?? '';
  final bool logoOnLeft = prefs.getBool('header_logo_on_left') ?? true;

  Uint8List? logoBytes;
  if (logoPath != null && logoPath.isNotEmpty) {
    final file = File(logoPath);
    if (await file.exists()) {
      logoBytes = await file.readAsBytes();
    }
  }

  return () {
    final logoWidget = logoBytes != null
        ? pw.Image(pw.MemoryImage(logoBytes), height: 60)
        : pw.SizedBox(width: 60);

    final companyInfo = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (companyName.isNotEmpty)
          pw.Text(
            companyName,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        if (companyAddr.isNotEmpty)
          pw.Text(companyAddr, style: const pw.TextStyle(fontSize: 10)),
        if (companyPhone.isNotEmpty)
          pw.Text(
            'Phone: $companyPhone',
            style: const pw.TextStyle(fontSize: 10),
          ),
      ],
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: logoOnLeft
          ? [
              logoWidget,
              pw.SizedBox(width: 12),
              pw.Expanded(child: companyInfo),
            ]
          : [
              pw.Expanded(child: companyInfo),
              pw.SizedBox(width: 12),
              logoWidget,
            ],
    );
  };
}

// =====================================================
// 🔹 COMMON HEADER WRAPPER
// =====================================================
pw.Widget buildCommonPdfHeader({
  required pw.Context context,
  required pw.Widget headerWidget,
  required String title,
  required bool showTitle,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      headerWidget,
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.grey700, thickness: 0.8),
      pw.SizedBox(height: 6),
      if (showTitle && context.pageNumber == 1)
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      if (showTitle && context.pageNumber == 1) pw.SizedBox(height: 10),
    ],
  );
}
