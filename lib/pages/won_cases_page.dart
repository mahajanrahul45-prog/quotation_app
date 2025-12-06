// lib/pages/won_cases_page.dart
import 'package:flutter/material.dart';

import '../models/quotation.dart';
import '../storage/quotation_storage.dart';

class WonCasesPage extends StatefulWidget {
  const WonCasesPage({super.key});

  @override
  State<WonCasesPage> createState() => _WonCasesPageState();
}

class _WonCasesPageState extends State<WonCasesPage> {
  List<Quotation> _wonQuotations = [];

  @override
  void initState() {
    super.initState();
    _loadWonQuotations();
  }

  Future<void> _loadWonQuotations() async {
    // 1️⃣ Load all saved quotations
    final all = await QuotationStorage.loadQuotations();

    // 2️⃣ Keep only those where status == 'Won'
    setState(() {
      _wonQuotations = all.where((q) => q.status == 'Won').toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Won Cases'),
      ),
      body: _wonQuotations.isEmpty
          ? const Center(child: Text('No Won cases found.'))
          : ListView.builder(
              itemCount: _wonQuotations.length,
              itemBuilder: (context, index) {
                final q = _wonQuotations[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      'Quotation #${q.quotationNumber} — ${q.customerName}',
                    ),
                    subtitle: Text(
                      'Date: ${q.date.toString().split(" ")[0]}  |  Total: ₹${q.totalAmount.toStringAsFixed(2)}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
