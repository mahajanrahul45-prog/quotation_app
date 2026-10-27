import 'package:flutter/material.dart';
import '../models/maintenance_lifecycle.dart';
import 'saved_maintenance_quotations_page.dart';

class ExpiringMaintenancePage extends StatelessWidget {
  const ExpiringMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) => const SavedMaintenanceQuotationsPage(
    initialView: MaintenanceView.expiringSoon,
  );
}
