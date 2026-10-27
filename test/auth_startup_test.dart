import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';

class SignedInUser implements User {
  @override
  String get uid => 'signed-in-user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SignedInCredential implements UserCredential {
  SignedInCredential(this.user);
  @override
  final User user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DelayedAuth extends SilentAuth {
  final user = SignedInUser();
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    changes.add(user);
    // The credential is available before the separate currentUser lookup.
    return SignedInCredential(user);
  }
}

class SilentFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      SilentCollection();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test doubles expose just the account listener, without a live Firebase backend.
// ignore: subtype_of_sealed_class
class SilentCollection implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      SilentDocument();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class SilentDocument implements DocumentReference<Map<String, dynamic>> {
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SilentAuth implements FirebaseAuth {
  final changes = StreamController<User?>();
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Successful login opens workspace when auth event arrives during verification and currentUser is delayed',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CloudPreferences.setMockInitialValues({});
      final auth = DelayedAuth();
      addTearDown(() async {
        AccountSession.authenticating = false;
        AccountSession.instance.update(null);
        CloudPreferences.clearMock();
        await auth.changes.close();
      });
      String? verifiedUid;
      await tester.pumpWidget(
        MyApp(
          auth: auth,
          firestore: SilentFirestore(),
          verifyAccount: (user) async {
            verifiedUid = user.uid;
            await AccountSession.cacheProfile(user.uid, {
              'email': 'user@example.com',
              'role': 'user',
              'masterUid': 'master',
              'enabled': true,
              'permissions': <String, bool>{},
            });
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(verifiedUid, auth.user.uid);
      expect(auth.currentUser, isNull);
      expect(AccountSession.instance.profile?.uid, auth.user.uid);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Business overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Sign-in opens even when auth never emits its initial event', (
    tester,
  ) async {
    final auth = SilentAuth();
    addTearDown(() => auth.changes.close());
    await tester.pumpWidget(MyApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // A delayed initial null event must not reset the login form.
    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    auth.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('user@example.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
