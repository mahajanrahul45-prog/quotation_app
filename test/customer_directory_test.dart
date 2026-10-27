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
}
