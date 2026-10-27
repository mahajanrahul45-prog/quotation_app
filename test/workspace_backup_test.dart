import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/services/workspace_backup.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';

void main() {
  setUp(() {
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'test',
        email: 'master@example.com',
        role: 'master',
        masterUid: 'test',
        enabled: true,
        permissions: {},
      ),
    );
    CloudPreferences.setMockInitialValues({});
  });
  tearDown(() {
    AccountSession.instance.update(null);
    CloudPreferences.clearMock();
  });
  test(
    'Round trip includes maintenance, service records, settings and embedded images',
    () async {
      CloudPreferences.setMockInitialValues({
        'maintenance_quotations': ['{"number":42}'],
        'service_reports': ['{"number":7}'],
        'company_name': 'Example',
        'header_logo_on_left': true,
        'logoPath': 'data:image/png;base64,AQID',
        'reset_pin': '9999',
        'login_password': 'secret',
      });
      final prefs = await CloudPreferences.getInstance();
      final values = WorkspaceBackup.decode(
        WorkspaceBackup.encode(await prefs.exportBackupValues()),
      );
      expect(
        values.keys,
        containsAll([
          'maintenance_quotations',
          'service_reports',
          'company_name',
        ]),
      );
      expect(values.containsKey('reset_pin'), isFalse);
      expect(values.containsKey('login_password'), isFalse);
      expect(values['logoPath']['__cloudFile'], 'AQID');
    },
  );
  test('Damaged archives and unsupported versions are rejected', () {
    final root = jsonDecode(
      WorkspaceBackup.encode({'company_name': 'Original'}),
    );
    root['payload'] = '{"company_name":"changed"}';
    expect(
      () => WorkspaceBackup.decode(jsonEncode(root)),
      throwsFormatException,
    );
    root['version'] = 2;
    expect(
      () => WorkspaceBackup.decode(jsonEncode(root)),
      throwsFormatException,
    );
    expect(() => WorkspaceBackup.decode('{}'), throwsFormatException);
  });
  test(
    'Legacy archives preserve missing sections and validate types',
    () async {
      CloudPreferences.setMockInitialValues({
        'service_reports': ['keep'],
      });
      final root = {
        'models': <String>[],
        'customers': ['customer'],
        'quotations': <String>[],
        'settings': {'company_name': 'Restored'},
      };
      final prefs = await CloudPreferences.getInstance();
      await prefs.restoreBackupValues(WorkspaceBackup.decode(jsonEncode(root)));
      expect(prefs.getStringList('service_reports'), ['keep']);
      expect(prefs.getString('company_name'), 'Restored');
      root['customers'] = [123];
      expect(
        () => WorkspaceBackup.decode(jsonEncode(root)),
        throwsFormatException,
      );
    },
  );
  test('Invalid sections cannot partially overwrite existing data', () async {
    CloudPreferences.setMockInitialValues({'company_name': 'Original'});
    final prefs = await CloudPreferences.getInstance();
    await expectLater(
      prefs.restoreBackupValues({
        'company_name': 'Changed',
        'service_reports': [123],
      }),
      throwsFormatException,
    );
    expect(prefs.getString('company_name'), 'Original');
    await expectLater(
      prefs.restoreBackupValues({'reset_pin': '1234'}),
      throwsFormatException,
    );
  });
  test('Non-master accounts cannot export or restore', () async {
    final prefs = await CloudPreferences.getInstance();
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'test',
        email: 'user@example.com',
        role: 'user',
        masterUid: 'test',
        enabled: true,
        permissions: {'settings': true},
      ),
    );
    await expectLater(prefs.exportBackupValues(), throwsStateError);
    await expectLater(
      prefs.restoreBackupValues({'company_name': 'Changed'}),
      throwsStateError,
    );
  });
}
