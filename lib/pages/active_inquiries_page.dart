// lib/pages/active_inquiries_page.dart
import 'package:flutter/material.dart';
import '../models/quotation.dart';
import '../storage/quotation_storage.dart';

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
      _activeQuotations =
          all.where((q) => q.status == 'Active').toList(); // 🔴 filter here
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Inquiries')),
      body: _activeQuotations.isEmpty
          ? const Center(child: Text('No active inquiries'))
          : ListView.builder(
              itemCount: _activeQuotations.length,
              itemBuilder: (context, index) {
                final q = _activeQuotations[index];
                return ListTile(
                  title: Text('Quotation #${q.quotationNumber} — ${q.customerName}'),
                  subtitle: Text(
                    'Date: ${q.date.toString().split(" ")[0]} | Total: ₹${q.totalAmount.toStringAsFixed(2)}',
                  ),
                );
              },
            ),
    );
  }
}
