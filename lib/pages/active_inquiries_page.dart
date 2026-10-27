import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
// lib/pages/active_inquiries_page.dart
import 'package:flutter/material.dart';
import '../models/quotation.dart';
import '../storage/quotation_storage.dart';
import 'dashboard_page.dart';

class ActiveInquiriesPage extends StatefulWidget {
  const ActiveInquiriesPage({super.key});

  @override
  State<ActiveInquiriesPage> createState() => _ActiveInquiriesPageState();
}

class _ActiveInquiriesPageState extends State<ActiveInquiriesPage> {
  List<Quotation> _activeQuotations = [];

  @override
  void initState() {
    super.initState();
    _loadActiveQuotations();
  }

  Future<void> _loadActiveQuotations() async {
    final all = await QuotationStorage.loadQuotations();
    setState(() {
      _activeQuotations = all
          .where((q) => q.status == 'Active')
          .toList(); // 🔴 filter here
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('quotations')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Active Inquiries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardPage(toggleTheme: () {}),
                ),
                (route) => false, // clears navigation stack
              );
            },
          ),
        ],
      ),

      body: _activeQuotations.isEmpty
          ? const Center(child: Text('No active inquiries'))
          : ListView.builder(
              itemCount: _activeQuotations.length,
              itemBuilder: (context, index) {
                final q = _activeQuotations[index];
                return ListTile(
                  title: Text(
                    'Quotation #${q.quotationNumber} — ${q.customerName}',
                  ),
                  subtitle: Text(
                    'Date: ${q.date.toString().split(" ")[0]} | Total: ₹${q.totalAmount.toStringAsFixed(2)}',
                  ),
                );
              },
            ),
    );
  }
}
