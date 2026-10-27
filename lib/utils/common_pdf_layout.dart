import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

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

// 2️⃣ Load logo bytes from file (if exists)
// =====================================================
// 🔹 LOGO LOADER (SAFE + ASYNC)
// =====================================================
Uint8List? _cachedLogoBytes;
String? _cachedLogoPath;

/// Loads logo bytes safely with cache
Future<Uint8List?> loadCompanyLogo(String? logoPath) async {
  if (logoPath == null || logoPath.isEmpty) return null;

  // ✅ use cache
  if (_cachedLogoBytes != null && _cachedLogoPath == logoPath) {
    return _cachedLogoBytes;
  }

  try {
    if (logoPath.startsWith('data:image/')) {
      return UriData.parse(logoPath).contentAsBytes();
    }
    final file = File(logoPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();

      _cachedLogoBytes = bytes;
      _cachedLogoPath = logoPath;

      return bytes;
    }
  } catch (_) {}

  return null;
}

// ----------------------------------------------------
// 🔹 Helper: company info block (text)
// ----------------------------------------------------
// =====================================================
// 🔹 COMPANY INFO + ANTHEM
// =====================================================
pw.Widget buildCompanyInfoWidget({
  required String companyName,
  required String companyAddr,
  required String companyPhone,
  required String companyContact,
  required String companyEmail,
  required String companyWebsite,
  required String companyGstin,
  required String companyAnthem,
  required bool fontBold,
  required bool fontItalic,
  required bool underlineCompany,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // 🔹 COMPANY NAME
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
      // 🔹 COMPANY ANTHEM (COMMON FOR ALL PDFs)
      // =====================================================
      if (companyAnthem.isNotEmpty) ...[
        pw.Divider(color: PdfColors.grey400),
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
}

// ----------------------------------------------------
// 🔹 Helper: header template layout
// ----------------------------------------------------
// =====================================================
// 🔹 COMMON HEADER BUILDER
// =====================================================
pw.Widget buildCommonHeader({
  required int pageTemplate,
  required bool logoOnLeft,
  required pw.Widget logoSizedWidget,
  required pw.Widget logoLargeWidget,
  required pw.Widget companyInfoWidget,
  required double logoOffsetX,
  required double logoOffsetY,
  required double companyOffsetX,
  required double companyOffsetY,
}) {
  switch (pageTemplate) {
    case 2: // EXECUTIVE
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

    case 3: // CORPORATE
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

    case 4: // PREMIUM
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

    case 5: // MINIMAL
      return pw.Column(
        children: [
          pw.Transform.translate(
            offset: PdfPoint(logoOffsetX, logoOffsetY),
            child: pw.Center(child: logoSizedWidget),
          ),
        ],
      );

    case 6: // MODERN
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

    case 1: // CLASSIC
    default:
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: logoOnLeft
            ? [
                pw.Transform.translate(
                  offset: PdfPoint(logoOffsetX, logoOffsetY),
                  child: logoSizedWidget,
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Transform.translate(
                    offset: PdfPoint(companyOffsetX, companyOffsetY),
                    child: companyInfoWidget,
                  ),
                ),
              ]
            : [
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
  }
}

// =====================================================
// 🔹 COMMON WATERMARK BACKGROUND
// Covers:
// 5. Watermark opacity
// 6. Watermark size
// 7. Watermark anglex
// =====================================================
pw.Widget buildCommonWatermarkBackground({
  required Uint8List? logoBytes,
  required double watermarkOpacity,
  required double watermarkAngleRad,
  required double watermarkSize,
  required String watermarkText,
}) {
  if (logoBytes != null) {
    return pw.Center(
      child: pw.Opacity(
        opacity: watermarkOpacity.clamp(0.0, 1.0),
        child: pw.Transform.rotate(
          angle: watermarkAngleRad,
          child: pw.Image(
            pw.MemoryImage(logoBytes),
            width: watermarkSize, // ✅ FIXED
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
  }

  if (watermarkText.isNotEmpty) {
    return pw.Center(
      child: pw.Transform.rotate(
        angle: watermarkAngleRad,
        child: pw.Opacity(
          opacity: 0.07,
          child: pw.Text(
            watermarkText,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: watermarkSize, // ✅ FIXED
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
