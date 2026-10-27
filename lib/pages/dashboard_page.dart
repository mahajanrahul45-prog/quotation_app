import '../services/workspace_backup.dart';
import '../models/maintenance_lifecycle.dart';
import '../storage/maintenance_quotation_storage.dart';
import '../auth/account_session.dart';
import '../widgets/app_scaffold.dart';
// lib/pages/dashboard_page.dart
// ---------- FILE NOTES ----------
// Changes made (copy-paste safe):
// 1) NEW: added state vars for banner: _dashboardTickerEnabled, _tickerText, _dashboardLogoFile
// 2) NEW: added loader functions _loadDashboardTickerFlag() and _loadLogoAndCompanyName()
// 3) UPDATED: initState() now calls those two loaders (reliable single source of truth)
// 4) REMOVED (kept for reference): removed direct _loadUiSettings() call from initState to avoid duplication
//    (The original _loadUiSettings() implementation is kept commented at the end of the file for reference.)
// 5) UPDATED: build() and _buildRunningBanner() use the unified state variables
// ---------------------------------

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../storage/cloud_preferences.dart';
import '../widgets/right_side_drawer.dart';
import '../pages/page_setup_page.dart'; // <- add this
//import '../restart_wrapper.dart';
import 'package:file_picker/file_picker.dart'; // ✅ NEW (already present in your file)
import 'package:marquee/marquee.dart'; // ✅ NEW (already present in your file)

// If you have a QuotationStorage helper, import it.
// If the file path is different in your project adjust the import below.
import '../storage/quotation_storage.dart'; // <--- adjust path if needed

import 'saved_quotations_page.dart';
import 'saved_maintenance_quotations_page.dart';
import 'customers_page.dart';

import 'active_maintenance_page.dart';
import 'expiring_maintenance_page.dart';
import 'expired_maintenance_page.dart';
import 'renewed_maintenance_page.dart';

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
  int totalMaintenanceQuotations = 0; // ✅ NEW

  int activeCount = 0;
  int expiringCount = 0;
  int expiredCount = 0;
  int renewedCount = 0;
  bool _showActiveMaintenanceCard = true;
  bool _showExpiringSoonMaintenanceCard = true;
  bool _showExpiredMaintenanceCard = true;
  bool _showRenewedMaintenanceCard = true;

  // 👇 bottom logo path (optional)
  String? _logoPath;

  // ---------------- Running banner (ticker) state ----------------
  // NEW: single source of truth for the banner toggle + content
  bool _dashboardTickerEnabled = false; // NEW
  File? _dashboardLogoFile; // NEW
  String _dashboardCompanyName = ''; // NEW (optional)
  String _tickerText = ''; // NEW: built string for marquee

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  bool _refreshing = false;
  String? _onlineError;
  Future<void> _loadWorkspace() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _onlineError = null;
    });
    try {
      await Future.wait([
        loadDashboardData(),
        loadMaintenanceCounters(),
        _loadMaintenanceCardVisibility(),
        _loadDashboardTickerFlag(),
        _loadLogoAndCompanyName(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(
          () => _onlineError =
              'Unable to load your workspace. Refresh to try again. $e',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadMaintenanceCardVisibility() async {
    final prefs = await CloudPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _showActiveMaintenanceCard =
          prefs.getBool('show_active_maintenance_dashboard_card') ?? true;
      _showExpiringSoonMaintenanceCard =
          prefs.getBool('show_expiring_soon_maintenance_dashboard_card') ??
          true;
      _showExpiredMaintenanceCard =
          prefs.getBool('show_expired_maintenance_dashboard_card') ?? true;
      _showRenewedMaintenanceCard =
          prefs.getBool('show_renewed_maintenance_dashboard_card') ?? true;
    });
  }

  Future<void> _setMaintenanceCardVisibility({
    required String prefKey,
    required bool isVisible,
    required VoidCallback updateState,
  }) async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.setBool(prefKey, isVisible);
    if (!mounted) return;
    setState(updateState);
  }

  Future<void> _hideMaintenanceCard({
    required String title,
    required String prefKey,
    required VoidCallback hideCard,
    required VoidCallback showCard,
  }) async {
    await _setMaintenanceCardVisibility(
      prefKey: prefKey,
      isVisible: false,
      updateState: hideCard,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title card hidden from dashboard'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _setMaintenanceCardVisibility(
              prefKey: prefKey,
              isVisible: true,
              updateState: showCard,
            );
          },
        ),
      ),
    );
  }

  bool get _areAllMaintenanceCardsHidden =>
      !_showActiveMaintenanceCard &&
      !_showExpiringSoonMaintenanceCard &&
      !_showExpiredMaintenanceCard &&
      !_showRenewedMaintenanceCard;

  Future<void> _toggleAllMaintenanceCards() async {
    final shouldShowAll = _areAllMaintenanceCardsHidden;
    final prefs = await CloudPreferences.getInstance();

    await prefs.setBool(
      'show_active_maintenance_dashboard_card',
      shouldShowAll,
    );
    await prefs.setBool(
      'show_expiring_soon_maintenance_dashboard_card',
      shouldShowAll,
    );
    await prefs.setBool(
      'show_expired_maintenance_dashboard_card',
      shouldShowAll,
    );
    await prefs.setBool(
      'show_renewed_maintenance_dashboard_card',
      shouldShowAll,
    );

    if (!mounted) return;
    setState(() {
      _showActiveMaintenanceCard = shouldShowAll;
      _showExpiringSoonMaintenanceCard = shouldShowAll;
      _showExpiredMaintenanceCard = shouldShowAll;
      _showRenewedMaintenanceCard = shouldShowAll;
    });
  }

  Future<String> _getResetPin() async {
    final prefs = await CloudPreferences.getInstance();
    return prefs.getString('reset_pin') ?? '1234'; // default PIN
  }

  Future<void> loadMaintenanceCounters() async {
    final all = await MaintenanceQuotationStorage.load();
    if (!mounted) return;
    setState(() {
      activeCount = all
          .where(
            (q) => MaintenanceLifecycle.matches(q, all, MaintenanceView.active),
          )
          .length;
      expiringCount = all
          .where(
            (q) => MaintenanceLifecycle.matches(
              q,
              all,
              MaintenanceView.expiringSoon,
            ),
          )
          .length;
      expiredCount = all
          .where(
            (q) =>
                MaintenanceLifecycle.matches(q, all, MaintenanceView.expired),
          )
          .length;
      renewedCount = all
          .where((q) => MaintenanceLifecycle.renewedThisMonth(q))
          .length;
    });
  }

  // ------------------ NEW loader: saved boolean flag ------------------
  Future<void> _loadDashboardTickerFlag() async {
    final prefs = await CloudPreferences.getInstance();
    final bool enabled = prefs.getBool('dashboard_ticker_enabled') ?? false;
    if (!mounted) return;
    setState(() {
      _dashboardTickerEnabled = enabled;
    });
  }

  Future<bool> _askResetPin() async {
    final controller = TextEditingController();
    bool isValid = false;

    final savedPin = await _getResetPin();
    if (!mounted) return false;

    await showDialog(
      context: context, // ✅ SAFE: State.context + mounted checked
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter Reset PIN'),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'PIN',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                if (controller.text == savedPin) {
                  isValid = true;
                  Navigator.of(ctx).pop();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                }
              },
            ),
          ],
        );
      },
    );

    return isValid;
  }

  Future<void> _resetApplicationData() async {
    if (AccountSession.instance.profile?.isMaster != true) return;
    // Capture messenger only (navigator not needed)
    final messenger = ScaffoldMessenger.of(context);

    // Ask PIN
    final pinOk = await _askResetPin();
    if (!pinOk) return;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Application'),
        content: const Text(
          'This will delete ALL data including:\n\n'
          '• Products\n'
          '• Customers\n'
          '• Quotations\n'
          '• Categories & Makes\n'
          '• Settings\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Clear storage
    final prefs = await CloudPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    // Reset in-memory state
    setState(() {
      totalQuotations = 0;
      totalCustomers = 0;
      totalQuotationAmount = 0.0;

      _logoPath = null;
      _dashboardLogoFile = null;
      _dashboardCompanyName = '';
      _tickerText = '';
      _dashboardTickerEnabled = false;
    });

    // Reload dashboard safely
    await loadDashboardData();

    if (!mounted) return;

    // ✅ SAFE: messenger used correctly
    messenger.showSnackBar(
      const SnackBar(content: Text('Application reset successfully')),
    );
  }

  Future<void> _showChangePinDialog() async {
    if (AccountSession.instance.profile?.isMaster != true) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    final prefs = await CloudPreferences.getInstance();
    if (!mounted) return;

    final currentPin = prefs.getString('reset_pin') ?? '1234';

    await showDialog(
      context: context, // ✅ SAFE
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Change Reset PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Confirm New PIN'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (oldPinCtrl.text != currentPin) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Current PIN incorrect')),
                  );
                  return;
                }

                if (newPinCtrl.text.length < 4) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('PIN must be at least 4 digits'),
                    ),
                  );
                  return;
                }

                if (newPinCtrl.text != confirmPinCtrl.text) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('PINs do not match')),
                  );
                  return;
                }

                await prefs.setString('reset_pin', newPinCtrl.text);

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Reset PIN updated successfully'),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ------------------ NEW loader: logo path + build ticker text ------------------
  Future<void> _loadLogoAndCompanyName() async {
    final prefs = await CloudPreferences.getInstance();
    final String? logoPath = prefs.getString('logoPath');
    final String companyName = prefs.getString('company_name') ?? '';
    final String companyPhone = prefs.getString('company_phone') ?? '';
    final String companyWebsite = prefs.getString('company_website') ?? '';

    // Build ticker text (Company | Ph | Website)
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

    String? finalLogoPath;
    File? logoFile;
    if (logoPath != null && logoPath.startsWith('data:image/')) {
      finalLogoPath = logoPath;
    } else if (!kIsWeb && logoPath != null && logoPath.isNotEmpty) {
      final f = File(logoPath);
      if (await f.exists()) {
        finalLogoPath = logoPath;
        logoFile = f;
      }
    }

    if (!mounted) return;
    setState(() {
      _logoPath = finalLogoPath;
      _dashboardLogoFile = logoFile;
      _dashboardCompanyName = companyName;
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
  ///    CloudPreferences keys 'quotations' and 'customers', which store JSON strings.
  Future<void> loadStats() async {
    try {
      // === Attempt 1: use QuotationStorage if available ===
      final dynamic quotationsFromStorage =
          await QuotationStorage.getAllQuotations();

      if (quotationsFromStorage is List) {
        final count = quotationsFromStorage.length;
        double sum = 0.0;
        for (final q in quotationsFromStorage) {
          if (q == null) continue;
          if (q is Map && q.containsKey('totalAmount')) {
            sum += (q['totalAmount'] ?? 0).toDouble();
          } else {
            try {
              final dynamic val = q.totalAmount;
              if (val != null) sum += (val as num).toDouble();
            } catch (_) {
              if (q is Map && q.containsKey('products')) {
                final products = q['products'] as List? ?? [];
                for (final p in products) {
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

        // Also load customers count from CloudPreferences
        await _loadCustomersFromPrefs();
        return;
      }
    } catch (e) {
      // ignore and fall back to CloudPreferences below
    }

    // === Fallback: read CloudPreferences directly ===
    final prefs = await CloudPreferences.getInstance();

    final storedQuotations = prefs.getStringList('quotations') ?? <String>[];
    int qCount = storedQuotations.length;
    double sumAmount = 0.0;

    for (final s in storedQuotations) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        if (decoded.containsKey('totalAmount')) {
          sumAmount += (decoded['totalAmount'] ?? 0).toDouble();
        } else if (decoded.containsKey('total')) {
          sumAmount += (decoded['total'] ?? 0).toDouble();
        } else if (decoded.containsKey('products')) {
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
    final prefs = await CloudPreferences.getInstance();
    final storedCustomers = prefs.getStringList('customers') ?? <String>[];
    if (!mounted) return;
    setState(() {
      totalCustomers = storedCustomers.length;
    });
  }

  Future<void> loadDashboardData() async {
    // 1) Load all saved quotations (your original logic)
    final list = await QuotationStorage.loadQuotations();

    // 2) Calculate total quotations
    int count = list.length;

    // 3) Calculate total amount of all quotations
    double sum = 0;
    for (var q in list) {
      sum += q.totalAmount; // assuming your model has totalAmount
    }

    // 4) Load customers from CloudPreferences and count them
    final prefs = await CloudPreferences.getInstance();
    final storedCustomers = prefs.getStringList('customers') ?? <String>[];
    final int customersCount = storedCustomers.length;

    // 4.1) Load maintenance quotations count
    final storedMaintenance =
        prefs.getStringList('maintenance_quotations') ?? <String>[];
    final int maintenanceCount = storedMaintenance.length;

    // 5) Update UI state
    if (!mounted) return;
    setState(() {
      totalQuotations = count;
      totalQuotationAmount = sum;
      totalCustomers = customersCount;
      totalMaintenanceQuotations = maintenanceCount; // ✅ ADD
    });
  }

  bool _backupBusy = false;

  Future<void> _backupData() async {
    if (_backupBusy || AccountSession.instance.profile?.isMaster != true) {
      return;
    }
    setState(() => _backupBusy = true);
    try {
      final prefs = await CloudPreferences.getInstance();
      final data = await prefs.exportBackupValues();
      if (data.isEmpty) {
        throw StateError('There is no workspace data to back up.');
      }
      final bytes = Uint8List.fromList(
        utf8.encode(WorkspaceBackup.encode(data)),
      );
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save workspace backup',
        fileName:
            'quotation_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      // On desktop saveFile selects a path; the caller must write the file.
      if (!kIsWeb &&
          savePath != null &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await File(savePath).writeAsBytes(bytes, flush: true);
      }
      if (!mounted || (!kIsWeb && savePath == null)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Backup download started. Keep the file in a safe place.'
                : 'Workspace backup saved successfully.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreData() async {
    if (_backupBusy || AccountSession.instance.profile?.isMaster != true) {
      return;
    }
    setState(() => _backupBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select workspace backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final selected = result.files.single;
      final bytes = selected.bytes;
      if (bytes == null) {
        throw const FormatException('Could not read the selected file.');
      }
      final values = WorkspaceBackup.decode(utf8.decode(bytes));
      final prefs = await CloudPreferences.getInstance();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore workspace data?'),
          content: Text(
            'Restore ${values.length} data sections from "${selected.name}"? '
            'Matching sections will be replaced. Sections missing from this backup will be kept. '
            'Create a current backup first if you need to keep the existing versions. '
            'Restored data will sync to this workspace when online.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore data'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await prefs.restoreBackupValues(values);
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data restored on this device. Cloud sync will continue automatically.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          // open drawer (your existing button) - keep it
          IconButton(
            tooltip: 'Open navigation',
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState!.openEndDrawer();
            },
          ),

          // NEW: Settings / Page Setup button — we await the push and refresh when it returns true
          if (AccountSession.instance.can('settings'))
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Page Setup',
              onPressed: () async {
                // capture context BEFORE await
                final navigator = Navigator.of(context);

                final result = await navigator.push<bool>(
                  MaterialPageRoute(builder: (_) => const PageSetupPage()),
                );

                if (result == true) {
                  await _loadDashboardTickerFlag();
                  await _loadLogoAndCompanyName();

                  if (!mounted) return;
                  setState(() {});
                }
              },
            ),
        ],
      ),

      endDrawer: RightSideDrawer(
        toggleTheme: widget.toggleTheme,
        onResetApp: _resetApplicationData,
        onChangePin: _showChangePinDialog,
        onBackup: _backupData,
        onRestore: _restoreData,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_refreshing) const LinearProgressIndicator(),
            if (_onlineError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _onlineError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (AccountSession.instance.profile?.isMaster == false &&
                !AccountSession.instance.profile!.permissions.values.any(
                  (v) => v,
                ))
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Your account is active. Ask your master administrator to grant access to the functions you need.',
                  ),
                ),
              ),
            // 📊 Top: stats grid
            if (AccountSession.instance.viewingUser)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_shared_outlined),
                  title: Text(
                    'User data: ${AccountSession.instance.viewEmail}',
                  ),
                  subtitle: const Text('Changes apply to this user workspace.'),
                  trailing: IconButton(
                    tooltip: 'Return to master workspace',
                    icon: const Icon(Icons.close),
                    onPressed: () => AccountSession.instance.viewOwn(),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _refreshing ? null : _loadWorkspace,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh online data'),
              ),
            ),
            Text(
              'Business overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your quotations, customers and service activity at a glance.',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth < 360
                    ? 1
                    : 2,
                mainAxisExtent: 180,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  if (AccountSession.instance.can('quotations'))
                    _buildStatCard(
                      "Total Quotations",
                      totalQuotations.toString(),
                      Icons.description,
                    ),
                  if (AccountSession.instance.can('customers'))
                    _buildStatCard(
                      "Total Customers",
                      totalCustomers.toString(),
                      Icons.people,
                    ),
                  if (AccountSession.instance.can('quotations'))
                    _buildStatCard(
                      "Total Amount",
                      "₹${totalQuotationAmount.toStringAsFixed(2)}",
                      Icons.attach_money,
                    ),
                  if (AccountSession.instance.can('maintenance'))
                    _buildStatCard(
                      "Total Maintenance Quotations",
                      totalMaintenanceQuotations.toString(),
                      Icons.build, // 🛠 maintenance icon
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ===============================
            // 📊 Maintenance Status Counters
            // ===============================
            if (AccountSession.instance.can('maintenance'))
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _toggleAllMaintenanceCards,
                  icon: Icon(
                    _areAllMaintenanceCardsHidden
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  label: Text(
                    _areAllMaintenanceCardsHidden ? 'Unhide All' : 'Hide All',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobileWidth = constraints.maxWidth < 420;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth < 360
                      ? 1
                      : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: isMobileWidth ? 112 : 104,
                  children: [
                    if (AccountSession.instance.can('maintenance') &&
                        _showActiveMaintenanceCard)
                      _buildMaintenanceCounterCard(
                        title: 'Active',
                        count: activeCount,
                        color: Colors.green,
                        icon: Icons.check_circle,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ActiveMaintenancePage(),
                            ),
                          ).then((_) => loadMaintenanceCounters());
                        },
                        onHide: () => _hideMaintenanceCard(
                          title: 'Active',
                          prefKey: 'show_active_maintenance_dashboard_card',
                          hideCard: () => _showActiveMaintenanceCard = false,
                          showCard: () => _showActiveMaintenanceCard = true,
                        ),
                      ),
                    if (AccountSession.instance.can('maintenance') &&
                        _showExpiringSoonMaintenanceCard)
                      _buildMaintenanceCounterCard(
                        title: 'Expiring Soon',
                        count: expiringCount,
                        color: Colors.orange,
                        icon: Icons.schedule,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ExpiringMaintenancePage(),
                            ),
                          ).then((_) => loadMaintenanceCounters());
                        },
                        onHide: () => _hideMaintenanceCard(
                          title: 'Expiring Soon',
                          prefKey:
                              'show_expiring_soon_maintenance_dashboard_card',
                          hideCard: () =>
                              _showExpiringSoonMaintenanceCard = false,
                          showCard: () =>
                              _showExpiringSoonMaintenanceCard = true,
                        ),
                      ),
                    if (AccountSession.instance.can('maintenance') &&
                        _showExpiredMaintenanceCard)
                      _buildMaintenanceCounterCard(
                        title: 'Expired',
                        count: expiredCount,
                        color: Colors.red,
                        icon: Icons.cancel,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ExpiredMaintenancePage(),
                            ),
                          ).then((_) => loadMaintenanceCounters());
                        },
                        onHide: () => _hideMaintenanceCard(
                          title: 'Expired',
                          prefKey: 'show_expired_maintenance_dashboard_card',
                          hideCard: () => _showExpiredMaintenanceCard = false,
                          showCard: () => _showExpiredMaintenanceCard = true,
                        ),
                      ),
                    if (AccountSession.instance.can('maintenance') &&
                        _showRenewedMaintenanceCard)
                      _buildMaintenanceCounterCard(
                        title: 'Renewed this month',
                        count: renewedCount,
                        color: Colors.blue,
                        icon: Icons.autorenew,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RenewedMaintenancePage(),
                            ),
                          ).then((_) => loadMaintenanceCounters());
                        },
                        onHide: () => _hideMaintenanceCard(
                          title: 'Renewed this month',
                          prefKey: 'show_renewed_maintenance_dashboard_card',
                          hideCard: () => _showRenewedMaintenanceCard = false,
                          showCard: () => _showRenewedMaintenanceCard = true,
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // 🔹 NEW: running logo + company banner (optional)
            if (_dashboardTickerEnabled) _buildRunningBanner(),
            if (_dashboardTickerEnabled) const SizedBox(height: 10),

            // 🔁 Backup / Restore buttons
            if (AccountSession.instance.profile?.isMaster == true)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _backupBusy ? null : _backupData,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Backup Data'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _backupBusy ? null : _restoreData,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Data'),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // 👇 Bottom bar: logo + developer name (UPDATED to show company name under logo)
            Wrap(
              spacing: 24,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Left: logo with company name shown *below* the logo (if available)
                if (_logoPath != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height:
                            40, // slightly taller so logo looks nicer with text under it
                        child: kIsWeb
                            ? Image.memory(
                                UriData.parse(_logoPath!).contentAsBytes(),
                                fit: BoxFit.contain,
                              )
                            : Image.file(File(_logoPath!), fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 4),
                      // show company name if we have it (uses the variable you kept)
                      if (_dashboardCompanyName.isNotEmpty)
                        Text(
                          _dashboardCompanyName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  )
                else
                  const SizedBox.shrink(),

                // Right: developer credit (unchanged)
                const Text(
                  'Developed by Rahul Mahajan',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceCounterCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
    VoidCallback? onHide,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '($count)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -8,
                right: -10,
                child: PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'hide' && onHide != null) {
                      onHide();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'hide', child: Text('Hide')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunningBanner() {
    if (!_dashboardTickerEnabled || _tickerText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (_dashboardLogoFile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Image.file(
                _dashboardLogoFile!,
                height: 26,
                fit: BoxFit.contain,
              ),
            ),

          Expanded(
            child: Marquee(
              text: _tickerText,
              scrollAxis: Axis.horizontal,
              textDirection: TextDirection.rtl,
              blankSpace: 50.0,
              velocity: 30.0,
              startPadding: 10.0,
              pauseAfterRound: const Duration(milliseconds: 500),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 This is OUTSIDE build(), but still inside _DashboardPageState
  // =====================================================
  // 🔹 DASHBOARD STAT CARD WITH DOUBLE TAP NAVIGATION
  // =====================================================
  Widget _buildStatCard(String title, String value, IconData icon) {
    return GestureDetector(
      // 👇 DOUBLE TAP ACTION
      onTap: () {
        // 🔹 TOTAL QUOTATIONS → SAVED QUOTATIONS PAGE
        if (title == "Total Quotations") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavedQuotationsPage()),
          );
        }
        // 🔹 TOTAL CUSTOMERS → CUSTOMERS PAGE
        else if (title == "Total Customers") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomersPage()),
          );
        }
        // 🔹 TOTAL MAINTENANCE → SAVED MAINTENANCE PAGE
        else if (title == "Total Maintenance Quotations") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SavedMaintenanceQuotationsPage(),
            ),
          );
        }
      },

      // 🔹 EXISTING CARD UI (UNCHANGED)
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------
// REMOVED (kept for reference)
// ----------------------------
// The original _loadUiSettings() you had in the file was left here commented
// so you can compare or restore it if you prefer. I removed the live call
// to _loadUiSettings() from initState to avoid duplication (we now use two
// dedicated loaders: _loadDashboardTickerFlag() and _loadLogoAndCompanyName()).
//
// If you prefer the single function approach, you can restore this and remove
// the two smaller loaders; keep only one approach to avoid race/duplication.
//
// REMOVED CODE (commented out):
/*
  // 🔹 NEW: load logo path, ticker toggle and company details from Page Setup
  Future<void> _loadUiSettings() async {
    final prefs = await CloudPreferences.getInstance();

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
      _dashboardLogoFile = finalLogoPath != null ? File(finalLogoPath) : null;
      _dashboardCompanyName = companyName;
      _dashboardTickerEnabled = showTicker;
      _tickerText = buffer.toString();
    });
  }
*/
