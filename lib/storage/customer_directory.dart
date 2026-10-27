import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../auth/account_session.dart';
import 'cloud_preferences.dart';
import 'cloud_payload_codec.dart';
import 'service_buildings.dart';

/// A common, account-scoped customer/building directory for all document types.
/// Sharing publishes a master-controlled snapshot; source records stay intact.
class CustomerDirectory {
  static bool ownsCustomer(Map<String, dynamic> record) =>
      record['_shared'] != true &&
      record['_serviceBuilding'] != true &&
      record['_ownerUid'] == AccountSession.instance.dataUid;

  /// Only customer records (not shared snapshots or service buildings) may be
  /// changed here. Firestore rules independently verify the account hierarchy.
  static bool canManageCustomer(Map<String, dynamic> record) =>
      ownsCustomer(record) ||
      (canApprove &&
          record['_shared'] != true &&
          record['_sourceKey'] == 'customers' &&
          record['_serviceBuilding'] != true &&
          record['_ownerUid'] is String &&
          (record['_ownerUid'] as String).isNotEmpty &&
          record['_ownerUid'] != AccountSession.instance.profile?.uid);

  static const editableFields = [
    'customerName', 'partyName', 'phone', 'email', 'address', 'area', 'state',
  ];

  /// Mutates the portable list without restoring or rewriting unrelated data.
  /// Ambiguous or stale records are rejected instead of editing a wrong person.
  static List<dynamic> changeManagedCustomer(
    List<dynamic> values,
    Map<String, dynamic> original,
    Map<String, dynamic>? updated,
  ) {
    final matches = <int>[];
    final records = <int, Map<String, dynamic>>{};
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      dynamic raw = value;
      if (raw is Map && raw.containsKey('__cloudJson')) raw = raw['__cloudJson'];
      if (raw is String) {
        try { raw = jsonDecode(raw); } on FormatException { continue; }
      }
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      final attributedRecord = attributed(record, original['_ownerUid'] as String,
          original['_ownerEmail'] as String? ?? '', 'customers');
      if (attributedRecord['directoryId'] != original['directoryId']) continue;
      if (editableFields.any((key) =>
          (record[key] ?? '').toString() != (original[key] ?? '').toString())) {
        throw StateError('This customer changed. Refresh the list and try again.');
      }
      matches.add(i);
      records[i] = record;
    }
    if (matches.length != 1) {
      throw StateError('Customer missing or duplicated. Refresh the list before trying again.');
    }
    final result = List<dynamic>.of(values);
    final index = matches.single;
    if (updated == null) {
      result.removeAt(index);
    } else {
      final record = records[index]!;
      for (final key in editableFields) {
        record[key] = updated[key] ?? '';
      }
      // Legacy IDs are derived from the old name. Persist it before a rename.
      record['directoryId'] = original['directoryId'];
      final value = values[index];
      if (value is Map && value.containsKey('__cloudJson')) {
        result[index] = {...value, '__cloudJson': record};
      } else if (value is String) {
        result[index] = jsonEncode(record);
      } else {
        result[index] = record;
      }
    }
    return result;
  }

  /// Foreign workspace changes are online-only and commit atomically to the
  /// latest Firestore revision. Offline edits are never reported as saved.
  static Future<void> changeManagedCustomerOnline(
    Map<String, dynamic> original, {
    Map<String, dynamic>? updated,
  }) async {
    final session = AccountSession.instance;
    final actor = session.profile?.uid;
    final owner = original['_ownerUid'] as String?;
    if (!canApprove || !canManageCustomer(original) || owner == actor) {
      throw StateError('Only the managing administrator can change this customer.');
    }
    final ref = FirebaseFirestore.instance.collection('accounts').doc(owner)
        .collection('data').doc('customers').collection('values').doc('customers');
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final meta = await tx.get(ref);
      if (!meta.exists || meta.data()?['deleted'] == true) {
        throw StateError('Customer list no longer exists. Refresh and try again.');
      }
      final revision = (meta.data()!['revision'] as num).toInt();
      final count = (meta.data()!['chunks'] as num).toInt();
      final chunks = <String>[];
      for (var i = 0; i < count; i++) {
        final part = await tx.get(ref.collection('chunks').doc('${revision}_$i'));
        if (!part.exists) throw StateError('Customer data is incomplete. Try again.');
        chunks.add(part.data()!['payload'] as String);
      }
      final payload = CloudPayloadCodec.decode(chunks.join());
      if (payload is! List) throw const FormatException('Invalid customer list.');
      final result = changeManagedCustomer(payload, original, updated);
      final encoded = CloudPayloadCodec.encode(result);
      const size = 350000;
      final newCount = (encoded.length / size).ceil();
      if (newCount > 100) throw StateError('Customer list is too large to save.');
      if (session.profile?.uid != actor || !canApprove) {
        throw StateError('Account changed. Open the customer list again.');
      }
      for (var i = 0; i < newCount; i++) {
        final end = (i + 1) * size < encoded.length ? (i + 1) * size : encoded.length;
        tx.set(ref.collection('chunks').doc('${revision + 1}_$i'),
            {'payload': encoded.substring(i * size, end)});
      }
      for (var i = 0; i < count; i++) {
        tx.delete(ref.collection('chunks').doc('${revision}_$i'));
      }
      tx.set(ref, {
        'revision': revision + 1, 'chunks': newCount, 'deleted': false,
        'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': actor,
      });
    }, timeout: const Duration(seconds: 15));
  }

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
