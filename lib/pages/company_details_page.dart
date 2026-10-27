import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../storage/company_storage.dart';
import 'company_view_page.dart';
import '../storage/cloud_preferences.dart';

class CompanyDetailsPage extends StatefulWidget {
  const CompanyDetailsPage({super.key});

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  // ---------------- Controllers ----------------
  final companyNameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  final gstinCtrl = TextEditingController();

  final bankCompanyCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController();
  final accountCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();

  List<Company> companies = [];

  int? editingIndex; // 🔹 null = new company, not editing

  // ---------------- FONT SETTINGS ----------------
  List<String> availableFonts = [
    'Default',
    'Arial',
    'Calibri',
    'Oxanium', // image font
    'Montserrat',
    'Rajdhani',
  ];

  String selectedFont = 'Default';

  // font style
  bool fontBold = false;
  bool fontItalic = false;
  bool underlineCompanyName = false;

  // company anthem / heading
  final anthemCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  // ---------------- Load companies ----------------
  Future<void> _loadCompanies() async {
    final list = await CompanyStorage.loadCompanies();
    if (!mounted) return;
    setState(() => companies = list);
  }

  // ---------------- Save / Update Company ----------------
  Future<void> _saveCompany() async {
    final messenger = ScaffoldMessenger.of(context);

    final company = Company(
      companyName: companyNameCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      contactPerson: contactCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      website: websiteCtrl.text.trim(),
      gstin: gstinCtrl.text.trim(),
      bankCompanyName: bankCompanyCtrl.text.trim(),
      bankName: bankNameCtrl.text.trim(),
      accountNumber: accountCtrl.text.trim(),
      branch: branchCtrl.text.trim(),
      ifsc: ifscCtrl.text.trim(),

      // 🔹 FONT SETTINGS
      fontFamily: selectedFont,
      bold: fontBold,
      italic: fontItalic,
      underline: underlineCompanyName,
      anthem: anthemCtrl.text.trim(),
    );

    // ================== SAVE TO SHARED PREFS (FOR PDF) ==================
    final prefs = await CloudPreferences.getInstance();

    await prefs.setString('company_anthem', anthemCtrl.text.trim());
    await prefs.setString('company_font_family', selectedFont);
    await prefs.setBool('company_font_bold', fontBold);
    await prefs.setBool('company_font_italic', fontItalic);
    await prefs.setBool('company_font_underline', underlineCompanyName);

    // 🔹 If editing, update existing company
    if (editingIndex != null) {
      await CompanyStorage.updateCompany(editingIndex!, company);
    } else {
      await CompanyStorage.saveCompany(company);
    }

    editingIndex = null;
    _clearForm();
    await _loadCompanies();

    messenger.showSnackBar(
      const SnackBar(content: Text('Company saved successfully')),
    );
  }

  // ---------------- Load company for editing ----------------
  void _loadForEdit(Company company, int index) {
    setState(() {
      editingIndex = index;

      companyNameCtrl.text = company.companyName;
      addressCtrl.text = company.address;
      phoneCtrl.text = company.phone;
      contactCtrl.text = company.contactPerson;
      emailCtrl.text = company.email;
      websiteCtrl.text = company.website;
      gstinCtrl.text = company.gstin;

      bankCompanyCtrl.text = company.bankCompanyName;
      bankNameCtrl.text = company.bankName;
      accountCtrl.text = company.accountNumber;
      branchCtrl.text = company.branch;
      ifscCtrl.text = company.ifsc;

      // 🔥 FIX — load anthem when editing

      anthemCtrl.text = company.anthem;
    });
  }

  void _clearForm() {
    companyNameCtrl.clear();
    addressCtrl.clear();
    phoneCtrl.clear();
    contactCtrl.clear();
    emailCtrl.clear();
    websiteCtrl.clear();
    gstinCtrl.clear();

    anthemCtrl.clear();

    bankCompanyCtrl.clear();
    bankNameCtrl.clear();
    accountCtrl.clear();
    branchCtrl.clear();
    ifscCtrl.clear();
  }

  // ================= FONT STYLE BUILDER =================
  TextStyle _companyTextStyle({bool isCompanyName = false}) {
    return TextStyle(
      // Use custom font only if not system font
      fontFamily:
          selectedFont == 'Default' ||
              selectedFont == 'Arial' ||
              selectedFont == 'Calibri'
          ? null
          : selectedFont,

      fontWeight: fontBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: fontItalic ? FontStyle.italic : FontStyle.normal,

      // Underline only for company name
      decoration: isCompanyName && underlineCompanyName
          ? TextDecoration.underline
          : TextDecoration.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('settings')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(title: const Text('Company Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------------- Company Form ----------------
            _field(companyNameCtrl, 'Company Name'),
            _field(addressCtrl, 'Address'),
            _field(phoneCtrl, 'Phone'),
            _field(contactCtrl, 'Contact Person'),
            _field(emailCtrl, 'Email'),
            _field(websiteCtrl, 'Website'),
            _field(gstinCtrl, 'GSTIN'),
            // ---------------- COMPANY ANTHEM ----------------
            _field(anthemCtrl, 'Company Anthem / Special Heading'),

            // ---------------- FONT SETTINGS UI ----------------
            const SizedBox(height: 12),
            const Text(
              'Font Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            // FONT DROPDOWN
            DropdownButtonFormField<String>(
              initialValue: selectedFont,
              decoration: const InputDecoration(
                labelText: 'Select Font',
                border: OutlineInputBorder(),
              ),
              items: availableFonts
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => selectedFont = v!),
            ),

            const SizedBox(height: 8),

            // ---------------- FONT TYPE OPTIONS ----------------
            const SizedBox(height: 8),
            const Text(
              'Font Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            CheckboxListTile(
              title: const Text('Bold (All company details)'),
              value: fontBold,
              onChanged: (v) => setState(() => fontBold = v ?? false),
            ),

            CheckboxListTile(
              title: const Text('Italic (All company details)'),
              value: fontItalic,
              onChanged: (v) => setState(() => fontItalic = v ?? false),
            ),

            CheckboxListTile(
              title: const Text('Underline (Company Name only)'),
              value: underlineCompanyName,
              onChanged: (v) =>
                  setState(() => underlineCompanyName = v ?? false),
            ),

            // ADD FONT BUTTON
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Load New Font'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'To add new font: copy .ttf into assets/fonts and restart app',
                    ),
                  ),
                );
              },
            ),

            //-----------------------------------------------------------------
            const SizedBox(height: 10),
            const Text(
              'Bank Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            _field(bankCompanyCtrl, 'Bank Company Name'),
            _field(bankNameCtrl, 'Bank Name'),
            _field(accountCtrl, 'Account Number'),
            _field(branchCtrl, 'Branch'),
            _field(ifscCtrl, 'IFSC / NEFT / RTGS'),

            const SizedBox(height: 12),

            //-------------------------------------------------------------

            // ---------------- FONT PREVIEW ----------------
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyNameCtrl.text.isEmpty
                        ? 'Company Name Preview'
                        : companyNameCtrl.text,
                    style: _companyTextStyle(isCompanyName: true),
                  ),

                  if (anthemCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(anthemCtrl.text, style: _companyTextStyle()),
                  ],
                ],
              ),
            ),

            // ---------------- Save Button ----------------
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(
                editingIndex == null ? 'Save Company' : 'Update Company',
              ),
              onPressed: _saveCompany,
            ),

            const Divider(height: 30),

            // ---------------- Saved Companies ----------------
            const Text(
              'Saved Companies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            ...companies.asMap().entries.map((entry) {
              final index = entry.key;
              final company = entry.value;

              return Card(
                child: ListTile(
                  title: Text(company.companyName),
                  subtitle: Text(company.bankName),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CompanyViewPage(company: company, index: index),
                        ),
                      );

                      // 🔹 If user tapped Edit
                      if (result is CompanyEditResult) {
                        _loadForEdit(result.company, result.index);
                      }

                      await _loadCompanies();
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
