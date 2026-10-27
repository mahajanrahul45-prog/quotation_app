import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import '../storage/cloud_preferences.dart';

class MaintenancePageSetupPage extends StatefulWidget {
  const MaintenancePageSetupPage({super.key});

  @override
  State<MaintenancePageSetupPage> createState() =>
      _MaintenancePageSetupPageState();
}

class _MaintenancePageSetupPageState extends State<MaintenancePageSetupPage> {
  // =====================================================
  // 🔹 SETTINGS CONTROLS
  // =====================================================

  bool showOfferDate = true;
  bool showCustomerName = true;
  bool showPeriod = true;
  bool showLiftQty = true;
  bool showAmounts = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  // =====================================================
  // 🔹 LOAD SETTINGS
  // =====================================================
  Future<void> loadSettings() async {
    final prefs = await CloudPreferences.getInstance();

    setState(() {
      showOfferDate = prefs.getBool('m_showOfferDate') ?? true;
      showCustomerName = prefs.getBool('m_showCustomerName') ?? true;
      showPeriod = prefs.getBool('m_showPeriod') ?? true;
      showLiftQty = prefs.getBool('m_showLiftQty') ?? true;
      showAmounts = prefs.getBool('m_showAmounts') ?? true;
    });
  }

  // =====================================================
  // 🔹 SAVE SETTINGS
  // =====================================================
  Future<void> saveSettings() async {
    final prefs = await CloudPreferences.getInstance();

    await prefs.setBool('m_showOfferDate', showOfferDate);
    await prefs.setBool('m_showCustomerName', showCustomerName);
    await prefs.setBool('m_showPeriod', showPeriod);
    await prefs.setBool('m_showLiftQty', showLiftQty);
    await prefs.setBool('m_showAmounts', showAmounts);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maintenance page setup saved')),
    );

    Navigator.pop(context);
  }

  // =====================================================
  // 🔹 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('maintenance')) {
      return const AccessDenied();
    }
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Maintenance Page Setup'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _toggle(
            'Show Offer Date (bold)',
            showOfferDate,
            (v) => setState(() => showOfferDate = v),
          ),

          _toggle(
            'Show Customer / Building Name (bold)',
            showCustomerName,
            (v) => setState(() => showCustomerName = v),
          ),

          _toggle(
            'Show Maintenance Period',
            showPeriod,
            (v) => setState(() => showPeriod = v),
          ),

          _toggle(
            'Show Lift Quantity',
            showLiftQty,
            (v) => setState(() => showLiftQty = v),
          ),

          _toggle(
            'Show Amount Section',
            showAmounts,
            (v) => setState(() => showAmounts = v),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 🔹 HELPER
  // =====================================================
  Widget _toggle(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
