import 'package:flutter/material.dart';
import '../models/maintenance_lifecycle.dart';
import 'saved_maintenance_quotations_page.dart';

class StatusMaintenancePage extends StatelessWidget {
  const StatusMaintenancePage({
    super.key,
    required this.status,
    required this.title,
  });
  final String status;
  final String title;

  @override
  Widget build(BuildContext context) => SavedMaintenanceQuotationsPage(
    initialView: switch (status.toLowerCase()) {
      'active' => MaintenanceView.active,
      'expiring soon' => MaintenanceView.expiringSoon,
      'expired' => MaintenanceView.expired,
      'renewed' => MaintenanceView.renewed,
      _ => MaintenanceView.all,
    },
  );
}
