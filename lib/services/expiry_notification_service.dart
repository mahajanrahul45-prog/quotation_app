import '../models/maintenance_lifecycle.dart';
import '../models/maintenance_quotation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../auth/access_profile.dart';
import '../auth/account_session.dart';
import '../storage/cloud_preferences.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const _expiryNotificationTask = 'expiring-maintenance-notification';
const _expiryNotificationId = 7001;

@pragma('vm:entry-point')
void expiryNotificationCallback() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _expiryNotificationTask) return true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true;
      final doc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return true;
      AccountSession.instance.update(
        AccessProfile.fromMap(doc.id, doc.data()!),
      );
      await ExpiryNotificationService.showExpiringMaintenanceNotification();
    } catch (_) {
      return false;
    }
    return true;
  });
}

class ExpiryNotificationService {
  static Future<void> deactivate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _initializeNotifications();
    await _notifications.cancel(_expiryNotificationId);
    await Workmanager().cancelByUniqueName(_expiryNotificationTask);
  }

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'expiring_maintenance',
    'Expiring Maintenance',
    description: 'Reminders for maintenance quotations expiring soon.',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(expiryNotificationCallback);
    await _initializeNotifications(requestPermission: true);

    await Workmanager().registerPeriodicTask(
      _expiryNotificationTask,
      _expiryNotificationTask,
      frequency: const Duration(days: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await showExpiringMaintenanceNotification();
  }

  static Future<void> showExpiringMaintenanceNotification() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final accountUid = AccountSession.instance.profile?.uid;
    await _initializeNotifications();
    if (!AccountSession.instance.can('maintenance') ||
        AccountSession.instance.viewingUser) {
      await _notifications.cancel(_expiryNotificationId);
      return;
    }
    final expiring = await _loadExpiringQuotations();
    if (!AccountSession.instance.can('maintenance') ||
        AccountSession.instance.viewingUser ||
        AccountSession.instance.profile?.uid != accountUid ||
        FirebaseAuth.instance.currentUser?.uid != accountUid) {
      await _notifications.cancel(_expiryNotificationId);
      return;
    }
    if (expiring.isEmpty) {
      await _notifications.cancel(_expiryNotificationId);
      return;
    }

    String dateFormat(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';

    final lines = expiring.map((q) {
      final start = DateTime.parse(q['startDate'].toString());
      final end = DateTime.parse(q['endDate'].toString());
      return '${q['customer']}: ${dateFormat(start)} - ${dateFormat(end)}';
    }).toList();

    final body = lines.length == 1
        ? lines.single
        : '${lines.length} quotations expiring soon\n${lines.join('\n')}';

    await _notifications.show(
      _expiryNotificationId,
      'Maintenance expiring soon',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'expiring_maintenance',
          'Expiring Maintenance',
          channelDescription:
              'Reminders for maintenance quotations expiring soon.',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> _initializeNotifications({
    bool requestPermission = false,
  }) async {
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: settings),
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_channel);
    if (requestPermission) {
      await android?.requestNotificationsPermission();
    }
  }

  static Future<List<Map<String, dynamic>>> _loadExpiringQuotations() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getStringList('maintenance_quotations') ?? [];
    final all = stored
        .map((value) => Map<String, dynamic>.from(jsonDecode(value)))
        .toList();
    final models = all.map(MaintenanceQuotation.fromMap).toList();
    return models
        .where(
          (q) => MaintenanceLifecycle.matches(
            q,
            models,
            MaintenanceView.expiringSoon,
          ),
        )
        .map((q) => q.toMap())
        .toList();
  }
}
