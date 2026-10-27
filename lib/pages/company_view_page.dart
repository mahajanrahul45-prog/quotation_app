import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../storage/company_storage.dart';

class CompanyEditResult {
  final Company company;
  final int index;

  CompanyEditResult(this.company, this.index);
}

class CompanyViewPage extends StatefulWidget {
  final Company company;
  final int index;

  const CompanyViewPage({
    super.key,
    required this.company,
    required this.index,
  });

  @override
  State<CompanyViewPage> createState() => _CompanyViewPageState();
}

class _CompanyViewPageState extends State<CompanyViewPage> {
  // 🔴 SAFE DELETE METHOD
  Future<void> _deleteCompany() async {
    await CompanyStorage.deleteCompany(widget.index);

    // ✅ Always check mounted before using context after await
    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('settings')) return const AccessDenied();
    final company = widget.company;

    return AppScaffold(
      appBar: AppBar(title: const Text('View Company')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Company Name', company.companyName),
            _row('Address', company.address),
            _row('Phone', company.phone),
            _row('Contact Person', company.contactPerson),
            _row('Email', company.email),
            _row('Website', company.website),
            _row('GSTIN', company.gstin),

            const Divider(height: 30),

            _row('Bank Name', company.bankName),
            _row('Account Number', company.accountNumber),
            _row('Branch', company.branch),
            _row('IFSC', company.ifsc),

            const Spacer(),

            // ---------------- Buttons ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔴 Delete Button (SAFE)
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  label: const Text('Delete'),
                  onPressed: _deleteCompany,
                ),

                // ✏ Edit Button (NO async → SAFE)
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      CompanyEditResult(company, widget.index),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
