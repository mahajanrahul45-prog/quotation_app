import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elevator_quotation_app/storage/offline_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineWorkspace.resetMemoryForTesting();
  });
  test(
    'Offline edits and deletions survive a restart without crossing accounts',
    () async {
      final a = await OfflineWorkspace.open('a');
      await a.mutate(() {
        a.values['customers'] = ['customer'];
        a.revisions['customers'] = 4;
        a.pending['customers'] = {
          'revision': 4,
          'encoded': 'payload',
          'deleted': false,
        };
        a.pending['service_deleted'] = {
          'revision': 2,
          'encoded': '',
          'deleted': true,
        };
      });
      OfflineWorkspace.resetMemoryForTesting();
      final restored = await OfflineWorkspace.open('a');
      expect(restored.values['customers'], ['customer']);
      expect(restored.revisions['customers'], 4);
      expect(restored.pending['customers']['encoded'], 'payload');
      expect(restored.pending['service_deleted']['deleted'], true);
      final b = await OfflineWorkspace.open('b');
      expect(b.values, isEmpty);
      expect(b.pending, isEmpty);
    },
  );
  test('Concurrent saves retain both changes in persisted storage', () async {
    final store = await OfflineWorkspace.open('a');
    await Future.wait([
      store.mutate(() => store.values['first'] = 1),
      store.mutate(() => store.values['second'] = 2),
    ]);
    OfflineWorkspace.resetMemoryForTesting();
    expect((await OfflineWorkspace.open('a')).values, {
      'first': 1,
      'second': 2,
    });
  });
}
