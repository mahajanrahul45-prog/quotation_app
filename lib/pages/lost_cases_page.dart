// lib/pages/lost_cases_page.dart
import 'package:flutter/material.dart';

import '../models/quotation.dart';
import '../storage/quotation_storage.dart';

class LostCasesPage extends StatefulWidget {
  const LostCasesPage({super.key});

  @override
  State<LostCasesPage> createState() => _LostCasesPageState();
}

class _LostCasesPageState extends State<LostCasesPage> {
  List<Quotation> _lostQuotations = [];

  @override
  void initState() {
    super.initState();
    _loadLostQuotations();
  }

  Future<void> _loadLostQuotations() async {
    // 1️⃣ Load all quotations from storage
    final all = await QuotationStorage.loadQuotations();

    // 2️⃣ Filter only those where status == 'Lost'
    setState(() {
      _lostQuotations = all.where((q) => q.status == 'Lost').toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Cases'),
      ),
      body: _lostQuotations.isEmpty
          ? const Center(child: Text('No Lost cases found.'))
          : ListView.builder(
              itemCount: _lostQuotations.length,
              itemBuilder: (context, index) {
                final q = _lostQuotations[index];
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
