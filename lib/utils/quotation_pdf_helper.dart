// lib/utils/quotation_pdf_helper.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

/// Common function to build quotation PDF bytes.
/// Used in:
/// 1) Quotation page -> Export PDF
/// 2) QuotationPreviewPage (from quotation page)
/// 3) QuotationPreviewPage (from saved quotation page)
Future<Uint8List> buildQuotationPdfBytes({
  required int quotationNumber,
  required String customerName,
  required List<Map<String, dynamic>> products,
  required double totalAmount,
}) async {
  // 1️⃣ Read Page Setup values from SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Company / header data
  final String? logoPath = prefs.getString('logoPath');
  final String companyName = prefs.getString('company_name') ?? '';
  final String companyAddr = prefs.getString('company_address') ?? '';
  final String companyPhone = prefs.getString('company_phone') ?? '';
  final String companyContact = prefs.getString('company_contact') ?? '';
  final String companyEmail = prefs.getString('company_email') ?? '';
  final String companyWebsite = prefs.getString('company_website') ?? '';
  final String companyGstin = prefs.getString('company_gstin') ?? '';
  final String notes = prefs.getString('notes') ?? '';

  final bool logoOnLeft = prefs.getBool('header_logo_on_left') ?? true;

  // Watermark settings
  final String watermarkText =
      prefs.getString('page_setup_watermark') ?? '';
  final double watermarkOpacity =
      prefs.getDouble('watermarkOpacity') ?? 0.1;
  final double watermarkAngleDeg =
      prefs.getDouble('watermark_angle_deg') ?? -35.0;
  final double watermarkAngleRad =
      watermarkAngleDeg * 3.1415926535 / 180.0;

  // Header logo size + offsets
  final double logoHeaderHeight =
      prefs.getDouble('logo_header_height') ?? 80.0;
  final double companyOffsetX =
      prefs.getDouble('company_offset_x') ?? 0.0;
  final double companyOffsetY =
      prefs.getDouble('company_offset_y') ?? 0.0;
  final double logoOffsetX =
      prefs.getDouble('logo_offset_x') ?? 0.0;
  final double logoOffsetY =
      prefs.getDouble('logo_offset_y') ?? 0.0;

  // Commercial Terms
  final String ctPrices = prefs.getString('ct_prices') ?? '';
  final String ctLegal = prefs.getString('ct_legal') ?? '';
  final String ctGst = prefs.getString('ct_gst') ?? '';
  final String ctFreight = prefs.getString('ct_freight') ?? '';
  final String ctValidity = prefs.getString('ct_validity') ?? '';
  final String ctInsurance = prefs.getString('ct_insurance') ?? '';
  final String ctDeliveryPeriod =
      prefs.getString('ct_delivery_period') ?? '';
  final String ctWarranty = prefs.getString('ct_warranty') ?? '';
  final String ctPaymentTerms =
      prefs.getString('ct_payment_terms') ?? '';
  final String ctServices = prefs.getString('ct_services') ?? '';

  // Bank details
  final String bankCompanyName =
      prefs.getString('bank_company_name') ?? '';
  final String bankName = prefs.getString('bank_name') ?? '';
  final String bankAccount = prefs.getString('bank_account') ?? '';
  final String bankBranch = prefs.getString('bank_branch') ?? '';
  final String bankNeftRtgs =
      prefs.getString('bank_neft_rtgs') ?? '';

  // Selected Template (1–6)
  final int pageTemplate = prefs.getInt('page_template') ?? 1;

  // 2️⃣ Load logo bytes from file (if exists)
  Uint8List? logoBytes;
  try {
    if (logoPath != null && logoPath.isNotEmpty) {
      final logoFile = File(logoPath);
      if (await logoFile.exists()) {
        logoBytes = await logoFile.readAsBytes();
      }
    }
  } catch (_) {
    logoBytes = null;
  }

  // ----------------------------------------------------
  // 🔹 Helper: logo widgets (normal + large)
  // ----------------------------------------------------
  final pw.Widget logoSizedWidget = (logoBytes != null)
      ? pw.SizedBox(
          height: logoHeaderHeight,
          width: logoHeaderHeight * 1.5,
          child: pw.Image(
            pw.MemoryImage(logoBytes),
            fit: pw.BoxFit.contain,
          ),
        )
      : pw.SizedBox(
          height: logoHeaderHeight,
          width: logoHeaderHeight * 1.5,
        );

  final pw.Widget logoLargeWidget = (logoBytes != null)
      ? pw.SizedBox(
          height: logoHeaderHeight * 1.2,
          width: logoHeaderHeight * 1.2 * 1.5,
          child: pw.Image(
            pw.MemoryImage(logoBytes),
            fit: pw.BoxFit.contain,
          ),
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
      if (companyName.isNotEmpty)
        pw.Text(
          companyName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      if (companyAddr.isNotEmpty)
        pw.Text(companyAddr, style: const pw.TextStyle(fontSize: 10)),
      if (companyPhone.isNotEmpty)
        pw.Text('Phone: $companyPhone',
            style: const pw.TextStyle(fontSize: 10)),
      if (companyContact.isNotEmpty)
        pw.Text('Contact: $companyContact',
            style: const pw.TextStyle(fontSize: 10)),
      if (companyEmail.isNotEmpty)
        pw.Text('Email: $companyEmail',
            style: const pw.TextStyle(fontSize: 10)),
      if (companyWebsite.isNotEmpty)
        pw.Text('Website: $companyWebsite',
            style: const pw.TextStyle(fontSize: 10)),
      if (companyGstin.isNotEmpty)
        pw.Text('GSTIN: $companyGstin',
            style: const pw.TextStyle(fontSize: 10)),
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
              width: 300,
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
                fontSize: 80,
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
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // 3️⃣ Build PDF document (multi-page)
  final pdf = pw.Document();
  final String dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

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
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader(),
            pw.SizedBox(height: 12),

            // Quotation No & Date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Quotation #$quotationNumber',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Date: $dateStr'),
              ],
            ),
            pw.SizedBox(height: 4),

            // Customer line
            if (customerName.isNotEmpty)
              pw.Text(
                'Customer: $customerName',
                style: const pw.TextStyle(fontSize: 12),
              ),

            pw.SizedBox(height: 12),
          ],
        );
      },

      // Main page content (auto flows across pages)
      build: (pw.Context context) {
        return [
          // 🔹 Products table (auto page-break)
          pw.TableHelper.fromTextArray(
            headers: const [
              'S.No',
              'Model No',
              'Description',
              'Qty',
              'Unit',
              'Total',
            ],
            data: products.map((r) {
              final serial = (r['serial'] ?? '').toString();
              final modelNo = (r['modelNo'] ?? '').toString();
              final desc = (r['modelDesc'] ?? '').toString();
              final qty = (r['qty'] ?? '').toString();
              final unit = (r['unit'] ?? '').toString();
              final total = ((r['total'] ?? 0.0) as num).toDouble();

              return [
                serial,
                modelNo,
                desc,
                qty,
                unit,
                total.toStringAsFixed(2),
              ];
            }).toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(
              width: 0.5,
              color: PdfColors.grey,
            ),
          ),

          pw.SizedBox(height: 8),

          // 🔹 Total amount
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total Amount: ₹${totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

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
            pw.Text(
              notes,
              style: const pw.TextStyle(fontSize: 9),
            ),
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
            if (ctInsurance.isNotEmpty)
              termRow('Insurance', ctInsurance),
            if (ctDeliveryPeriod.isNotEmpty)
              termRow('Delivery Period', ctDeliveryPeriod),
            if (ctWarranty.isNotEmpty)
              termRow('Warranty', ctWarranty),
            if (ctPaymentTerms.isNotEmpty)
              termRow('Payment Terms', ctPaymentTerms),
            if (ctServices.isNotEmpty)
              termRow('Services', ctServices),
            pw.SizedBox(height: 8),
          ],

          // 🔹 Bank Details
          if (bankCompanyName.isNotEmpty ||
              bankName.isNotEmpty ||
              bankAccount.isNotEmpty ||
              bankBranch.isNotEmpty ||
              bankNeftRtgs.isNotEmpty) ...[
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
            if (bankName.isNotEmpty)
              termRow('Bank Name', bankName),
            if (bankAccount.isNotEmpty)
              termRow('Account Number', bankAccount),
            if (bankBranch.isNotEmpty)
              termRow('Branch', bankBranch),
            if (bankNeftRtgs.isNotEmpty)
              termRow('NEFT/RTGS Code', bankNeftRtgs),
          ],
        ];
      },
    ),
  );

  // 4️⃣ Return PDF bytes
  return pdf.save();
}
