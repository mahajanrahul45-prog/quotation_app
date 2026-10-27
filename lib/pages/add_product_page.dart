import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';

class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('products')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: const Center(child: Text('Add Product Page Coming Soon...')),
    );
  }
}
