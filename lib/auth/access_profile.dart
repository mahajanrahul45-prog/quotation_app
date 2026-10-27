const featureLabels = <String, String>{
  'quotations': 'Quotations and inquiries',
  'customers': 'Customers',
  'products': 'Products',
  'maintenance': 'Maintenance quotations',
  'service': 'Service reports',
  'settings': 'Company, print and email settings',
};

String featureForKey(String key) {
  if (['quotations', 'saved_quotations'].contains(key) ||
      key.startsWith('showModel') ||
      ['showQty', 'showUnit', 'showAmount'].contains(key)) {
    return 'quotations';
  }
  if (key == 'customers') return 'customers';
  if (['models', 'product_categories', 'category_makes'].contains(key)) {
    return 'products';
  }
  if (key == 'maintenance_quotations' ||
      key == 'selected_maintenance_body_template' ||
      key.startsWith('m_') ||
      key.startsWith('maintenance_') ||
      key.contains('maintenance_dashboard_card')) {
    return 'maintenance';
  }
  if (key.startsWith('service_')) return 'service';
  return 'settings';
}

class AccessProfile {
  const AccessProfile({
    required this.uid,
    required this.email,
    required this.role,
    required this.masterUid,
    required this.enabled,
    required this.permissions,
  });
  final String uid, email, role, masterUid;
  final bool enabled;
  final Map<String, bool> permissions;
  bool get isMaster => role == 'master';
  bool can(String feature) =>
      enabled && (isMaster || permissions[feature] == true);
  factory AccessProfile.fromMap(String uid, Map<String, dynamic> data) =>
      AccessProfile(
        uid: uid,
        email: data['email'] as String? ?? '',
        role: data['role'] as String? ?? 'user',
        masterUid: data['masterUid'] as String? ?? '',
        enabled: data['enabled'] == true,
        permissions: (data['permissions'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v == true),
        ),
      );
}
