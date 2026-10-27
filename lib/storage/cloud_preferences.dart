import 'dart:async';
import 'package:flutter/foundation.dart';
import 'offline_workspace.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart' as local;
import '../auth/access_profile.dart';
import '../auth/account_session.dart';
import 'cloud_payload_codec.dart';

/// Account-scoped local storage with a durable outbox and revision-checked sync.
class CloudPreferences {
  CloudPreferences._(this.uid, this._values, this._revisions);
  final String uid;
  final Map<String, dynamic> _values;
  final Map<String, int> _revisions;
  static final syncStatus = ValueNotifier<String>('');
  static final conflicts = <String, int>{};
  static Timer? _syncTimer;
  static String? _conflictUid;
  static bool _syncing = false;
  static Completer<void>? _syncDone;
  static void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static void startSync() {
    _syncTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(synchronize());
    });
    unawaited(synchronize());
  }

  static bool _connectionError(Object error) =>
      error is TimeoutException ||
      error is FirebaseException &&
          [
            'unavailable',
            'deadline-exceeded',
            'network-request-failed',
          ].contains(error.code);

  static Future<CloudPreferences> _local(String uid) async {
    final store = await OfflineWorkspace.open(uid);
    final values = <String, dynamic>{};
    for (final key in store.values.keys.toList()) {
      if (AccountSession.instance.can(featureForKey(key))) {
        values[key] = await _restore(store.values[key], uid);
      }
    }
    if (AccountSession.instance.profile == null ||
        AccountSession.instance.dataUid != uid) {
      throw StateError('Account changed.');
    }
    return CloudPreferences._(uid, values, Map.of(store.revisions));
  }

  static Future<void> synchronize() async {
    final session = AccountSession.instance;
    if (_syncing) {
      await _syncDone?.future;
      return;
    }
    if (session.profile?.enabled != true) return;
    _syncing = true;
    _syncDone = Completer<void>();
    final uid = session.dataUid;
    final actor = session.profile!.uid;
    if (_conflictUid != uid) {
      conflicts.clear();
      _conflictUid = uid;
    }
    try {
      final store = await OfflineWorkspace.open(uid);
      for (final key in store.pending.keys.toList()) {
        if (session.profile?.uid != actor || session.dataUid != uid) return;
        if (!session.can(featureForKey(key))) continue;
        final entry = Map<String, dynamic>.from(store.pending[key]);
        final expected = (entry['revision'] as num).toInt();
        final encoded = entry['encoded'] as String;
        final deleted = entry['deleted'] == true;
        const size = 350000;
        final count = (encoded.length / size).ceil();
        final ref = _collection(uid, featureForKey(key)).doc(key);
        try {
          await FirebaseFirestore.instance.runTransaction(
            (tx) async {
              final current = await tx.get(ref);
              final actual =
                  (current.data()?['revision'] as num?)?.toInt() ?? 0;
              if (actual != expected) {
                // Recover an upload committed before the local acknowledgement.
                if (actual == expected + 1 &&
                    current.data()?['deleted'] == deleted &&
                    current.data()?['chunks'] == count) {
                  final parts = <String>[];
                  for (var i = 0; i < count; i++) {
                    parts.add(
                      (await tx.get(
                                ref.collection('chunks').doc('${actual}_$i'),
                              )).data()?['payload']
                              as String? ??
                          '',
                    );
                  }
                  if (parts.join() == encoded) return;
                }
                conflicts[key] = actual;
                throw StateError('Sync conflict: $key');
              }
              if (session.profile?.uid != actor ||
                  session.dataUid != uid ||
                  !session.can(featureForKey(key))) {
                throw StateError('Account changed.');
              }
              for (var i = 0; i < count; i++) {
                tx.set(ref.collection('chunks').doc('${expected + 1}_$i'), {
                  'payload': encoded.substring(
                    i * size,
                    min(encoded.length, (i + 1) * size),
                  ),
                });
              }
              final oldCount =
                  (current.data()?['chunks'] as num?)?.toInt() ?? 0;
              for (var i = 0; i < oldCount; i++) {
                tx.delete(ref.collection('chunks').doc('${actual}_$i'));
              }
              tx.set(ref, {
                'revision': expected + 1,
                'chunks': count,
                'deleted': deleted,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': actor,
              });
            },
            timeout: const Duration(seconds: 8),
            maxAttempts: 2,
          );
          await store.mutate(() {
            store.revisions[key] = expected + 1;
            if (_lastObserved[uid]?[key] == expected) {
              _lastObserved[uid]![key] = expected + 1;
            }
            if (store.pending[key]?['token'] == entry['token']) {
              store.pending.remove(key);
            } else if (store.pending[key] != null) {
              store.pending[key]['revision'] = expected + 1;
            }
          });
          conflicts.remove(key);
        } on StateError catch (e) {
          if (!e.message.toString().startsWith('Sync conflict:')) rethrow;
        }
      }
      if (conflicts.isNotEmpty) {
        syncStatus.value =
            'Sync conflict - tap to choose which version to keep';
        return;
      }
      final fresh = await _load(uid).timeout(const Duration(seconds: 5));
      if (session.profile?.uid != actor || session.dataUid != uid) return;
      await store.mutate(() {
        store.downloaded = true;
        for (final feature in featureLabels.keys.where(session.can)) {
          store.values.removeWhere(
            (key, _) =>
                featureForKey(key) == feature &&
                !store.pending.containsKey(key),
          );
          store.revisions.removeWhere(
            (key, _) =>
                featureForKey(key) == feature &&
                !store.pending.containsKey(key),
          );
        }
        for (final key in fresh._values.keys) {
          if (!store.pending.containsKey(key)) {
            store.values[key] = fresh._values[key];
          }
        }
        for (final key in fresh._revisions.keys) {
          if (!store.pending.containsKey(key)) {
            store.revisions[key] = fresh._revisions[key]!;
          }
        }
      });
      syncStatus.value = store.pending.isEmpty
          ? ''
          : 'Changes saved on device - syncing';
    } catch (e) {
      syncStatus.value = _connectionError(e)
          ? 'Offline - changes saved on this device; sync resumes automatically'
          : 'Sync paused: $e';
    } finally {
      _syncing = false;
      _syncDone?.complete();
    }
  }

  static Future<void> resolveConflicts({required bool keepLocal}) async {
    final store = await OfflineWorkspace.open(AccountSession.instance.dataUid);
    await store.mutate(() {
      for (final entry in conflicts.entries) {
        if (keepLocal) {
          store.pending[entry.key]?['revision'] = entry.value;
        } else {
          store.pending.remove(entry.key);
          store.values.remove(entry.key);
        }
      }
    });
    conflicts.clear();
    await synchronize();
  }

  static final _pendingReads = <String, Future<CloudPreferences>>{};
  static final _lastObserved = <String, Map<String, int>>{};
  static Map<String, dynamic>? _testValues;
  static void setMockInitialValues(Map<String, dynamic> values) {
    _testValues = Map.of(values);
  }

  static void clearMock() {
    _testValues = null;
    _lastObserved.clear();
  }

  static Future<void> eraseLegacyCredentials() async {
    final prefs = await local.SharedPreferences.getInstance();
    for (final key in [
      'login_username',
      'login_password',
      'biometric_enabled',
    ]) {
      await prefs.remove(key);
    }
  }

  static Future<CloudPreferences> getInstance() async {
    if (_testValues != null) {
      return CloudPreferences._('test', _testValues!, {});
    }
    final session = AccountSession.instance;
    if (session.profile == null || !session.profile!.enabled) {
      throw StateError('Please sign in to an enabled account.');
    }
    final uid = session.dataUid;
    final pending = _pendingReads[uid];
    if (pending != null) return pending;
    final future = () async {
      final store = await OfflineWorkspace.open(uid);
      if (!store.downloaded && store.pending.isEmpty) {
        await synchronize().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            throw StateError(
              'Workspace download is taking too long. Check your connection and retry.',
            );
          },
        );
        if (syncStatus.value.startsWith('Offline') ||
            syncStatus.value.startsWith('Sync paused')) {
          throw StateError(
            'Connect once to download your workspace before using it offline.',
          );
        }
      } else {
        unawaited(synchronize());
      }
      return _local(uid);
    }();
    _pendingReads[uid] = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingReads[uid], future)) _pendingReads.remove(uid);
    }
  }

  /// Read a service list for a managed user without changing the active workspace.
  static Future<List<String>> readManagedServiceList(
    String uid,
    String key,
  ) async {
    final session = AccountSession.instance;
    final masterUid = session.profile?.uid;
    if (session.profile?.isMaster != true ||
        !session.can('service') ||
        !key.startsWith('service_')) {
      throw StateError('Master service access required.');
    }
    final account = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (account.data()?['masterUid'] != masterUid ||
        account.data()?['role'] != 'user') {
      throw StateError('Access denied');
    }
    final prefs = await _load(
      uid,
      features: ['service'],
      keys: {key},
      requireCurrentScope: false,
    );
    if (session.profile?.uid != masterUid || !session.can('service')) {
      throw StateError('Account changed.');
    }
    return (await _restore(prefs._values[key], uid) as List?)?.cast<String>() ??
        [];
  }

  /// Reads only the two directory lists, never another account's reports.
  static Future<List<String>> readDirectoryList(String uid, String key) async {
    if (key != 'customers' && key != 'service_buildings') {
      throw ArgumentError('Unsupported directory list');
    }
    final session = AccountSession.instance;
    final actor = session.profile?.uid;
    final ref = _collection(uid, featureForKey(key)).doc(key);
    final metadata = await ref.get(const GetOptions(source: Source.server));
    if (!metadata.exists || metadata.data()?['deleted'] == true) return [];
    final revision = metadata.data()!['revision'] as int;
    final count = metadata.data()!['chunks'] as int;
    final parts = await Future.wait(
      List.generate(
        count,
        (i) => ref
            .collection('chunks')
            .doc('${revision}_$i')
            .get(const GetOptions(source: Source.server)),
      ),
    );
    if (parts.any((part) => !part.exists)) {
      throw StateError('Directory changed. Please refresh.');
    }
    if (session.profile?.uid != actor) throw StateError('Account changed.');
    return decodeDirectoryPayload(
      parts.map((p) => p.data()!['payload'] as String).join(),
      uid,
    );
  }

  /// Directory strings use the same portable JSON envelopes as workspace data.
  /// Restore those envelopes before handing records to the directory decoder.
  static Future<List<String>> decodeDirectoryPayload(
    String encoded,
    String uid,
  ) async {
    final restored = await _restore(CloudPayloadCodec.decode(encoded), uid);
    if (restored is! List) {
      throw const FormatException('Invalid directory data');
    }
    return restored
        .map((value) => value is String ? value : jsonEncode(value))
        .toList();
  }

  static Future<CloudPreferences> _load(
    String uid, {
    Iterable<String>? features,
    Set<String>? keys,
    bool requireCurrentScope = true,
  }) async {
    final session = AccountSession.instance;
    final values = <String, dynamic>{};
    final revisions = <String, int>{};
    await Future.wait(
      (features ?? featureLabels.keys.where(session.can)).map((feature) async {
        final docs = await _collection(
          uid,
          feature,
        ).get(const GetOptions(source: Source.server));
        await Future.wait(
          docs.docs.where((doc) => keys == null || keys.contains(doc.id)).map((
            doc,
          ) async {
            var metadata = doc.data();
            for (var attempt = 0; attempt < 3; attempt++) {
              final revision = (metadata['revision'] as num).toInt();
              revisions[doc.id] = revision;
              if (metadata['deleted'] == true) return;
              final count = (metadata['chunks'] as num).toInt();
              final parts = await Future.wait(
                List.generate(
                  count,
                  (i) => doc.reference
                      .collection('chunks')
                      .doc('${revision}_$i')
                      .get(const GetOptions(source: Source.server)),
                ),
              );
              if (parts.any((part) => !part.exists)) {
                metadata = (await doc.reference.get(
                  const GetOptions(source: Source.server),
                )).data()!;
                continue;
              }
              final encoded = parts
                  .map((p) => p.data()!['payload'] as String)
                  .join();
              final decoded = CloudPayloadCodec.decode(encoded);
              values[doc.id] = decoded;
              return;
            }
            throw StateError(
              'Data changed during download. Refresh and try again.',
            );
          }),
        );
      }),
    );
    if (session.profile == null ||
        (requireCurrentScope && session.dataUid != uid)) {
      throw StateError('Account changed. Open the page again.');
    }
    return CloudPreferences._(uid, values, revisions);
  }

  static CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String feature,
  ) => FirebaseFirestore.instance
      .collection('accounts')
      .doc(uid)
      .collection('data')
      .doc(feature)
      .collection('values');
  Set<String> getKeys() => _values.keys.toSet();
  bool containsKey(String key) => _values.containsKey(key);
  dynamic _observe(String key) {
    (_lastObserved[uid] ??= {})[key] = _revisions[key] ?? 0;
    return _values[key];
  }

  Object? get(String key) => _observe(key);
  String? getString(String key) => _observe(key) as String?;
  bool? getBool(String key) => _observe(key) as bool?;
  int? getInt(String key) => (_observe(key) as num?)?.toInt();
  double? getDouble(String key) => (_observe(key) as num?)?.toDouble();
  List<String>? getStringList(String key) =>
      (_observe(key) as List?)?.cast<String>().toList();
  Future<bool> setString(String key, String value) => _write(key, value);
  Future<bool> setStringList(String key, List<String> value) =>
      _write(key, List.of(value));
  Future<bool> setInt(String key, int value) => _write(key, value);
  Future<bool> setDouble(String key, double value) => _write(key, value);
  Future<bool> setBool(String key, bool value) => _write(key, value);
  Future<bool> remove(String key) => _write(key, null);
  Future<void> reload() async {
    final fresh = await getInstance();
    if (fresh.uid != uid) throw StateError('Account changed.');
    _values
      ..clear()
      ..addAll(fresh._values);
    _revisions
      ..clear()
      ..addAll(fresh._revisions);
  }

  Future<bool> clear() async {
    if (_testValues == null &&
        AccountSession.instance.profile?.isMaster != true) {
      throw StateError('Only the master administrator can reset a workspace.');
    }
    for (final key in getKeys()) {
      await remove(key);
    }
    return true;
  }

  Future<bool> _write(String key, dynamic value) async {
    if (_testValues != null) {
      if (value == null) {
        _values.remove(key);
      } else {
        _values[key] = value;
      }
      return true;
    }
    final session = AccountSession.instance;
    final feature = featureForKey(key);
    if (session.profile == null ||
        session.dataUid != uid ||
        !session.can(feature)) {
      throw StateError('You do not have access to this function.');
    }
    if ([
      'login_username',
      'login_password',
      'biometric_enabled',
    ].contains(key)) {
      throw StateError('Local credentials cannot be migrated.');
    }
    final portable = await _portable(value);
    final encoded = value == null ? '' : CloudPayloadCodec.encode(portable);
    const size = 350000;
    final count = (encoded.length / size).ceil();
    if (count > 100) {
      throw StateError(
        'This data exceeds the upload limit. Reduce image sizes and try again.',
      );
    }
    final store = await OfflineWorkspace.open(uid);
    await store.mutate(() {
      final expected =
          store.pending[key]?['revision'] ??
          _lastObserved[uid]?[key] ??
          _revisions[key] ??
          0;
      if (value == null) {
        store.values.remove(key);
      } else {
        store.values[key] = portable;
      }
      store.pending[key] = {
        'revision': expected,
        'encoded': encoded,
        'deleted': value == null,
        'token': DateTime.now().microsecondsSinceEpoch.toString(),
      };
    });
    syncStatus.value = 'Changes saved on device - syncing';
    unawaited(synchronize());
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    return true;
  }

  // Include images/signatures in cloud payloads, then materialize a private
  // account cache on each device so existing Image.file/PDF flows keep working.
  static Future<dynamic> _portable(dynamic value) async {
    if (value is List) return Future.wait(value.map(_portable));
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key.toString()] = await _portable(entry.value);
      }
      return result;
    }
    if (value is String) {
      if (value.startsWith('data:image/')) {
        final uri = UriData.parse(value);
        return {
          '__cloudFile': base64Encode(uri.contentAsBytes()),
          'extension': '.${uri.mimeType.split('/').last}',
        };
      }
      if (!kIsWeb &&
          path.isAbsolute(value) &&
          [
            '.png',
            '.jpg',
            '.jpeg',
            '.webp',
            '.gif',
          ].contains(path.extension(value).toLowerCase())) {
        final file = File(value);
        if (await file.exists()) {
          return {
            '__cloudFile': base64Encode(await file.readAsBytes()),
            'extension': path.extension(value).toLowerCase(),
          };
        }
        throw StateError(
          'An attached image is missing: ${path.basename(value)}. Select it again before saving.',
        );
      }
      try {
        final parsed = jsonDecode(value);
        if (parsed is Map || parsed is List) {
          return {'__cloudJson': await _portable(parsed)};
        }
      } on FormatException {
        /* Ordinary text. */
      }
    }
    return value;
  }

  static Future<dynamic> _restore(dynamic value, String uid) async {
    if (value is List) return Future.wait(value.map((v) => _restore(v, uid)));
    if (value is Map) {
      if (value.containsKey('__cloudFile')) {
        if (kIsWeb) {
          final extension = value['extension'] as String? ?? '.png';
          final mime = extension == '.jpg' || extension == '.jpeg'
              ? 'jpeg'
              : extension.replaceFirst('.', '');
          return 'data:image/$mime;base64,${value['__cloudFile']}';
        }
        final bytes = base64Decode(value['__cloudFile'] as String);
        final base = await getApplicationSupportDirectory();
        final directory = Directory(
          path.join(base.path, 'account_assets', uid),
        );
        await directory.create(recursive: true);
        final extension =
            [
              '.png',
              '.jpg',
              '.jpeg',
              '.webp',
              '.gif',
            ].contains(value['extension'])
            ? value['extension'] as String
            : '.png';
        final file = File(
          path.join(directory.path, '${sha256.convert(bytes)}$extension'),
        );
        if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
      if (value.containsKey('__cloudJson')) {
        return jsonEncode(await _restore(value['__cloudJson'], uid));
      }
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key.toString()] = await _restore(entry.value, uid);
      }
      return result;
    }
    return value;
  }

  /// Portable snapshot includes attached images rather than device-specific paths.
  Future<Map<String, dynamic>> exportBackupValues() async {
    _requireBackupAccess();
    final result = <String, dynamic>{};
    for (final key in getKeys()) {
      if (_backupKeyAllowed(key)) result[key] = await _portable(get(key));
    }
    _requireBackupAccess();
    return result;
  }

  static bool _backupKeyAllowed(String key) =>
      ![
        'login_username',
        'login_password',
        'biometric_enabled',
        'reset_pin',
      ].contains(key) &&
      !key.startsWith('offline_workspace_') &&
      !key.startsWith('offline_profile_');

  void _requireBackupAccess() {
    final session = AccountSession.instance;
    if (session.profile?.isMaster != true ||
        !session.profile!.enabled ||
        session.viewingUser ||
        session.dataUid != uid) {
      throw StateError(
        'Backup and restore are available in the master workspace only.',
      );
    }
  }

  /// Prepare everything before committing one durable local workspace change.
  /// Keys absent from the backup are retained, including for legacy backups.
  Future<void> restoreBackupValues(Map<String, dynamic> values) async {
    _requireBackupAccess();
    final portable = <String, dynamic>{};
    final materialized = <String, dynamic>{};
    final encoded = <String, String>{};
    for (final entry in values.entries) {
      if (!_backupKeyAllowed(entry.key)) {
        throw const FormatException(
          'Backup contains protected device settings.',
        );
      }
      final restored = await _restore(entry.value, uid);
      if (!(restored is String ||
          restored is bool ||
          restored is num ||
          restored is List && restored.every((item) => item is String))) {
        throw FormatException('Unsupported value for ${entry.key}.');
      }
      materialized[entry.key] = restored;
      portable[entry.key] = await _portable(restored);
      encoded[entry.key] = CloudPayloadCodec.encode(portable[entry.key]);
      if (encoded[entry.key]!.length > 35000000) {
        throw FormatException(
          'Backup section ${entry.key} exceeds the upload limit.',
        );
      }
    }
    _requireBackupAccess();
    if (_testValues != null) {
      _values.addAll(materialized);
      return;
    }
    final store = await OfflineWorkspace.open(uid);
    await store.mutate(() {
      _requireBackupAccess();
      for (final key in values.keys) {
        store.values[key] = portable[key];
        store.pending[key] = {
          'revision':
              store.pending[key]?['revision'] ??
              _lastObserved[uid]?[key] ??
              _revisions[key] ??
              0,
          'encoded': encoded[key],
          'deleted': false,
          'token': '${DateTime.now().microsecondsSinceEpoch}_$key',
        };
      }
    });
    _values.addAll(materialized);
    syncStatus.value = 'Restored on this device - syncing';
    unawaited(synchronize());
  }

  /// Explicit, master-only migration. Never automatically assigns shared
  /// device data to whichever user happens to sign in first.
  Future<int> importLegacyData() async {
    final session = AccountSession.instance;
    if (session.profile?.isMaster != true || session.viewingUser) {
      throw StateError('Import is available in the master workspace only.');
    }
    final legacy = await local.SharedPreferences.getInstance();
    var imported = 0;
    for (final key in legacy.getKeys()) {
      if ([
            'login_username',
            'login_password',
            'biometric_enabled',
          ].contains(key) ||
          key.startsWith('offline_workspace_v1_') ||
          key.startsWith('offline_profile_v1_') ||
          _revisions.containsKey(key)) {
        continue;
      }
      await _write(key, legacy.get(key));
      imported++;
    }
    await legacy.remove('login_password');
    await legacy.remove('login_username');
    await legacy.remove('biometric_enabled');
    return imported;
  }
}
