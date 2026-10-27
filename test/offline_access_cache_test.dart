import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/storage/offline_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineWorkspace.resetMemoryForTesting();
  });
  tearDown(() => AccountSession.instance.update(null));

  test(
    'Verified access cache contains metadata only and is account scoped',
    () async {
      await AccountSession.cacheProfile('a', {
        'email': 'a@example.com',
        'role': 'user',
        'masterUid': 'master',
        'enabled': true,
        'permissions': {'service': true},
        'password': 'must not persist',
        'token': 'must not persist',
      });
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString('offline_profile_v1_a')!);
      expect(
        data.keys,
        unorderedEquals([
          'email',
          'role',
          'masterUid',
          'enabled',
          'permissions',
        ]),
      );
      expect(prefs.getString('offline_profile_v1_b'), isNull);
      expect(
        AccessProfile.fromMap(
          'a',
          Map<String, dynamic>.from(data),
        ).can('service'),
        isTrue,
      );
    },
  );

  test('Downloaded workspace opens without a Firebase connection', () async {
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'a',
        email: 'a@example.com',
        role: 'user',
        masterUid: 'master',
        enabled: true,
        permissions: {'service': true},
      ),
    );
    final store = await OfflineWorkspace.open('a');
    await store.mutate(() {
      store.downloaded = true;
      store.values['service_buildings'] = ['Building A'];
      if (kIsWeb) {
        store.values['service_signature'] = {
          '__cloudFile': 'AQID',
          'extension': '.png',
        };
      }
    });
    final prefs = await CloudPreferences.getInstance();
    expect(prefs.getStringList('service_buildings'), ['Building A']);
    if (kIsWeb) {
      expect(
        prefs.getString('service_signature'),
        'data:image/png;base64,AQID',
      );
      await prefs.setString(
        'service_signature',
        prefs.getString('service_signature')!,
      );
      expect(store.values['service_signature']['__cloudFile'], 'AQID');
      expect(store.pending['service_signature'], isNotNull);
    }
  });
}
