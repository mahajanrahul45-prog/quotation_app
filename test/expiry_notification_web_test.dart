@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/services/expiry_notification_service.dart';

void main() {
  test('web startup skips Android notification and background plugins', () async {
    await ExpiryNotificationService.deactivate();
    await ExpiryNotificationService.initialize();
    await ExpiryNotificationService.showExpiringMaintenanceNotification();
  });
}
