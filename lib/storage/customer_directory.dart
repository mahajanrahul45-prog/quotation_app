import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../auth/account_session.dart';
import 'cloud_preferences.dart';
import 'service_buildings.dart';

/// A common, account-scoped customer/building directory for all document types.
/// Sharing publishes a master-controlled snapshot; source records stay intact.
class CustomerDirectory {
  static bool ownsCustomer(Map<String, dynamic> record) =>
      record['_shared'] != true &&
      record['_serviceBuilding'] != true &&
      record['_ownerUid'] == AccountSession.instance.dataUid;

  static bool get canApprove =>
      AccountSession.instance.profile?.isMaster == true &&
      !AccountSession.instance.viewingUser;

  static Map<String, dynamic> attributed(
    Map<String, dynamic> record,
    String uid,
    String email,
    String key,
  ) => {
    for (final field in [
      'partyName',
      'email',
      'phone',
      'address',
      'area',
      'state',
    ])
      field: '',
    ...record,
    'directoryId':
        record['directoryId'] ??
        sha256
            .convert(
              utf8.encode(
                '$uid|$key|${buildingNameKey(record['customerName'] ?? '')}',
              ),
            )
            .toString(),
    '_ownerUid': uid,
    '_ownerEmail': email,
    '_sourceKey': key,
    '_serviceBuilding': key == ServiceBuildings.storageKey,
  };

  static Future<List<Map<String, dynamic>>> load({
    bool deduplicate = true,
  }) async {
    final session = AccountSession.instance;
    final actor = session.profile?.uid;
    final prefs = await CloudPreferences.getInstance();
    final uid = prefs.uid;
    final email =
        session.viewEmail ?? session.profile?.email ?? 'This workspace';
    final records = <Map<String, dynamic>>[];
    for (final key in ['customers', ServiceBuildings.storageKey]) {
      // Local lists retain offline writes. Read only the missing directory
      // feature remotely when a document user has no master-data permission.
      final values =
          prefs.getStringList(key) ??
          (uid == 'test' ||
                  session.can(key == 'customers' ? 'customers' : 'service')
              ? <String>[]
              : await CloudPreferences.readDirectoryList(uid, key));
      records.addAll(
        ServiceBuildings.decode(
          values,
        ).map((r) => attributed(r, uid, email, key)),
      );
    }
    if (uid != 'test' && canApprove) {
      final users = await FirebaseFirestore.instance
          .collection('accounts')
          .where('masterUid', isEqualTo: actor)
          .where('role', isEqualTo: 'user')
          .get();
      for (final user in users.docs) {
        for (final key in ['customers', ServiceBuildings.storageKey]) {
          final values = await CloudPreferences.readDirectoryList(user.id, key);
          records.addAll(
            ServiceBuildings.decode(values).map(
              (r) => attributed(
                r,
                user.id,
                user.data()['email'] as String? ?? '',
                key,
              ),
            ),
          );
        }
      }
    } else if (uid != 'test') {
      final masterUid = session.profile!.isMaster
          ? session.profile!.uid
          : session.profile!.masterUid;
      final shared = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(masterUid)
          .collection('customerShares')
          .where('approvedEmails', arrayContains: email.toLowerCase())
          .get(const GetOptions(source: Source.server));
      for (final doc in shared.docs) {
        records.add({
          ...Map<String, dynamic>.from(doc.data()['customer'] as Map),
          '_shared': true,
        });
      }
    }
    if (session.profile?.uid != actor ||
        (uid != 'test' && session.dataUid != uid)) {
      throw StateError('Account changed. Open the directory again.');
    }
    return deduplicate ? uniqueBuildings(records) : records;
  }

  static Map<String, dynamic> creatorMetadata() => {
    'createdByUid': AccountSession.instance.profile?.uid ?? '',
    'createdByEmail': AccountSession.instance.profile?.email ?? '',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  };

  static String shareId(Map<String, dynamic> customer) => sha256
      .convert(
        utf8.encode(
          '${customer['_ownerUid']}|${customer['_sourceKey']}|${customer['directoryId'] ?? buildingNameKey(customer['customerName'] ?? '')}',
        ),
      )
      .toString();

  static DocumentReference<Map<String, dynamic>> _share(
    Map<String, dynamic> customer,
  ) => FirebaseFirestore.instance
      .collection('accounts')
      .doc(AccountSession.instance.profile!.uid)
      .collection('customerShares')
      .doc(shareId(customer));

  static Future<List<String>> approvedEmails(
    Map<String, dynamic> customer,
  ) async => List<String>.from(
    (await _share(customer).get(
          const GetOptions(source: Source.server),
        )).data()?['approvedEmails'] ??
        [],
  );

  static Future<void> revokeDeletedCustomer(
    Map<String, dynamic> customer,
  ) async {
    if (canApprove &&
        customer['_ownerUid'] == AccountSession.instance.profile!.uid) {
      await _share(customer).delete();
    }
  }

  static Future<List<String>> invitees() async {
    if (!canApprove) throw StateError('Only the master can approve customers.');
    final uid = AccountSession.instance.profile!.uid;
    final accounts = await FirebaseFirestore.instance
        .collection('accounts')
        .where('masterUid', isEqualTo: uid)
        .where('role', isEqualTo: 'user')
        .get();
    final invitations = await FirebaseFirestore.instance
        .collection('invitations')
        .where('masterUid', isEqualTo: uid)
        .get();
    return {
      ...accounts.docs
          .where((d) => d.data()['enabled'] == true)
          .map((d) => d.data()['email'] as String),
      ...invitations.docs
          .where((d) => d.data()['enabled'] == true)
          .map((d) => d.data()['email'] as String),
    }.toList()..sort();
  }

  static Future<void> approve(
    Map<String, dynamic> customer,
    List<String> emails,
  ) async {
    if (!canApprove ||
        customer['_ownerUid'] != AccountSession.instance.profile!.uid) {
      throw StateError('Approve customers from your own master workspace.');
    }
    await _share(customer).set({
      'customer': {
        for (final entry in customer.entries) entry.key: entry.value,
      },
      'approvedEmails': emails.map((e) => e.toLowerCase()).toSet().toList(),
      'updatedBy': AccountSession.instance.profile!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
