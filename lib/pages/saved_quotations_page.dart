import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../storage/cloud_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'mail_settings_page.dart';
import '../models/quotation.dart';
import '../storage/quotation_storage.dart';
import 'quotations_page.dart';
import 'quotation_preview_page.dart';
import 'won_cases_page.dart';
import 'lost_cases_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../utils/quotation_pdf_helper.dart'; // 🔹 your PDF builder
import '../utils/quotation_number_helper.dart';

class SavedQuotationsPage extends StatefulWidget {
  const SavedQuotationsPage({super.key});

  @override
  State<SavedQuotationsPage> createState() => _SavedQuotationsPageState();
}

class _SavedQuotationsPageState extends State<SavedQuotationsPage> {
  // full list from storage
  List<Quotation> _allQuotations = [];
  // list shown on screen (filtered)
  List<Quotation> quotations = [];

  // NEW: possible status values
  final List<String> _statuses = ['Active', 'Won', 'Lost', 'Abandoned'];

  // name -> phone (loaded from customers data)
  final Map<String, String> _customerPhones = {};

  // name -> email (loaded from customers page)
  final Map<String, String> _customerEmails = {};

  final TextEditingController _searchController = TextEditingController();

  /// 🔹 Load selected email template from Mail Settings
  Future<Map<String, String>> _loadSelectedEmailTemplate() async {
    final prefs = await CloudPreferences.getInstance();

    final selectedName = prefs.getString('selected_email_template');
    final list = prefs.getStringList('email_templates') ?? [];

    if (selectedName == null || list.isEmpty) {
      return {'subject': '', 'body': '', 'signature': '', 'cc': ''};
    }

    for (final item in list) {
      final decoded = jsonDecode(item) as Map<String, dynamic>;
      if (decoded['name'] == selectedName) {
        return {
          'subject': decoded['subject'] ?? '',
          'body': decoded['body'] ?? '',
          'signature': decoded['signature'] ?? '',
          'cc': decoded['cc'] ?? '',
        };
      }
    }

    return {'subject': '', 'body': '', 'signature': '', 'cc': ''};
  }

  @override
  void initState() {
    super.initState();
    loadQuotations();
    _loadCustomerPhones(); // 🔁 also load customer phone numbers
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load saved quotations from storage
  Future<void> loadQuotations() async {
    final list = await QuotationStorage.loadQuotations();
    setState(() {
      _allQuotations = list;
      quotations = list; // initially show all
    });
  }

  /// Load all customers from CloudPreferences and build name -> phone map
  /// Load customer phone & email from CloudPreferences
  Future<void> _loadCustomerPhones() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getStringList('customers') ?? <String>[];

    final phoneMap = <String, String>{};
    final emailMap = <String, String>{};

    for (final s in stored) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        final name = (decoded['customerName'] ?? '').toString();
        final phone = (decoded['phone'] ?? '').toString();
        final email = (decoded['email'] ?? '').toString(); // 👈 IMPORTANT

        if (name.isNotEmpty) {
          if (phone.isNotEmpty) phoneMap[name] = phone;
          if (email.isNotEmpty) emailMap[name] = email;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _customerPhones.clear();
      _customerPhones.addAll(phoneMap);

      _customerEmails.clear();
      _customerEmails.addAll(emailMap);
    });
  }

  /// Filter quotations list by search query
  void _applyFilter(String query) {
    query = query.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        quotations = _allQuotations;
      });
      return;
    }

    setState(() {
      quotations = _allQuotations.where((q) {
        final customer = q.customerName.toLowerCase();
        final number = q.quotationNumber.toString();
        final total = q.totalAmount.toStringAsFixed(2);
        return customer.contains(query) ||
            number.contains(query) ||
            total.contains(query);
      }).toList();
    });
  }

  /// Build WhatsApp text message from a quotation
  /// Now async so we can load GST & Freight from Page Setup
  Future<String> _buildWhatsappMessage(Quotation q) async {
    final prefs = await CloudPreferences.getInstance();
    final ctGst = prefs.getString('ct_gst') ?? '';
    final ctFreight = prefs.getString('ct_freight') ?? '';

    final buffer = StringBuffer();
    //buffer.writeln('Quotation #${q.quotationNumber}');
    //buffer.writeln('Customer: ${q.customerName}');
    //buffer.writeln('Date: ${q.date.toString().split(" ")[0]}');
    //buffer.writeln('');
    buffer.writeln('Items:');

    for (final p in q.products) {
      final serial = p['serial'] ?? '';
      final modelNo = p['modelNo'] ?? '';
      final desc = p['modelDesc'] ?? '';
      final qty = p['qty'] ?? '';
      final unit = p['unit'] ?? '';
      final total = p['total'] ?? '';
      buffer.writeln(
        '$serial) $modelNo - $desc | Qty: $qty | Unit: ₹$unit | Total: ₹$total',
      );
    }

    buffer.writeln('');
    buffer.writeln('Grand Total: ₹${q.totalAmount.toStringAsFixed(2)}');

    // 🔹 Add only GST and Freight from Commercial Terms
    if (ctGst.isNotEmpty || ctFreight.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Commercial Terms:');
      if (ctGst.isNotEmpty) {
        buffer.writeln('GST: $ctGst');
      }
      if (ctFreight.isNotEmpty) {
        buffer.writeln('Freight: $ctFreight');
      }
    }

    return buffer.toString();
  }

  /// 🔹 Build PLAIN TEXT quotation table (email-safe)
  Future<String> _buildEmailTableText(Quotation q) async {
    final buffer = StringBuffer();

    buffer.writeln('----------------------------------------------');
    buffer.writeln('Quotation Items');
    buffer.writeln('----------------------------------------------');
    buffer.writeln('No | Model No | Description | Qty | Rate | Total');
    buffer.writeln('----------------------------------------------');

    for (final p in q.products) {
      buffer.writeln(
        '${p['serial']} | ${p['modelNo']} | ${p['modelDesc']} | ${p['qty']} | ₹${p['unit']} | ₹${p['total']}',
      );
    }

    buffer.writeln('----------------------------------------------');
    buffer.writeln('Grand Total : ₹${q.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------------');

    return buffer.toString();
  }

  // 🔴 DELETE quotation with confirmation (UI + storage sync)
  Future<void> _confirmDeleteQuotation(Quotation q) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text(
          'Are you sure you want to delete Quotation No. ${q.quotationNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ✅ 1. Delete from CloudPreferences
    await QuotationStorage.deleteQuotation(q.quotationNumber);

    // ✅ 2. Reload updated list from storage
    final updatedList = await QuotationStorage.loadQuotations();

    if (!mounted) return;

    // ✅ 3. Update UI state
    setState(() {
      _allQuotations = updatedList;
      quotations = updatedList;
    });

    // ✅ 4. Feedback
    messenger.showSnackBar(
      const SnackBar(content: Text('Quotation deleted successfully')),
    );
  }

  Future<void> _sendWhatsapp(Quotation q) async {
    final customerName = q.customerName;
    final phone = _customerPhones[customerName];

    // 1) Check if we have a phone number
    if (phone == null || phone.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No phone number found for "$customerName". Please update customer details.',
          ),
        ),
      );
      return;
    }

    // 2) Clean phone (digits only). Make sure this includes country code, e.g. 91XXXXXXXXXX
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number for "$customerName" is invalid. Please check it.',
          ),
        ),
      );
      return;
    }

    // 3) Build message text (table + total + GST + Freight)
    final message = await _buildWhatsappMessage(q);
    final encodedMessage = Uri.encodeComponent(message);

    // 4) Build WhatsApp URI
    //final uri = Uri.parse(
    // 'whatsapp://send?phone=$cleanedPhone&text=$encodedMessage',
    // );

    //add new below for whatsapp businees

    // ✅ Try WhatsApp Business first (android & iOS handle this via wa.me as well)
    //final waBusinessUri = Uri.parse(
    // 'https://wa.me/$cleanedPhone?text=$encodedMessage',
    //);

    // 4) Use wa.me link (Android will show WhatsApp / WhatsApp Business chooser)
    final uri = Uri.parse('https://wa.me/$cleanedPhone?text=$encodedMessage');

    // (Optional) debug print – you can see this in VS Code debug console
    // print('WA URI: $uri');

    // 5) Try to open WhatsApp
    try {
      // 👇 Directly try to open. If it fails, we catch the error.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp / WhatsApp Business.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening WhatsApp: $e')));
    }
  }

  /// Send quotation as PDF via WhatsApp (through system share sheet)
  Future<void> _sendWhatsappPdf(Quotation q) async {
    try {
      // 1) Build PDF bytes using your existing helper
      final pdfBytes = await buildQuotationPdfBytes(
        quotationNumber: q.quotationNumber,
        customerName: q.customerName,
        area: '', // ✅ FIX: saved quotation has no stored area
        products: q.products,
        productTables: q.productTables,
        tableTotalVisibility: q.tableTotalVisibility,
        totalAmount: q.totalAmount,
      );

      // 2) Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/quotation_${q.quotationNumber}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // 3) Open system share dialog
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Quotation No ${q.quotationNumber} for ${q.customerName}',
        ),
      );

      // User will choose WhatsApp / WhatsApp Business and contact
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
    }
  }

  void _showWhatsappOptions(Quotation q) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Send via WhatsApp PDF'),
                onTap: () async {
                  Navigator.pop(context); // close sheet
                  await _sendWhatsappPdf(q);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Send via WhatsApp Text'),
                onTap: () async {
                  Navigator.pop(context); // close sheet
                  await _sendWhatsapp(q);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// ------------------------------
  /// STEP 1: Choose Mail Type
  /// ------------------------------
  void _showMailTypeOptions(Quotation q) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Send Mail (Text only)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMailAppChooser(
                    q,
                    isPdf: false, // TEXT ONLY
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Send Mail (PDF attachment)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMailAppChooser(
                    q,
                    isPdf: true, // PDF
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// ------------------------------
  /// STEP 2: Mail App Chooser
  /// ------------------------------
  Future<void> _showMailAppChooser(Quotation q, {required bool isPdf}) async {
    if (isPdf) {
      await _sendEmailPdf(q); // opens chooser
    } else {
      await _sendEmailText(q); // opens chooser
    }
  }

  /// 🔹 Build email subject & body using LATEST active template
  Future<Map<String, String>> _buildEmailContent(Quotation q) async {
    // 1️⃣ ALWAYS reload selected template
    final template = await _loadSelectedEmailTemplate();

    final baseSubject = template['subject'] ?? '';
    final baseBody = template['body'] ?? '';
    final signature = template['signature'] ?? '';
    final cc = template['cc'] ?? '';

    // 2️⃣ Build formatted quotation number
    final fy = getFinancialYear(q.date);
    final quotationNo = buildQuotationNumber(
      year: fy,
      number: q.quotationNumber,
    );

    // 3️⃣ Build TEXT table
    final tableText = await _buildEmailTableText(q);

    // 4️⃣ Subject
    final subject = baseSubject.isEmpty
        ? quotationNo
        : '$baseSubject - $quotationNo';

    // 5️⃣ Final BODY (NO HTML)
    final body =
        '''
$baseBody

$tableText

$signature
''';

    return {'subject': subject, 'body': body, 'cc': cc};
  }

  Future<void> _sendEmailText(Quotation q) async {
    // 🔹 1) Customer email
    final customerEmail = _customerEmails[q.customerName];

    if (customerEmail == null || customerEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No email found for "${q.customerName}". Please update customer details.',
          ),
        ),
      );
      return;
    }

    // 🔹 2) Load ACTIVE template + table
    final emailData = await _buildEmailContent(q);

    // 🔹 3) Mailto URI (TEXT ONLY)
    final uri = Uri(
      scheme: 'mailto',
      path: customerEmail,
      queryParameters: {
        'subject': emailData['subject'],
        'body': emailData['body'],
        if (emailData['cc']!.isNotEmpty) 'cc': emailData['cc'],
      },
    );

    // 🔹 4) Open mail app chooser
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  //Send Email – PDF attachment
  Future<void> _sendEmailPdf(Quotation q) async {
    // 🔹 1) Get customer email
    final customerEmail = _customerEmails[q.customerName];

    if (customerEmail == null || customerEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No email found for "${q.customerName}". Please update customer details.',
          ),
        ),
      );
      return;
    }

    // 🔹 2) Build PDF
    final pdfBytes = await buildQuotationPdfBytes(
      quotationNumber: q.quotationNumber,
      customerName: q.customerName,
      area: '', // ✅ FIX: saved quotation has no stored area
      products: q.products,
      productTables: q.productTables,
      tableTotalVisibility: q.tableTotalVisibility,
      totalAmount: q.totalAmount,
    );

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/quotation_${q.quotationNumber}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    // 🔹 3) Build subject/body from template
    final emailData = await _buildEmailContent(q);

    // 🔹 4) Share PDF → mail apps auto appear
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: emailData['subject'],
        text: emailData['body'],
        // recipients: [customerEmail], // ✅ AUTO EMAIL
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('quotations')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Saved Quotations'),
        actions: [
          // 🏆 Won cases button
          IconButton(
            icon: const Icon(Icons.emoji_events), // trophy icon
            tooltip: 'Won Cases',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WonCasesPage()),
              );
            },
          ),

          // 😞 Lost cases button
          IconButton(
            icon: const Icon(Icons.sentiment_dissatisfied),
            tooltip: 'Lost Cases',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LostCasesPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Mail Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MailSettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by customer, quotation no, or total',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter('');
                        },
                      ),
              ),
              onChanged: _applyFilter,
            ),
          ),

          // 📜 List of quotations
          Expanded(
            child: quotations.isEmpty
                ? const Center(child: Text('No saved quotations found.'))
                : ListView.builder(
                    itemCount: quotations.length,
                    itemBuilder: (context, i) {
                      final q = quotations[i];
                      // ✅ STEP 1: Declare variables BEFORE ListTile
                      final fy = getFinancialYear(q.date);
                      final displayNo = buildQuotationNumber(
                        year: fy,
                        number: q.quotationNumber,
                      );
                      return Card(
                        child: ListTile(
                          onLongPress: () => _confirmDeleteQuotation(
                            q,
                          ), // 🔥 LONG PRESS DELETE
                          leading: const Icon(CupertinoIcons.phone),
                          isThreeLine: true, // NEW
                          // ✅ Changed format: "Quotation No. 1"
                          // ✅ STEP 2: Use variable inside widget
                          title: Text('$displayNo — ${q.customerName}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date: ${q.date.toString().split(" ")[0]}  |  Total: ₹${q.totalAmount.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Status: '),
                                  DropdownButton<String>(
                                    // if somehow status is empty, fallback to 'Active'
                                    value: q.status.isEmpty
                                        ? 'Active'
                                        : q.status,

                                    items: _statuses
                                        .map(
                                          (s) => DropdownMenuItem<String>(
                                            value: s,
                                            child: Text(s),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) async {
                                      if (value == null) return;

                                      setState(() {
                                        q.status =
                                            value; // update quotation object in memory
                                      });

                                      // Save updated quotation to storage
                                      await QuotationStorage.saveQuotation(q);

                                      // Reload list from storage (optional but safe)
                                      await loadQuotations();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuotationsPage(quotationToEdit: q),
                              ),
                            );
                            await loadQuotations(); // reload after edit
                          },
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                            ), // ⋮ three-dot icon
                            tooltip: 'Actions',
                            onSelected: (value) async {
                              switch (value) {
                                case 'edit':
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          QuotationsPage(quotationToEdit: q),
                                    ),
                                  );
                                  await loadQuotations();
                                  break;

                                case 'print':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuotationPreviewPage(
                                        quotationNumber: q.quotationNumber,
                                        products: q.products,
                                        productTables: q.productTables,
                                        tableTotalVisibility:
                                            q.tableTotalVisibility,
                                        totalAmount: q.totalAmount,
                                        selectedCustomer: {
                                          'name': q.customerName,
                                        },
                                      ),
                                    ),
                                  );
                                  break;

                                case 'mail':
                                  _showMailTypeOptions(q); // 👈 NEW FUNCTION
                                  break;

                                case 'whatsapp':
                                  _showWhatsappOptions(q);
                                  break;
                              }
                            },

                            itemBuilder: (context) => [
                              // ✏ Edit
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit, color: Colors.blue),
                                  title: Text('Edit'),
                                ),
                              ),

                              // 🖨 Print Preview
                              const PopupMenuItem(
                                value: 'print',
                                child: ListTile(
                                  leading: Icon(Icons.print),
                                  title: Text('Print Preview'),
                                ),
                              ),

                              // 📧 Send Mail (renamed)
                              const PopupMenuItem(
                                value: 'mail',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.email,
                                    color: Colors.deepPurple,
                                  ),
                                  title: Text('Send via Mail'),
                                ),
                              ),

                              // 🟢 Send WhatsApp
                              const PopupMenuItem(
                                value: 'whatsapp',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.send,
                                    color: Colors.green,
                                  ),
                                  title: Text('Send via WhatsApp'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
