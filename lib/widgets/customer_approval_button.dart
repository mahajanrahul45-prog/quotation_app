import 'package:flutter/material.dart';
import '../auth/account_session.dart';
import '../storage/customer_directory.dart';

class CustomerApprovalButton extends StatefulWidget {
  const CustomerApprovalButton({super.key, required this.customer});
  final Map<String, dynamic> customer;

  @override
  State<CustomerApprovalButton> createState() => _CustomerApprovalButtonState();
}

class _CustomerApprovalButtonState extends State<CustomerApprovalButton> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    final actor = AccountSession.instance.profile?.uid;
    try {
      final emails = await CustomerDirectory.invitees();
      final approved = (await CustomerDirectory.approvedEmails(
        widget.customer,
      )).toSet();
      if (!mounted || AccountSession.instance.profile?.uid != actor) return;
      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('Approve customer access'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer['customerName'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose invited users who can select this customer in quotations, maintenance and service reports. Saving publishes the current customer details. Clear a selection to revoke access.',
                    ),
                    const SizedBox(height: 12),
                    if (emails.isEmpty)
                      const Text('Invite a user first from User Management.'),
                    for (final email in emails)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(email),
                        value: approved.contains(email),
                        onChanged: (checked) => refresh(() {
                          if (checked == true) {
                            approved.add(email);
                          } else {
                            approved.remove(email);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  approved.where(emails.contains).toList(),
                ),
                child: const Text('Save approval'),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      if (AccountSession.instance.profile?.uid != actor) {
        throw StateError('Account changed.');
      }
      await CustomerDirectory.approve(widget.customer, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer access updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update customer access: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CustomerDirectory.canApprove ||
        widget.customer['_ownerUid'] != AccountSession.instance.profile?.uid) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: _busy ? null : _approve,
      icon: const Icon(Icons.verified_user_outlined, size: 18),
      label: Text(_busy ? 'Loading...' : 'Approve user access'),
    );
  }
}
