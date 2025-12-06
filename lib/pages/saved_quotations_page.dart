import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  final TextEditingController _searchController = TextEditingController();

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

  /// Load all customers from SharedPreferences and build name -> phone map
  Future<void> _loadCustomerPhones() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('customers') ?? <String>[];

    final Map<String, String> result = {};
    for (final s in stored) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        final name = (decoded['customerName'] ?? '').toString();
        final phone = (decoded['phone'] ?? '').toString();
        if (name.isNotEmpty && phone.isNotEmpty) {
          result[name] = phone;
        }
      } catch (_) {
        // ignore broken entries
      }
    }

    if (!mounted) return;
    setState(() {
      _customerPhones.clear();
      _customerPhones.addAll(result);
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
  final prefs = await SharedPreferences.getInstance();
  final ctGst     = prefs.getString('ct_gst')     ?? '';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error opening WhatsApp: $e')),
    );
  }
}


/// Send quotation as PDF via WhatsApp (through system share sheet)
Future<void> _sendWhatsappPdf(Quotation q) async {
  try {
    // 1) Build PDF bytes using your existing helper
    final pdfBytes = await buildQuotationPdfBytes(
      quotationNumber: q.quotationNumber,
      customerName: q.customerName,
      products: q.products,
      totalAmount: q.totalAmount,
    );

    // 2) Save to a temporary file
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/quotation_${q.quotationNumber}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    // 3) Open system share dialog
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Quotation #${q.quotationNumber} for ${q.customerName}',
    );
    // User will choose WhatsApp / WhatsApp Business and contact
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error sharing PDF: $e')),
    );
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          MaterialPageRoute(
            builder: (_) => const WonCasesPage(),
          ),
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
          MaterialPageRoute(
            builder: (_) => const LostCasesPage(),
          ),
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
                      return Card(
                        child: ListTile(
                          leading: const Icon(CupertinoIcons.phone), 
                          isThreeLine: true, // NEW
                          title: Text(
                              'Quotation #${q.quotationNumber} — ${q.customerName}'),
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
          value: q.status.isEmpty ? 'Active' : q.status,

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
              q.status = value; // update quotation object in memory
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
                                builder: (_) => QuotationsPage(
                                  quotationToEdit: q,
                                ),
                              ),
                            );
                            await loadQuotations(); // reload after edit
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ✏️ Edit
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit Quotation',
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuotationsPage(
                                        quotationToEdit: q,
                                      ),
                                    ),
                                  );
                                  await loadQuotations();
                                },
                              ),

                              // 🖨 Print preview
                              IconButton(
                                icon: const Icon(Icons.print),
                                tooltip: 'Print Preview',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QuotationPreviewPage(
                                      quotationNumber: q.quotationNumber,
                                      products: q.products,
                                      totalAmount: q.totalAmount,
                                      selectedCustomer: {
                                        'name': q.customerName
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              // 🟢 WhatsApp send (choose PDF or Text)
IconButton(
  icon: const Icon(Icons.send),
  tooltip: 'Send via WhatsApp',
  onPressed: () => _showWhatsappOptions(q),
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
