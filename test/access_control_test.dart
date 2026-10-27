import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/widgets/right_side_drawer.dart';

void main() {
  tearDown(() => AccountSession.instance.update(null));
  const user = AccessProfile(
    uid: 'user-a',
    email: 'user@example.com',
    role: 'user',
    masterUid: 'master',
    enabled: true,
    permissions: {'quotations': true},
  );
  test('Users receive only explicit grants; disabled master has no access', () {
    expect(user.can('quotations'), isTrue);
    expect(user.can('settings'), isFalse);
    expect(user.can('unknown'), isFalse);
    const master = AccessProfile(
      uid: 'master',
      email: 'master@example.com',
      role: 'master',
      masterUid: 'master',
      enabled: false,
      permissions: {},
    );
    expect(master.can('quotations'), isFalse);
  });
  test('User cannot switch to the master or another user workspace', () async {
    final session = AccountSession.instance;
    session.update(user);
    expect(session.dataUid, 'user-a');
    await expectLater(session.viewUser(user), throwsStateError);
    expect(session.dataUid, 'user-a');
  });
  test(
    'Master can inspect own users but cannot switch into another master',
    () async {
      final session = AccountSession.instance;
      const master = AccessProfile(
        uid: 'master',
        email: 'master@example.com',
        role: 'master',
        masterUid: 'master',
        enabled: true,
        permissions: {},
      );
      session.update(master);
      await session.viewUser(user);
      expect(session.dataUid, 'user-a');
      expect(session.viewingUser, isTrue);
      session.viewOwn();
      expect(session.dataUid, 'master');
      await expectLater(session.viewUser(master), throwsStateError);
    },
  );
  testWidgets('Navigation hides every function not granted to a user', (
    tester,
  ) async {
    AccountSession.instance.update(user);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RightSideDrawer(
            toggleTheme: () {},
            onResetApp: () {},
            onChangePin: () {},
            onBackup: () {},
            onRestore: () {},
          ),
        ),
      ),
    );
    expect(find.text('Quotations'), findsOneWidget);
    expect(find.text('Product List'), findsNothing);
    expect(find.text('Customers'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Users & permissions'), findsNothing);
    expect(find.text('Change Reset PIN'), findsNothing);
  });
}
