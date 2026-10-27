import 'package:flutter/material.dart';
import '../models/maintenance_lifecycle.dart';
import 'saved_maintenance_quotations_page.dart';

class ExpiredMaintenancePage extends StatelessWidget {
  const ExpiredMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) => const SavedMaintenanceQuotationsPage(
    initialView: MaintenanceView.expired,
  );
}
