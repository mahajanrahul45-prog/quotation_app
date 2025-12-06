// lib/pages/dashboard_page.dart
import 'dart:convert';
import 'dart:io'; // 👈 ADD this
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/right_side_drawer.dart';

import 'package:file_picker/file_picker.dart';   // ✅ NEW
import 'package:marquee/marquee.dart';   // 👈 add this


// If you have a QuotationStorage helper, import it.
// If the file path is different in your project adjust the import below.
import '../storage/quotation_storage.dart'; // <--- adjust path if needed

class DashboardPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const DashboardPage({super.key, required this.toggleTheme});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // these will be filled from storage
  int totalQuotations = 0;
  int totalCustomers = 0;
  double totalQuotationAmount = 0.0;

   // 👇 ADD THIS //👇 for bottom logo (already there)
  String? _logoPath;

  // 🔹 NEW: running banner settings & text
  bool _showTicker = false;
  String _tickerText = '';   // will hold "Company | Phone | Website"

  @override
  void initState() {
    super.initState();
    loadDashboardData();   // Load quotations & totals
    _loadUiSettings();     // 👈 NEW: load logo + banner prefs + company text
  }

  // 🔹 NEW: load logo path, ticker toggle and company details from Page Setup
  Future<void> _loadUiSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Use the same keys as PageSetupPage
    final String? logoPath = prefs.getString('logoPath');  // 👈 NOTE: 'logoPath', not 'page_setup_logo'
    final bool showTicker =
        prefs.getBool('dashboard_ticker_enabled') ?? false;

    final String companyName = prefs.getString('company_name') ?? '';
    final String companyPhone = prefs.getString('company_phone') ?? '';
    final String companyWebsite = prefs.getString('company_website') ?? '';

    // Build ticker text: "Company | Ph: xxx | website"
    final buffer = StringBuffer();
    if (companyName.isNotEmpty) buffer.write(companyName);
    if (companyPhone.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('   |   ');
      buffer.write('Ph: $companyPhone');
    }
    if (companyWebsite.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('   |   ');
      buffer.write(companyWebsite);
    }

    // Check logo file exists (optional, safe)
    String? finalLogoPath;
    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        finalLogoPath = logoPath;
      }
    }

    if (!mounted) return;
    setState(() {
      _logoPath = finalLogoPath;
      _showTicker = showTicker;
      _tickerText = buffer.toString();
    });
  }


  /// Loads quotations and customers from persistent storage and updates UI.
  ///
  /// Strategy:
  /// 1) Try to use QuotationStorage.getAllQuotations() if available in your project.
  ///    That method should return a List of saved quotations (either model objects
  ///    or maps). If it exists the code will use it.
  /// 2) If QuotationStorage isn't available or doesn't work, fall back to reading
  ///    SharedPreferences keys 'quotations' and 'customers', which store JSON strings.
  Future<void> loadStats() async {
    try {
      // === Attempt 1: use QuotationStorage if available ===
      // QuotationStorage.getAllQuotations should return something like:
      // List<Quotation> or List<Map<String, dynamic>>
      // If your QuotationStorage exposes a different method name, change it here.
      final dynamic quotationsFromStorage = await QuotationStorage.getAllQuotations();

      if (quotationsFromStorage is List) {
        // number of quotations
        final count = quotationsFromStorage.length;

        // compute total amount safely:
        double sum = 0.0;
        for (final q in quotationsFromStorage) {
          if (q == null) continue;
          // possible shapes: Quotation object with .totalAmount,
          // or Map<String,dynamic> with 'totalAmount' key,
          // or Map with 'products' list.
          if (q is Map && q.containsKey('totalAmount')) {
            sum += (q['totalAmount'] ?? 0).toDouble();
          } else {
            try {
              // try property access (if it's a model object)
              final dynamic val = q.totalAmount;
              if (val != null) sum += (val as num).toDouble();
            } catch (_) {
              // fallback: if products exist, sum product totals
              if (q is Map && q.containsKey('products')) {
                final products = q['products'] as List? ?? [];
                for (final p in products) {
                  // product total may be 'total' or calculated
                  if (p is Map && p.containsKey('total')) {
                    sum += (p['total'] ?? 0).toDouble();
                  }
                }
              }
            }
          }
        }

        if (!mounted) return;
        setState(() {
          totalQuotations = count;
          totalQuotationAmount = sum;
        });

        // Also load customers count from SharedPreferences (common pattern)
        await _loadCustomersFromPrefs();
        return;
      }
    } catch (e) {
      // ignore and fall back to SharedPreferences below
      // (most likely QuotationStorage doesn't have the method yet)
    }

    // === Fallback: read SharedPreferences directly ===
    final prefs = await SharedPreferences.getInstance();

    // Quotations: many apps store them as a StringList under 'quotations'
    final storedQuotations = prefs.getStringList('quotations') ?? <String>[];
    int qCount = storedQuotations.length;
    double sumAmount = 0.0;

    for (final s in storedQuotations) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        // common fields: 'totalAmount' or 'total'
        if (decoded.containsKey('totalAmount')) {
          sumAmount += (decoded['totalAmount'] ?? 0).toDouble();
        } else if (decoded.containsKey('total')) {
          sumAmount += (decoded['total'] ?? 0).toDouble();
        } else if (decoded.containsKey('products')) {
          // sum product totals if quotation stores products list
          final products = decoded['products'] as List? ?? [];
          for (final p in products) {
            if (p is Map && p.containsKey('total')) {
              sumAmount += (p['total'] ?? 0).toDouble();
            }
          }
        }
      } catch (_) {
        // skip malformed entry
      }
    }

    // Customers
    final storedCustomers = prefs.getStringList('customers') ?? <String>[];
    final cCount = storedCustomers.length;

    if (!mounted) return;
    setState(() {
      totalQuotations = qCount;
      totalCustomers = cCount;
      totalQuotationAmount = sumAmount;
    });
  }

  // helper used when QuotationStorage succeeded to still load customers
  Future<void> _loadCustomersFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCustomers = prefs.getStringList('customers') ?? <String>[];
    if (!mounted) return;
    setState(() {
      totalCustomers = storedCustomers.length;
    });
  }

  Future<void> loadDashboardData() async {
  // 1) Load all saved quotations
  final list = await QuotationStorage.loadQuotations();

  // 2) Calculate total quotations
  int count = list.length;

  // 3) Calculate total amount of all quotations
  double sum = 0;
  for (var q in list) {
    sum += q.totalAmount; // because totalAmount is a double in your model
  }

   // 4) Load customers from SharedPreferences and count them
  final prefs = await SharedPreferences.getInstance();
  // We expect customers saved as a StringList under key 'customers'
  final storedCustomers = prefs.getStringList('customers') ?? <String>[];
  final int customersCount = storedCustomers.length;

  // 5) Update UI state (guard mounted)
  if (!mounted) return;
  setState(() {
    totalQuotations = count;
    totalQuotationAmount = sum;
    totalCustomers = customersCount;   // <- this line makes "Total Customers" show
  });
}

  /// 🔄 BACKUP: save all app data (models, customers, quotations, settings) into one JSON file
  Future<void> _backupData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1️⃣ Collect everything into one Map
      final data = <String, dynamic>{
        'models': prefs.getStringList('models') ?? <String>[],
        'customers': prefs.getStringList('customers') ?? <String>[],
        'quotations': prefs.getStringList('quotations') ?? <String>[],
        'settings': {
          'watermarkOpacity': prefs.getDouble('watermarkOpacity'),
          'logoPath': prefs.getString('logoPath'),
          'company_name': prefs.getString('company_name'),
          'company_address': prefs.getString('company_address'),
          'company_phone': prefs.getString('company_phone'),
          'company_contact': prefs.getString('company_contact'),
          'company_email': prefs.getString('company_email'),
          'company_website': prefs.getString('company_website'),
          'company_gstin': prefs.getString('company_gstin'),
          'header_logo_on_left':
              prefs.getBool('header_logo_on_left'),
          'page_setup_watermark':
              prefs.getString('page_setup_watermark'),
        },
      };

      // 2️⃣ Convert map → JSON string
      final jsonString = jsonEncode(data);

      // 3️⃣ Ask user where to save the file
      final defaultFileName =
          'quotation_backup_${DateTime.now().toIso8601String().replaceAll(":", "-")}.json';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select where to save backup',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath == null) {
        // user cancelled
        return;
      }

      // 4️⃣ Write file
      final file = File(savePath);
      await file.writeAsString(jsonString);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved: $savePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  /// 🔁 RESTORE: load all app data from a backup JSON file
  Future<void> _restoreData() async {
    try {
      // 1️⃣ Let user pick a .json backup file
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select backup file',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        // user cancelled
        return;
      }

      final backupPath = result.files.single.path!;
      final file = File(backupPath);
      final contents = await file.readAsString();

      // 2️⃣ Decode JSON
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid backup format');
      }

      final prefs = await SharedPreferences.getInstance();

      // 3️⃣ Restore lists (models, customers, quotations)
      final models = (decoded['models'] as List?) ?? <dynamic>[];
      await prefs.setStringList(
        'models',
        models.map((e) => e.toString()).toList(),
      );

      final customers = (decoded['customers'] as List?) ?? <dynamic>[];
      await prefs.setStringList(
        'customers',
        customers.map((e) => e.toString()).toList(),
      );

      final quotations = (decoded['quotations'] as List?) ?? <dynamic>[];
      await prefs.setStringList(
        'quotations',
        quotations.map((e) => e.toString()).toList(),
      );

      // 4️⃣ Restore settings (page setup, company details, etc.)
      final settings = decoded['settings'] as Map<String, dynamic>?;

      if (settings != null) {
        final opacityRaw = settings['watermarkOpacity'];
        if (opacityRaw is num) {
          await prefs.setDouble('watermarkOpacity', opacityRaw.toDouble());
        }

        if (settings['logoPath'] is String) {
          await prefs.setString('logoPath', settings['logoPath'] as String);
        }

        if (settings['company_name'] is String) {
          await prefs.setString(
              'company_name', settings['company_name'] as String);
        }
        if (settings['company_address'] is String) {
          await prefs.setString(
              'company_address', settings['company_address'] as String);
        }
        if (settings['company_phone'] is String) {
          await prefs.setString(
              'company_phone', settings['company_phone'] as String);
        }
        if (settings['company_contact'] is String) {
          await prefs.setString(
              'company_contact', settings['company_contact'] as String);
        }
        if (settings['company_email'] is String) {
          await prefs.setString(
              'company_email', settings['company_email'] as String);
        }
        if (settings['company_website'] is String) {
          await prefs.setString(
              'company_website', settings['company_website'] as String);
        }
        if (settings['company_gstin'] is String) {
          await prefs.setString(
              'company_gstin', settings['company_gstin'] as String);
        }
        if (settings['header_logo_on_left'] is bool) {
          await prefs.setBool('header_logo_on_left',
              settings['header_logo_on_left'] as bool);
        }
        if (settings['page_setup_watermark'] is String) {
          await prefs.setString('page_setup_watermark',
              settings['page_setup_watermark'] as String);
        }
      }

      // 5️⃣ Refresh dashboard numbers (quotations, customers, amount)
      await loadDashboardData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data restored from backup')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }



    @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState!.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: RightSideDrawer(toggleTheme: widget.toggleTheme),
            body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 📊 Top: stats grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  _buildStatCard(
                    "Total Quotations",
                    totalQuotations.toString(),
                    Icons.description,
                  ),
                  _buildStatCard(
                    "Total Customers",
                    totalCustomers.toString(),
                    Icons.people,
                  ),
                  _buildStatCard(
                    "Total Amount",
                    "₹${totalQuotationAmount.toStringAsFixed(2)}",
                    Icons.attach_money,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 NEW: running logo + company banner (optional)
            if (_showTicker) _buildRunningBanner(),

            if (_showTicker) const SizedBox(height: 10),

            // 🔁 Backup / Restore buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _backupData,
                    icon: const Icon(Icons.backup),
                    label: const Text('Backup Data'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restoreData,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Data'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 👇 Bottom bar: logo + developer name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_logoPath != null)
                  SizedBox(
                    height: 32,
                    child: Image.file(
                      File(_logoPath!),
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  const SizedBox.shrink(),

                const Text(
                  'Developed by Rahul Mahajan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

    );
  }
  // 🔹 Running (marquee) banner with logo + company info
  Widget _buildRunningBanner() {
    // If disabled or no text, show nothing
    if (!_showTicker || _tickerText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Logo on the left (if available)
          if (_logoPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Image.file(
                File(_logoPath!),
                height: 26,
                fit: BoxFit.contain,
              ),
            ),

          // Scrolling text area
          Expanded(
  child: Marquee(
    text: _tickerText,
    // 🔹 Horizontal scrolling
    scrollAxis: Axis.horizontal,
    // 🔹 Make text flow right ➜ left
    textDirection: TextDirection.rtl,
    blankSpace: 50.0,
    velocity: 30.0,
    startPadding: 10.0,
    pauseAfterRound: const Duration(milliseconds: 500),
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  ),
),

        ],
      ),
    );
  }

  // 👇 This is OUTSIDE build(), but still inside _DashboardPageState
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
