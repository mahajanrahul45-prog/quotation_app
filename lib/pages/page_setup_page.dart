// lib/pages/page_setup_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PageSetupPage extends StatefulWidget {
  const PageSetupPage({super.key});

  @override
  State<PageSetupPage> createState() => _PageSetupPageState();
}


class _PageSetupPageState extends State<PageSetupPage> {
  double _watermarkOpacity = 0.1; // slider value for watermark
  File? _logoFile; // selected logo image

  int _selectedTemplate = 1; // 🔥 default template selection
  // 🔹 NEW: Header logo size (only affects header, not watermark)
  double _logoHeaderHeight = 80.0; // default height in PDF points

  // 🔹 NEW: Company details position offsets (in PDF points)
  double _companyOffsetX = 0.0; // left/right
  double _companyOffsetY = 0.0; // up/down

    // 🔹 NEW: Logo position offsets (in PDF points)
  double _logoOffsetX = 0.0; // left/right
  double _logoOffsetY = 0.0; // up/down

  // 🔹 NEW: watermark angle in degrees (for cross watermark)
  double _watermarkAngleDeg = -35.0; // negative = tilt left, positive = tilt right


    // Company info controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();

// 🔹 NEW: Notes (general notes, above Commercial T&C)
  final TextEditingController _notesController = TextEditingController();

  // ---------- NEW: Commercial Terms & Conditions ----------
final TextEditingController _ctPricesController = TextEditingController();
final TextEditingController _ctLegalController = TextEditingController();
final TextEditingController _ctGstController = TextEditingController();
final TextEditingController _ctFreightController = TextEditingController();
final TextEditingController _ctValidityController = TextEditingController();
final TextEditingController _ctInsuranceController = TextEditingController();
final TextEditingController _ctDeliveryPeriodController = TextEditingController();
final TextEditingController _ctWarrantyController = TextEditingController();
final TextEditingController _ctPaymentTermsController = TextEditingController();
final TextEditingController _ctServicesController = TextEditingController();

// ---------- NEW: Bank Details ----------

final TextEditingController _bankCompanyNameController = TextEditingController();
final TextEditingController _bankNameController = TextEditingController();
final TextEditingController _bankAccountController = TextEditingController();
final TextEditingController _bankBranchController = TextEditingController();
final TextEditingController _bankNeftRtgsController = TextEditingController();


  // Toggle: true => logo on LEFT, false => logo on RIGHT
  bool _logoOnLeft = true;

  // 🔹 NEW: Enable/Disable running logo + company text on Dashboard
  bool _dashboardTickerEnabled = false;



  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// ✅ Load saved logo and opacity from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedTemplate = prefs.getInt('page_template') ?? 1;


    setState(() {
      _watermarkOpacity = prefs.getDouble('watermarkOpacity') ?? 0.1;
            // 🔹 NEW: load watermark angle (degrees)
      _watermarkAngleDeg = prefs.getDouble('watermark_angle_deg') ?? -35.0;

            // 🔹 NEW: load dashboard ticker toggle
      _dashboardTickerEnabled =
          prefs.getBool('dashboard_ticker_enabled') ?? false;



      // 🔹 NEW: load header logo size (default 80)
    _logoHeaderHeight = prefs.getDouble('logo_header_height') ?? 80.0;

    // 🔹 NEW: load company details offsets (defaults 0, 0)
    _companyOffsetX = prefs.getDouble('company_offset_x') ?? 0.0;
    _companyOffsetY = prefs.getDouble('company_offset_y') ?? 0.0;

    // 🔹 NEW: load header logo offsets (default 0, 0)
  _logoOffsetX = prefs.getDouble('logo_offset_x') ?? 0.0;
  _logoOffsetY = prefs.getDouble('logo_offset_y') ?? 0.0;

      final path = prefs.getString('logoPath');
      if (path != null && File(path).existsSync()) {
        _logoFile = File(path);
      }

      // Company info
      _companyNameController.text = prefs.getString('company_name') ?? '';
      _addressController.text = prefs.getString('company_address') ?? '';
      _phoneController.text = prefs.getString('company_phone') ?? '';
      _contactPersonController.text = prefs.getString('company_contact') ?? '';
      _emailController.text = prefs.getString('company_email') ?? '';
      _websiteController.text = prefs.getString('company_website') ?? '';
      _gstinController.text = prefs.getString('company_gstin') ?? '';

      // 🔹 NEW: Notes
      _notesController.text       = prefs.getString('notes') ?? '';


            // Commercial Terms & Conditions
  _ctPricesController.text         = prefs.getString('ct_prices')          ?? '';
  _ctLegalController.text          = prefs.getString('ct_legal')           ?? '';
  _ctGstController.text            = prefs.getString('ct_gst')             ?? '';
  _ctFreightController.text        = prefs.getString('ct_freight')         ?? '';
  _ctValidityController.text       = prefs.getString('ct_validity')        ?? '';
  _ctInsuranceController.text      = prefs.getString('ct_insurance')       ?? '';
  _ctDeliveryPeriodController.text = prefs.getString('ct_delivery_period') ?? '';
  _ctWarrantyController.text       = prefs.getString('ct_warranty')        ?? '';
  _ctPaymentTermsController.text   = prefs.getString('ct_payment_terms')   ?? '';
  _ctServicesController.text       = prefs.getString('ct_services')        ?? '';

  // Bank details
  
  _bankCompanyNameController.text  = prefs.getString('bank_company_name')  ?? '';
  _bankNameController.text         = prefs.getString('bank_name')          ?? '';
  _bankAccountController.text      = prefs.getString('bank_account')       ?? '';
  _bankBranchController.text       = prefs.getString('bank_branch')        ?? '';
  _bankNeftRtgsController.text     = prefs.getString('bank_neft_rtgs')     ?? '';


      // Logo alignment (default = left)
      _logoOnLeft = prefs.getBool('header_logo_on_left') ?? true;


    });
  }

  /// ✅ Pick logo from gallery
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _logoFile = File(picked.path));
    }
  }

  /// ✅ Remove logo and update preferences
  Future<void> _removeLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logoPath');
    setState(() => _logoFile = null);
  }

  /// ✅ Save opacity (called when slider changes)
  Future<void> _saveOpacity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('watermarkOpacity', value);
  }

  /// ✅ Save all settings when user taps “Save & Return”
Future<void> _saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
   // Save watermark opacity
  await prefs.setDouble('watermarkOpacity', _watermarkOpacity);
    // 🔹 NEW: save watermark angle in degrees
  await prefs.setDouble('watermark_angle_deg', _watermarkAngleDeg);

    // Save selected template
  await prefs.setInt('page_template', _selectedTemplate);

    // 🔹 NEW: save dashboard running banner toggle
  await prefs.setBool('dashboard_ticker_enabled', _dashboardTickerEnabled);


  // 🔹 NEW: Save header logo size
  await prefs.setDouble('logo_header_height', _logoHeaderHeight);

  // 🔹 NEW: Save company details offsets
  await prefs.setDouble('company_offset_x', _companyOffsetX);
  await prefs.setDouble('company_offset_y', _companyOffsetY);

  // 🔹 NEW: Save header logo offsets
  await prefs.setDouble('logo_offset_x', _logoOffsetX);
  await prefs.setDouble('logo_offset_y', _logoOffsetY);

   // Save logo path
  if (_logoFile != null) {
    await prefs.setString('logoPath', _logoFile!.path);
  }

  // Save company info
    await prefs.setString('company_name', _companyNameController.text.trim());
    await prefs.setString('company_address', _addressController.text.trim());
    await prefs.setString('company_phone', _phoneController.text.trim());
    await prefs.setString('company_contact', _contactPersonController.text.trim());
    await prefs.setString('company_email', _emailController.text.trim());
    await prefs.setString('company_website', _websiteController.text.trim());
    await prefs.setString('company_gstin', _gstinController.text.trim());

    // 🔹 NEW: save Notes
    await prefs.setString('notes', _notesController.text.trim());

      // Commercial Terms & Conditions
  await prefs.setString('ct_prices',          _ctPricesController.text.trim());
  await prefs.setString('ct_legal',           _ctLegalController.text.trim());
  await prefs.setString('ct_gst',             _ctGstController.text.trim());
  await prefs.setString('ct_freight',         _ctFreightController.text.trim());
  await prefs.setString('ct_validity',        _ctValidityController.text.trim());
  await prefs.setString('ct_insurance',       _ctInsuranceController.text.trim());
  await prefs.setString('ct_delivery_period', _ctDeliveryPeriodController.text.trim());
  await prefs.setString('ct_warranty',        _ctWarrantyController.text.trim());
  await prefs.setString('ct_payment_terms',   _ctPaymentTermsController.text.trim());
  await prefs.setString('ct_services',        _ctServicesController.text.trim());

  // Bank details
  
  await prefs.setString('bank_company_name', _bankCompanyNameController.text.trim());
  await prefs.setString('bank_name',         _bankNameController.text.trim());
  await prefs.setString('bank_account',      _bankAccountController.text.trim());
  await prefs.setString('bank_branch',       _bankBranchController.text.trim());
  await prefs.setString('bank_neft_rtgs',    _bankNeftRtgsController.text.trim());


    // Save header logo alignment
    await prefs.setBool('header_logo_on_left', _logoOnLeft);

  // ✅ Safe context usage after async gap
  if (!mounted) return;
  // Go back to previous page (e.g., QuotationsPage)
  Navigator.pop(context);
}


// 🔍 Open the template preview screen and wait for user selection
Future<void> _openTemplatePreview() async {
  final selected = await Navigator.push<int>(
    context,
    MaterialPageRoute(
      builder: (_) => TemplatePreviewPage(
        currentTemplate: _selectedTemplate,         // current template
        logoFile: _logoFile,                        // logo image
        companyName: _companyNameController.text,   // company name
        address: _addressController.text,
        phone: _phoneController.text,
        contactPerson: _contactPersonController.text,
        email: _emailController.text,
        website: _websiteController.text,
        gstin: _gstinController.text,
      ),
    ),
  );

  if (selected != null) {
    setState(() {
      _selectedTemplate = selected;
    });
  }
}





    @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _gstinController.dispose();

_notesController.dispose(); // 🔹 NEW

  _ctPricesController.dispose();
  _ctLegalController.dispose();
  _ctGstController.dispose();
  _ctFreightController.dispose();
  _ctValidityController.dispose();
  _ctInsuranceController.dispose();
  _ctDeliveryPeriodController.dispose();
  _ctWarrantyController.dispose();
  _ctPaymentTermsController.dispose();
  _ctServicesController.dispose();

  
  _bankCompanyNameController.dispose();
  _bankNameController.dispose();
  _bankAccountController.dispose();
  _bankBranchController.dispose();
  _bankNeftRtgsController.dispose();




    super.dispose();




  }

  // 🔹 Helper for one labeled text field (used in Commercial T&C and Bank Details)
  Widget _buildTermField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Page Setup')),
    body: SafeArea(
      child: SingleChildScrollView(                   // 👈 makes page scrollable
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Company Logo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ✅ Display current logo or upload button
            Center(
              child: _logoFile != null
                  ? Column(
                      children: [
                        Image.file(_logoFile!, height: 120),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Remove Logo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _removeLogo,
                        ),
                      ],
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload Logo'),
                      onPressed: _pickLogo,
                    ),
            ),
            // 🔹 NEW: Header logo size slider
const SizedBox(height: 12),
const Text(
  'Header Logo Size',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
Slider(
  value: _logoHeaderHeight,
  min: 40,   // minimum size
  max: 150,  // maximum size
  divisions: 11,
  label: _logoHeaderHeight.toStringAsFixed(0),
  onChanged: (value) {
    setState(() {
      _logoHeaderHeight = value;
    });
  },
),
Text(
  'Current: ${_logoHeaderHeight.toStringAsFixed(0)} pt',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),

// 🔹 NEW: Header Logo Position (fine tuning)
const SizedBox(height: 16),
const Text(
  'Header Logo Position (Header)',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
const SizedBox(height: 4),

// Up
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    IconButton(
      icon: const Icon(Icons.arrow_upward),
      onPressed: () {
        setState(() {
          _logoOffsetY -= 5; // move logo up
        });
      },
    ),
  ],
),
// Left / Center / Right
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        setState(() {
          _logoOffsetX -= 5; // move logo left
        });
      },
    ),
    IconButton(
      icon: const Icon(Icons.center_focus_strong),
      tooltip: 'Reset logo position',
      onPressed: () {
        setState(() {
          _logoOffsetX = 0;
          _logoOffsetY = 0;
        });
      },
    ),
    IconButton(
      icon: const Icon(Icons.arrow_forward),
      onPressed: () {
        setState(() {
          _logoOffsetX += 5; // move logo right
        });
      },
    ),
  ],
),
// Down
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    IconButton(
      icon: const Icon(Icons.arrow_downward),
      onPressed: () {
        setState(() {
          _logoOffsetY += 5; // move logo down
        });
      },
    ),
  ],
),
Text(
  'Logo X: ${_logoOffsetX.toStringAsFixed(0)}, '
  'Y: ${_logoOffsetY.toStringAsFixed(0)}',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),


            const SizedBox(height: 24),

// ================= Company Details (input fields) =================
Card(
  child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Company Name
        TextField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        // Address
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),

        // Phone
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 8),

        // Contact Person
        TextField(
          controller: _contactPersonController,
          decoration: const InputDecoration(
            labelText: 'Contact Person',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        // Email
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),

        // Website
        TextField(
          controller: _websiteController,
          decoration: const InputDecoration(
            labelText: 'Website',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        // GSTIN
        TextField(
          controller: _gstinController,
          decoration: const InputDecoration(
            labelText: 'GSTIN',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
  ),
),

// 🔹 NEW: Company details position (for header)
const SizedBox(height: 8),
const Text(
  'Company Details Position (Header)',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
const SizedBox(height: 4),
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Up arrow
    IconButton(
      icon: const Icon(Icons.arrow_upward),
      onPressed: () {
        setState(() {
          _companyOffsetY -= 5; // move up
        });
      },
    ),
  ],
),
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Left
    IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        setState(() {
          _companyOffsetX -= 5; // move left
        });
      },
    ),
    // Reset
    IconButton(
      icon: const Icon(Icons.center_focus_strong),
      onPressed: () {
        setState(() {
          _companyOffsetX = 0;
          _companyOffsetY = 0;
        });
      },
      tooltip: 'Reset position',
    ),
    // Right
    IconButton(
      icon: const Icon(Icons.arrow_forward),
      onPressed: () {
        setState(() {
          _companyOffsetX += 5; // move right
        });
      },
    ),
  ],
),
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Down arrow
    IconButton(
      icon: const Icon(Icons.arrow_downward),
      onPressed: () {
        setState(() {
          _companyOffsetY += 5; // move down
        });
      },
    ),
  ],
),
Text(
  'X: ${_companyOffsetX.toStringAsFixed(0)}, Y: ${_companyOffsetY.toStringAsFixed(0)}',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),

const SizedBox(height: 16),
// 🔹 NEW: Toggle for running logo + company line on Dashboard
SwitchListTile(
  title: const Text('Show running logo + company name on Dashboard'),
  subtitle: const Text('Appears as a scrolling banner below the Dashboard totals'),
  value: _dashboardTickerEnabled,
  onChanged: (value) {
    setState(() {
      _dashboardTickerEnabled = value;
    });
  },
),

const SizedBox(height: 16),


            // ---------- WATERMARK OPACITY ----------
            const Text(
              'Watermark Opacity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Slider(
              value: _watermarkOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _watermarkOpacity.toStringAsFixed(1),
              onChanged: (value) {
                setState(() => _watermarkOpacity = value);
                _saveOpacity(value);
              },
            ),

            const SizedBox(height: 12),

// 🔹 NEW: WATERMARK ANGLE SLIDER
const Text(
  'Watermark Angle',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Slider(
  value: _watermarkAngleDeg,
  min: -90,   // tilt left
  max: 90,    // tilt right
  divisions: 18, // 10° steps
  label: '${_watermarkAngleDeg.toStringAsFixed(0)}°',
  onChanged: (value) {
    setState(() {
      _watermarkAngleDeg = value;
    });
    // no need to save here; _saveSettings() will save when user taps Save & Return
  },
),
Text(
  'Current: ${_watermarkAngleDeg.toStringAsFixed(0)}°',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),

            const SizedBox(height: 24),

            // =============== Notes (shown above Commercial Terms) ===============
const Text(
  'Notes',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),
const SizedBox(height: 8),
TextField(
  controller: _notesController,
  decoration: const InputDecoration(
    labelText: 'Notes',
    border: OutlineInputBorder(),
  ),
  maxLines: 3, // you can change to 4–5 if you want more space
),

const SizedBox(height: 16),


const Text(
  'Select Print Layout Template',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 10),

Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded(
      child: Text(
        'Current: Template $_selectedTemplate',
        style: const TextStyle(fontSize: 16),
      ),
    ),
    ElevatedButton.icon(
      onPressed: _openTemplatePreview,     // 👈 we will create this method in Step 2
      icon: const Icon(Icons.visibility),
      label: const Text('View & Select'),
    ),
  ],
),

const SizedBox(height: 16),







            // ================= Commercial Terms & Conditions =================
Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Commercial Terms And Conditions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),

        _buildTermField('Prices', _ctPricesController),
        _buildTermField('Legal', _ctLegalController),
        _buildTermField('GST', _ctGstController),
        _buildTermField('Frights', _ctFreightController),
        _buildTermField('Validity', _ctValidityController),
        _buildTermField('Insurance', _ctInsuranceController),
        _buildTermField('Delivery Period', _ctDeliveryPeriodController),
        _buildTermField('Warranty', _ctWarrantyController),
        _buildTermField('Payment Terms', _ctPaymentTermsController),
        _buildTermField('Services', _ctServicesController),
      ],
    ),
  ),
),

const SizedBox(height: 8),

// ================= Bank Details =================
Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bank Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),

        
        _buildTermField('Company Name', _bankCompanyNameController),
        _buildTermField('Bank Name', _bankNameController),
        _buildTermField('Account Number', _bankAccountController),
        _buildTermField('Branch', _bankBranchController),
        _buildTermField('NEFT/RTGS Code', _bankNeftRtgsController),
      ],
    ),
  ),
),


            // ✅ Save & Return button – you now scroll to it
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Save & Return'),
                onPressed: _saveSettings,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}// 👈 closes build()

} // 👈 closes _PageSetupPageState class






// 🔷 Small page to preview and select a template
class TemplatePreviewPage extends StatelessWidget {
  final int currentTemplate;
  final File? logoFile;
  final String companyName;
  final String address;
  final String phone;
  final String contactPerson;
  final String email;
  final String website;
  final String gstin;

  const TemplatePreviewPage({
    super.key,
    required this.currentTemplate,
    required this.logoFile,
    required this.companyName,
    required this.address,
    required this.phone,
    required this.contactPerson,
    required this.email,
    required this.website,
    required this.gstin,
  });

  @override
  Widget build(BuildContext context) {
    // Template short descriptions
    final List<String> templateNames = [
      'Template 1 – Classic\nLogo LEFT, text RIGHT',
      'Template 2 – Executive\nLogo RIGHT, text LEFT',
      'Template 3 – Corporate\nCentered header',
      'Template 4 – Premium\nTop logo + info',
      'Template 5 – Minimal\nBig centered branding',
      'Template 6 – Modern\nBig left logo + info',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Print Layout Template'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,       // 2 cards per row
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3 / 4, // tall-ish cards
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final templateNumber = index + 1;
            final bool isSelected = templateNumber == currentTemplate;

            return InkWell(
              onTap: () {
                Navigator.pop(context, templateNumber);
              },
              child: Card(
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                elevation: isSelected ? 4 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // 🔹 Mini real-like page preview
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ),
                          ),
                          child: _TemplateMiniPreview(
                            templateNumber: templateNumber,
                            logoFile: logoFile,
                            companyName: companyName,
                            address: address,
                            phone: phone,
                            contactPerson: contactPerson,
                            email: email,
                            website: website,
                            gstin: gstin,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        templateNames[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


// 🔹 Small visual preview per template (fake mini print page)
class _TemplateMiniPreview extends StatelessWidget {
  final int templateNumber;
  final File? logoFile;
  final String companyName;
  final String address;
  final String phone;
  final String contactPerson;
  final String email;
  final String website;
  final String gstin;

  const _TemplateMiniPreview({
    required this.templateNumber,
    required this.logoFile,
    required this.companyName,
    required this.address,
    required this.phone,
    required this.contactPerson,
    required this.email,
    required this.website,
    required this.gstin,
  });

  @override
  Widget build(BuildContext context) {
    final Color frameColor = Colors.grey.shade300;

    // --- Small logo widget ---
    Widget logoWidget() {
      if (logoFile != null) {
        return Image.file(
          logoFile!,
          height: 20,
          fit: BoxFit.contain,
        );
      }
      return Container(
        width: 30,
        height: 20,
        color: Colors.blueGrey,
      );
    }

    // --- Small company text block ---
    Widget companyInfo() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (companyName.isNotEmpty)
            Text(
              companyName,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (address.isNotEmpty)
            Text(
              address,
              style: const TextStyle(fontSize: 6),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (phone.isNotEmpty)
            Text(
              'Ph: $phone',
              style: const TextStyle(fontSize: 6),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (gstin.isNotEmpty)
            Text(
              'GSTIN: $gstin',
              style: const TextStyle(fontSize: 6),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    // --- Header arranged as per template ---
    Widget buildHeader() {
      switch (templateNumber) {
        case 2: // Executive – logo right, text left
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: companyInfo()),
              const SizedBox(width: 4),
              logoWidget(),
            ],
          );

        case 3: // Corporate – centered
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              logoWidget(),
              const SizedBox(height: 2),
              Center(child: companyInfo()),
            ],
          );

        case 4: // Premium – logo top, info below
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              logoWidget(),
              const SizedBox(height: 2),
              companyInfo(),
            ],
          );

        case 5: // Minimal – big centered branding
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              logoWidget(),
              const SizedBox(height: 2),
              if (companyName.isNotEmpty)
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );

        case 6: // Modern – big left logo + info under
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  logoWidget(),
                  const SizedBox(width: 4),
                  Expanded(child: companyInfo()),
                ],
              ),
            ],
          );

        case 1: // Classic – logo left, text right
        default:
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              logoWidget(),
              const SizedBox(width: 4),
              Expanded(child: companyInfo()),
            ],
          );
      }
    }

    // --- Fake quotation table area ---
    Widget buildTableArea() {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: frameColor, width: 0.5),
        ),
        child: Column(
          children: [
            // header row
            Container(
              height: 8,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 2),
            // 3–4 fake rows
            Container(height: 5, color: Colors.grey.shade100),
            const SizedBox(height: 1),
            Container(height: 5, color: Colors.grey.shade100),
            const SizedBox(height: 1),
            Container(height: 5, color: Colors.grey.shade100),
          ],
        ),
      );
    }

    // --- Fake Commercial Terms & Bank Details section ---
    Widget buildBottomSections() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          const Text(
            'Commercial Terms & Conditions',
            style: TextStyle(
              fontSize: 6,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Container(
            margin: const EdgeInsets.only(top: 1),
            height: 4,
            color: Colors.grey.shade100,
          ),
          Container(
            margin: const EdgeInsets.only(top: 1),
            height: 4,
            color: Colors.grey.shade100,
          ),
          const SizedBox(height: 3),
          const Text(
            'Bank Details',
            style: TextStyle(
              fontSize: 6,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Container(
            margin: const EdgeInsets.only(top: 1),
            height: 4,
            color: Colors.grey.shade100,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        children: [
          // Header (top area)
          buildHeader(),

          // Table (middle)
          Expanded(child: buildTableArea()),

          // Bottom terms + bank details
          buildBottomSections(),
        ],
      ),
    );
  }
}
