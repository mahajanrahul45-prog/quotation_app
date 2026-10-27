import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/maintenance_quotation.dart';
import 'package:intl/intl.dart';
import '../storage/cloud_preferences.dart';

import 'dart:convert';
import 'common_pdf_layout.dart';



// =====================================================
// 🔹 HELPER — Convert number to words (simple version)
// =====================================================
String numberToWords(int number) {
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five',
    'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
    'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
  ];

  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty',
    'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  if (number < 20) return ones[number];
  if (number < 100) {
    return tens[number ~/ 10] +
        (number % 10 != 0 ? ' ${ones[number % 10]}' : '');
  }
  if (number < 1000) {
    return '${ones[number ~/ 100]} Hundred'
        '${number % 100 != 0 ? ' ${numberToWords(number % 100)}' : ''}';
  }

  if (number < 100000) {
    return '${numberToWords(number ~/ 1000)} Thousand'
        '${number % 1000 != 0 ? ' ${numberToWords(number % 1000)}' : ''}';
  }

  return number.toString();
}


Future<Uint8List> buildMaintenancePdfBytes(
  MaintenanceQuotation q,
) async {



  // =====================================================
// 🔹 LOAD MAINTENANCE PAGE SETUP SETTINGS
// =====================================================
final prefs = await CloudPreferences.getInstance();

// SAME KEYS AS QUOTATION
final logoPath = prefs.getString('logoPath');
final headerLogoSize = prefs.getDouble('headerLogoSize') ?? 60;
final headerLogoPosition = prefs.getString('headerLogoPosition') ?? 'left';


final watermarkOpacity =
    prefs.getDouble('watermarkOpacity') ?? 0.1;
final watermarkSize =
    prefs.getDouble('watermarkSize') ?? 300;
final watermarkAngle =
    prefs.getDouble('watermarkAngle') ?? -30;

final String watermarkText =
    prefs.getString('page_setup_watermark') ?? '';

final double watermarkAngleRad =
    watermarkAngle * 3.1415926535 / 180.0;


final printTemplate =
    prefs.getString('printTemplate') ?? 'default';

//Use Page Body in PDF
//final bodyText = prefs.getString('m_pageBody') ?? '';
//// =====================================================
// 🔹 LOAD MAINTENANCE PAGE BODY TEXTS (STEP 2)
// =====================================================
final String text1Body =
    prefs.getString('m_body_text1') ?? '';

final String text2Body =
    prefs.getString('m_body_text2') ?? '';

// =====================================================
// 🔹 STEP 3 — LOAD TEXT 3 TO TEXT 12 (BULLET POINTS)
// =====================================================
final String text3Body = prefs.getString('m_body_text3') ?? '';
final String text4Body = prefs.getString('m_body_text4') ?? '';
final String text5Body = prefs.getString('m_body_text5') ?? '';
final String text6Body = prefs.getString('m_body_text6') ?? '';
final String text7Body = prefs.getString('m_body_text7') ?? '';
final String text8Body = prefs.getString('m_body_text8') ?? '';
final String text9Body = prefs.getString('m_body_text9') ?? '';
final String text10Body = prefs.getString('m_body_text10') ?? '';
final String text11Body = prefs.getString('m_body_text11') ?? '';
final String text12Body = prefs.getString('m_body_text12') ?? '';

// =====================================================
// 🔹 STEP 4 — LOAD TEXT 13 TO TEXT 16
// =====================================================
final String text13Body = prefs.getString('m_body_text13') ?? '';
final String text14Body = prefs.getString('m_body_text14') ?? '';
final String text15Body = prefs.getString('m_body_text15') ?? '';
final String text16Body = prefs.getString('m_body_text16') ?? '';

// =====================================================
// 🔹 STEP 3 — BULLET POINTS (TEXT 3 → TEXT 12)
// =====================================================
final bulletTexts = [
  text3Body,
  text4Body,
  text5Body,
  text6Body,
  text7Body,
  text8Body,
  text9Body,
  text10Body,
  text11Body,
  text12Body,
].where((t) => t.trim().isNotEmpty).toList();

//final showOfferDate = prefs.getBool('m_showOfferDate') ?? true;
final showCustomerName = prefs.getBool('m_showCustomerName') ?? true;
// final showPeriod = prefs.getBool('m_showPeriod') ?? true;
// final showLiftQty = prefs.getBool('m_showLiftQty') ?? true;
// final showAmounts = prefs.getBool('m_showAmounts') ?? true;

// 🔹 SHOW / HIDE TITLE
final bool showTitle =
    prefs.getBool('m_show_title') ?? false;


// =====================================================
// 🔹 STEP 5 — SIGNATURE SETTINGS FROM PAGE BODY
// =====================================================
final bool signAlignRight =
    prefs.getBool('m_sign_align_right') ?? true;

final bool accAlignRight =
    prefs.getBool('m_acc_align_right') ?? true;


final String signText1 =
    prefs.getString('m_sign_text1') ?? '';

final String signText2 =
    prefs.getString('m_sign_text2') ?? '';

final String? signImageBase64 =
    prefs.getString('m_sign_image');

// 🔹 POSITION CONTROLS
final double signText1X =
    prefs.getDouble('m_sign_text1_x') ?? 0;
final double signText1Y =
    prefs.getDouble('m_sign_text1_y') ?? 0;



// =====================================================
// 🔒 CLAMP SIGNATURE MOVEMENT (PREVENT HEADER OVERLAP)
// =====================================================



// 🔹 Accepted Customer block position
final double accBlockX =
    prefs.getDouble('m_acc_block_x') ?? 0;

final double accBlockY =
    prefs.getDouble('m_acc_block_y') ?? 0;




  final pdf = pw.Document();
  final df = DateFormat('dd/MM/yyyy');





  // =====================================================
// 🔹 CUSTOMER INFO FROM MAINTENANCE QUOTATION
// =====================================================
final String customerName = q.customerName;
final String customerArea = q.area ?? ''; // make sure area exists in model


// =====================================================
// 🔹 STEP 4 — AMOUNT IN WORDS
// =====================================================

// 🔹 LIFT AMOUNT (ONE LIFT) IN WORDS
final int liftAmountInt = q.liftAmount.isNaN
    ? 0
    : q.liftAmount.round();

final String liftAmountWords =
    numberToWords(liftAmountInt);

// 🔹 TOTAL AMOUNT (ALL LIFTS) IN WORDS
final int totalAmountInt = q.totalAmount.isNaN
    ? 0
    : q.totalAmount.round();

final String totalAmountWords =
    numberToWords(totalAmountInt);




// =====================================================
// 🔹 LOAD COMPANY DETAILS (same as quotation)
// =====================================================
final companyName = prefs.getString('company_name') ?? '';
final companyAddr = prefs.getString('company_address') ?? '';
final companyPhone = prefs.getString('company_phone') ?? '';
final companyEmail = prefs.getString('company_email') ?? '';

final bool logoOnLeft = headerLogoPosition == 'left';



// =====================================================
// 🔹 BUILD COMPANY INFO WIDGET
// =====================================================
// =====================================================
// 🔹 BUILD COMPANY INFO WIDGET (COMMON)
// =====================================================
final pw.Widget companyInfoWidget = buildCompanyInfoWidget(
  companyName: companyName,
  companyAddr: companyAddr,
  companyPhone: companyPhone,
  companyContact: '', // maintenance doesn't use contact
  companyEmail: companyEmail,
  companyWebsite: '', // optional
  companyGstin: '',   // optional
  companyAnthem: prefs.getString('company_anthem') ?? '',
  fontBold: true,
  fontItalic: false,
  underlineCompany: false,
);


// =====================================================
// 🔹 BUILD LOGO WIDGET
// =====================================================
final logoBytes = await loadCompanyLogo(logoPath);

final pw.Widget logoSizedWidget = (logoBytes != null)
    ? pw.SizedBox(
        height: headerLogoSize,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          fit: pw.BoxFit.contain,
        ),
      )
    : pw.SizedBox(height: headerLogoSize);

final pw.Widget logoLargeWidget = logoSizedWidget;

// default offsets
final double logoOffsetX = 0;
final double logoOffsetY = 0;
final double companyOffsetX = 0;
final double companyOffsetY = 0;

// page template
final int pageTemplate = 1;


// =====================================================
// 🔹 DECODE SIGNATURE IMAGE
// =====================================================
Uint8List? signatureBytes;

if (signImageBase64 != null &&
    signImageBase64.isNotEmpty) {
  try {
    signatureBytes = base64Decode(signImageBase64);
  } catch (_) {
    signatureBytes = null;
  }
}



// =====================================================
// 🔹 STEP 4 — TITLE FROM PRINT TEMPLATE
// =====================================================
String titleText = 'MAINTENANCE QUOTATION'; // default

if (printTemplate == 'modern') {
  titleText = 'MAINTENANCE CONTRACT';
} else if (printTemplate == 'simple') {
  titleText = 'SERVICE AGREEMENT';
}


// =====================================================
// 🔹 ADD PAGE WITH WATERMARK SUPPORT
// =====================================================
pdf.addPage(
  pw.MultiPage(


// =====================================================
    // 🔹 FIXED HEADER — APPEARS ON EVERY PAGE
    // =====================================================
    header: (context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          // 🔹 COMPANY HEADER (LOGO + DETAILS)
          buildCommonHeader(
            pageTemplate: pageTemplate,
            logoOnLeft: logoOnLeft,
            logoSizedWidget: logoSizedWidget,
            logoLargeWidget: logoLargeWidget,
            companyInfoWidget: companyInfoWidget,
            logoOffsetX: logoOffsetX,
            logoOffsetY: logoOffsetY,
            companyOffsetX: companyOffsetX,
            companyOffsetY: companyOffsetY,
          ),

          pw.SizedBox(height: 5),

          // 🔹 DIVIDER (FIXED)
          pw.Divider(thickness: 1),

          pw.SizedBox(height: 4),

         

          // // 🔹 OPTIONAL TITLE
          // if (showTitle) ...[
          //   pw.SizedBox(height: 6),
          //   pw.Center(
          //     child: pw.Text(
          //       titleText,
          //       style: pw.TextStyle(
          //         fontSize: 16,
          //         fontWeight: pw.FontWeight.bold,
          //         letterSpacing: 1,
          //       ),
          //     ),
          //   ),
          // ],

          pw.SizedBox(height: 6),
        ],
      );
    },





    // 🔹 PAGE THEME (Watermark comes from here)
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),


     buildBackground: (context) => buildCommonWatermarkBackground(
  logoBytes: logoBytes,
  watermarkOpacity: watermarkOpacity,
  watermarkAngleRad: watermarkAngleRad,
  watermarkSize: watermarkSize,
  watermarkText: watermarkText,
),


    ),

    // 🔹 MAIN PAGE CONTENT
    build: (context) {
      return [

        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [


  // =====================================================
// 🔹 OFFER DATE — TOP RIGHT
// =====================================================
pw.Align(
  alignment: pw.Alignment.topRight,
  child: pw.Text(
    'Date: ${df.format(q.offerDate)}',
    style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
),

pw.SizedBox(height: 10),

// =====================================================
// 🔹 TITLE (CONTROLLED BY TOGGLE)
// =====================================================
if (showTitle)
  pw.Center(
    child: pw.Text(
      titleText,
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  ),


// if (showTitle) pw.SizedBox(height: 12),

// =====================================================
// 🔹 TO / CUSTOMER / AREA BLOCK (NO LABELS, NO INTERPOLATION)
// =====================================================
if (showCustomerName || true)

pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      'To,',
      style: pw.TextStyle(
        fontSize: 11,
        //fontWeight: pw.FontWeight.bold,
      ),
    ),

    pw.SizedBox(height: 4),

    // ✅ Direct customer name
    pw.Text(
      customerName,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
    ),

    // ✅ Direct area (only if exists)
    if (customerArea.isNotEmpty)
      pw.Text(
        customerArea,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
  ],
),


pw.SizedBox(height: 12),


// =====================================================
// 🔹 PAGE BODY TEXT 1 + TEXT 2 (JOIN FORMAT)
// =====================================================
if (text1Body.isNotEmpty || text2Body.isNotEmpty) ...[
  pw.RichText(
  text: pw.TextSpan(
    style: const pw.TextStyle(fontSize: 11),
    children: [

      // 🔹 TEXT 1 BODY (NORMAL)
      pw.TextSpan(text: '$text1Body '),

      // 🔹 CUSTOMER NAME (BOLD)
      pw.TextSpan(
        text: '$customerName ',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),

      // 🔹 CUSTOMER AREA (BOLD – ONLY IF EXISTS)
      if (customerArea.isNotEmpty)
        pw.TextSpan(
          text: '$customerArea ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),

      // 🔹 "From" (NORMAL)
      pw.TextSpan(text: 'From '),

      // 🔹 START DATE (BOLD)
      pw.TextSpan(
        text: '${df.format(q.startDate)} ',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),

      // 🔹 "To" (NORMAL)
      pw.TextSpan(text: 'To '),

      // 🔹 END DATE (BOLD)
      pw.TextSpan(
        text: '${df.format(q.endDate)} ',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),

      // 🔹 TEXT 2 BODY (NORMAL)
      pw.TextSpan(text: text2Body),
    ],
  ),
),

  pw.SizedBox(height: 10),

],


// =====================================================
// 🔹 STEP 3 — BULLET POINTS (TEXT 3 → TEXT 12)
// =====================================================
if (bulletTexts.isNotEmpty)
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: bulletTexts.map((text) {
      final bool isText11 = text.trim() == text11Body.trim();

      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2), // bullet point spacing.
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 🔹 BULLET SYMBOL
            pw.Text(
              '- ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),

            // 🔹 BULLET CONTENT
            pw.Expanded(
              child: isText11
                  ? pw.RichText(
                      text: pw.TextSpan(
                        style: const pw.TextStyle(fontSize: 11),
                        children: [
                          // 🔹 TEXT 11 BODY
                          pw.TextSpan(text: '$text '),

                          // 🔹 COMPANY NAME (BOLD)
                          pw.TextSpan(
                            text: companyName,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : pw.Text(
                      text,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
            ),
          ],
        ),
      );
    }).toList(),
  ),



pw.SizedBox(height: 5),


  // =====================================================
// 🔹 STEP 4 — TEXT 13 (PARAGRAPH)
// =====================================================
if (text13Body.isNotEmpty) ...[
  pw.SizedBox(height: 10),
  pw.Text(
    text13Body,
    style: const pw.TextStyle(fontSize: 11),
  ),
],

// =====================================================
// 🔹 STEP 4 — TEXT 14 + LIFT AMOUNT + TEXT 15
// =====================================================
if (text14Body.isNotEmpty || text15Body.isNotEmpty) ...[
  pw.SizedBox(height: 10),

  pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 11),
      children: [
        pw.TextSpan(text: text14Body),
        pw.TextSpan(
          text: ' Rs.${q.liftAmount.toStringAsFixed(2)} ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: text15Body),
      ],
    ),
  ),

  pw.SizedBox(height: 3),

  // 🔹 AMOUNT IN WORDS (BOLD)
 // 🔹 LIFT AMOUNT IN WORDS (TEXT 15)
pw.Text(
  'In Words: Rupees $liftAmountWords Only',
  style: pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
  ),
),

],

// =====================================================
// 🔹 STEP 4 — TEXT 16 + LIFT QTY + TOTAL AMOUNT
// =====================================================
if (text16Body.isEmpty) ...[
  pw.SizedBox(height: 10),

  pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 11),
      children: [

        // 🔹 LIFT QTY WITH WORDS
        pw.TextSpan(
          text: 'For ${q.liftQty} (${numberToWords(q.liftQty)}) Lift ',
        ),

        // 🔹 LABEL (NORMAL)
        pw.TextSpan(
          text: 'Total Amount is ',
        ),

        // 🔹 AMOUNT ONLY (BOLD) 
        pw.TextSpan(
          text: 'Rs.${q.totalAmount.toStringAsFixed(2)}   (+GST 18%)',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),

        // 🔹 OPTIONAL TEXT 16 BODY
        pw.TextSpan(
          text: text16Body,
        ),
      ],
    ),
  ),

  pw.SizedBox(height: 6),

  // 🔹 AMOUNT IN WORDS (SHOW ONLY IF LIFT QTY > 1) // 🔹 TOTAL AMOUNT IN WORDS (TEXT 16)
if (q.liftQty > 1)
  pw.Text(
    'In Words: Rupees $totalAmountWords Only',
    style: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
    ),
  ),
  
],

// =====================================================
// 🔹 SIGNATURE BLOCK (SAME FLOW AS QUOTATION PAGE)
// 🔹 Automatically moves to next page if no space
// 🔹 NEVER overlaps header
// =====================================================
buildSignatureSection(
  signAlignRight: signAlignRight,
  accAlignRight: accAlignRight,
  signText1: signText1,
  signatureBytes: signatureBytes,
  signText2: signText2,
  verticalOffset: signText1Y,
  horizontalOffset: signText1X,
  accBlockX: accBlockX,
  accBlockY: accBlockY,
),


          ],
        ),

      ];
    },
  ),
);


  return pdf.save();
}

// =====================================================
// 🔹 COMMON SIGNATURE SECTION
// 🔹 Used in BODY FLOW (NOT footer)
// 🔹 SAME behavior as quotation page
// =====================================================
pw.Widget buildSignatureSection({
  required bool signAlignRight,
  required bool accAlignRight,
  required String signText1,
  required Uint8List? signatureBytes,
  required String signText2,
  required double verticalOffset,
  required double horizontalOffset,
  required double accBlockX,
  required double accBlockY,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 30),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [

        if (!signAlignRight)
          _safeSignature(
            signText1,
            signatureBytes,
            signText2,
            verticalOffset,
            horizontalOffset,
          ),

        if (!accAlignRight)
          _buildAcceptedCustomerBlock(accBlockX, accBlockY),

        if (accAlignRight)
          _buildAcceptedCustomerBlock(accBlockX, accBlockY),

        if (signAlignRight)
          _safeSignature(
            signText1,
            signatureBytes,
            signText2,
            verticalOffset,
            horizontalOffset,
          ),
      ],
    ),
  );
}



// =====================================================
// 🔹 HELPER — Accepted Customer Block (POSITIONED)
// =====================================================
pw.Widget _buildAcceptedCustomerBlock(
  double offsetX,
  double offsetY,
) {
  return pw.Transform.translate(
    offset: PdfPoint(offsetX, offsetY),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Accepted Customer',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Sign: ____________________',
          style: pw.TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

// =====================================================
// 🔹 SAFE SIGNATURE RENDERER (HEADER PROTECTED)
// =====================================================
pw.Widget _safeSignature(
  String signText1,
  Uint8List? signatureBytes,
  String signText2,
  double verticalOffset,
  double horizontalOffset,
) {
  return pw.Padding(
    padding: pw.EdgeInsets.only(
      top: verticalOffset,
      left: horizontalOffset > 0 ? horizontalOffset : 0,
      right: horizontalOffset < 0 ? -horizontalOffset : 0,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (signText1.isNotEmpty)
          pw.Text(
            signText1,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

        pw.SizedBox(height: 8),

        if (signatureBytes != null)
          pw.Image(
            pw.MemoryImage(signatureBytes),
            height: 60,
          ),

        pw.SizedBox(height: 6),

        if (signText2.isNotEmpty)
          pw.Text(
            signText2,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
      ],
    ),
  );
}
