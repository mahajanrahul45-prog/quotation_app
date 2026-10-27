import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/storage/customer_directory.dart';
import 'package:elevator_quotation_app/storage/cloud_payload_codec.dart';
import 'package:elevator_quotation_app/storage/service_buildings.dart';

void main() {
  test(
    'Remote directory restores portable JSON envelopes before converting to strings',
    () async {
      final payload = CloudPayloadCodec.encode([
        {
          '__cloudJson': {'customerName': 'Cloud Tower', 'area': 'Mumbai'},
        },
        jsonEncode({'customerName': 'Legacy Tower'}),
        {'customerName': 'Map Tower'},
      ]);
      final strings = await CloudPreferences.decodeDirectoryPayload(
        payload,
        'test',
      );
      final records = ServiceBuildings.decode(strings);
      expect(records.map((r) => r['customerName']), [
        'Cloud Tower',
        'Legacy Tower',
        'Map Tower',
      ]);
      expect(records.first['area'], 'Mumbai');
    },
  );
  setUp(() {
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'alice',
        email: 'alice@example.com',
        role: 'user',
        masterUid: 'master',
        enabled: true,
        permissions: {'quotations': true},
      ),
    );
  });
  tearDown(() {
    CloudPreferences.clearMock();
    AccountSession.instance.update(null);
  });

  test(
    'Common directory merges customers and buildings without rewriting either source',
    () async {
      final customers = [
        jsonEncode({'customerName': 'Sunrise Tower', 'phone': '123'}),
      ];
      final buildings = [
        jsonEncode({'customerName': '  sunrise  tower ', 'area': 'Mumbai'}),
        jsonEncode({'customerName': 'New Building', 'area': 'Pune'}),
      ];
      CloudPreferences.setMockInitialValues({
        'customers': customers,
        'service_buildings': buildings,
      });
      final result = await CustomerDirectory.load();
      expect(result.map((r) => r['customerName']), [
        'Sunrise Tower',
        'New Building',
      ]);
      expect(result.first['phone'], '123');
      expect(result.last['email'], '');
      expect(result.last['_ownerEmail'], 'alice@example.com');
      final prefs = await CloudPreferences.getInstance();
      expect(prefs.getStringList('customers'), customers);
      expect(prefs.getStringList('service_buildings'), buildings);
      expect(await CustomerDirectory.load(deduplicate: false), hasLength(3));
    },
  );

  test(
    'Creator labels come from the source account; foreign and shared records cannot be edited',
    () {
      final record = CustomerDirectory.attributed(
        {
          'customerName': 'Tower',
          'createdByEmail': 'spoofed@example.com',
          '_ownerUid': 'master',
        },
        'alice',
        'alice@example.com',
        'customers',
      );
      expect(record['_ownerEmail'], 'alice@example.com');
      expect(CustomerDirectory.ownsCustomer(record), isTrue);
      expect(
        CustomerDirectory.ownsCustomer({...record, '_shared': true}),
        isFalse,
      );
      expect(
        CustomerDirectory.ownsCustomer({...record, '_ownerUid': 'bob'}),
        isFalse,
      );
      expect(CustomerDirectory.canApprove, isFalse);
    },
  );

  test(
    'Stable customer identifier keeps approvals addressable after rename',
    () {
      final record = CustomerDirectory.attributed(
        {'customerName': 'Old Tower'},
        'master',
        'master@example.com',
        'customers',
      );
      expect(
        CustomerDirectory.shareId({...record, 'customerName': 'New Tower'}),
        CustomerDirectory.shareId(record),
      );
    },
  );

  test('Master can manage user customer records but not shared or building records', () {
    AccountSession.instance.update(const AccessProfile(
      uid: 'master', email: 'master@example.com', role: 'master',
      masterUid: '', enabled: true, permissions: {},
    ));
    final record = CustomerDirectory.attributed(
      {'customerName': 'Tower'}, 'alice', 'alice@example.com', 'customers');
    expect(CustomerDirectory.canManageCustomer(record), isTrue);
    expect(CustomerDirectory.canManageCustomer({...record, '_shared': true}), isFalse);
    expect(CustomerDirectory.canManageCustomer({...record, '_serviceBuilding': true}), isFalse);
  });

  test('User cannot manage another user customer', () {
    final foreign = CustomerDirectory.attributed(
      {'customerName': 'Tower'}, 'bob', 'bob@example.com', 'customers');
    expect(CustomerDirectory.canManageCustomer(foreign), isFalse);
  });

  test('Managed edit preserves ownership fields and unrelated records; delete targets one record', () {
    final raw = {'customerName': 'Old Tower', 'phone': '123', 'createdByUid': 'alice', 'custom': 'keep'};
    final original = CustomerDirectory.attributed(raw, 'alice', 'alice@example.com', 'customers');
    final other = {'customerName': 'Other'};
    final values = <dynamic>[{'__cloudJson': raw}, {'__cloudJson': other}];
    final edited = CustomerDirectory.changeManagedCustomer(values, original,
      {...original, 'customerName': 'New Tower'});
    final record = (edited.first as Map)['__cloudJson'] as Map;
    expect(record['customerName'], 'New Tower');
    expect(record['createdByUid'], 'alice');
    expect(record['custom'], 'keep');
    expect(record['directoryId'], original['directoryId']);
    expect(edited.last, values.last);
    expect(CustomerDirectory.changeManagedCustomer(values, original, null), [values.last]);
    expect(values, hasLength(2));
  });

  test('Managed changes reject stale or ambiguous customers', () {
    final original = CustomerDirectory.attributed(
      {'customerName': 'Tower', 'phone': '123'}, 'alice', 'alice@example.com', 'customers');
    expect(() => CustomerDirectory.changeManagedCustomer(
      [jsonEncode({'customerName': 'Tower', 'phone': '456'})], original, null), throwsStateError);
    expect(() => CustomerDirectory.changeManagedCustomer(
      [jsonEncode({'customerName': 'Tower', 'phone': '123'}),
       jsonEncode({'customerName': 'Tower', 'phone': '123'})], original, null), throwsStateError);
  });

}
