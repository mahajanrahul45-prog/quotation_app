import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable account-scoped cache and outbox. Never stores login credentials.
class OfflineWorkspace {
  OfflineWorkspace(this.uid);
  final String uid;
  bool downloaded = false;
  Map<String, dynamic> values = {};
  Map<String, int> revisions = {};
  Map<String, dynamic> pending = {};
  static final Map<String, Future<OfflineWorkspace>> _instances = {};
  static Future<OfflineWorkspace> open(String uid) =>
      _instances.putIfAbsent(uid, () async {
        final store = OfflineWorkspace(uid);
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('offline_workspace_v1_$uid');
        if (raw != null) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          store.downloaded = data['downloaded'] == true;
          store.values = Map<String, dynamic>.from(data['values']);
          store.revisions = (data['revisions'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          );
          store.pending = Map<String, dynamic>.from(data['pending']);
        }
        return store;
      });
  @visibleForTesting
  static void resetMemoryForTesting() => _instances.clear();

  Future<void> _tail = Future.value();
  Future<void> mutate(void Function() change) {
    final next = _tail.then((_) async {
      final previous = jsonEncode({
        'downloaded': downloaded,
        'values': values,
        'revisions': revisions,
        'pending': pending,
      });
      change();
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = await prefs.setString(
          'offline_workspace_v1_$uid',
          jsonEncode({
            'downloaded': downloaded,
            'values': values,
            'revisions': revisions,
            'pending': pending,
          }),
        );
        if (!saved) throw StateError('Could not save data on this device.');
      } catch (_) {
        final old = jsonDecode(previous) as Map<String, dynamic>;
        downloaded = old['downloaded'] == true;
        values = Map<String, dynamic>.from(old['values']);
        revisions = (old['revisions'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        );
        pending = Map<String, dynamic>.from(old['pending']);
        rethrow;
      }
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
}
