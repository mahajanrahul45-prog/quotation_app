import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/account_session.dart';
import 'cloud_preferences.dart';

String buildingNameKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Display-only union. Existing customers take precedence; source records stay intact.
List<Map<String, dynamic>> uniqueBuildings(
  Iterable<Map<String, dynamic>> records,
) {
  final names = <String>{};
  return records.where((record) {
    final key = buildingNameKey((record['customerName'] ?? '').toString());
    return key.isNotEmpty && names.add(key);
  }).toList();
}

class ServiceBuildings {
  static const storageKey = 'service_buildings';
  static List<Map<String, dynamic>> decode(List<String> values) => values
      .map((value) => Map<String, dynamic>.from(jsonDecode(value) as Map))
      .toList();

  static Future<List<Map<String, dynamic>>> managedBuildings() async {
    final session = AccountSession.instance;
    if (session.profile?.isMaster != true || session.viewingUser) return [];
    final uid = session.profile!.uid;
    final users = await FirebaseFirestore.instance
        .collection('accounts')
        .where('masterUid', isEqualTo: uid)
        .where('role', isEqualTo: 'user')
        .get(const GetOptions(source: Source.server));
    final lists = await Future.wait(
      users.docs.map((user) async {
        final values = await CloudPreferences.readManagedServiceList(
          user.id,
          storageKey,
        );
        return decode(values).map(
          (building) => <String, dynamic>{
            ...building,
            '_serviceBuilding': true,
            '_ownerEmail': user.data()['email'] ?? '',
          },
        );
      }),
    );
    if (session.profile?.uid != uid || session.viewingUser) {
      throw StateError('Account changed.');
    }
    return lists.expand((list) => list).toList();
  }
}
