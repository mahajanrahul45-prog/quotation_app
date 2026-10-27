import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'access_profile.dart';

class AccountSession extends ChangeNotifier {
  AccountSession._();
  static final instance = AccountSession._();
  static bool authenticating = false;
  AccessProfile? profile;
  String? _viewUid;
  String? viewEmail;
  String get dataUid => _viewUid ?? profile!.uid;
  bool get viewingUser => _viewUid != null;
  bool can(String feature) => profile?.can(feature) ?? false;
  void update(AccessProfile? value) {
    profile = value;
    _viewUid = null;
    viewEmail = null;
    notifyListeners();
  }

  Future<void> viewUser(AccessProfile user) async {
    if (profile?.isMaster != true ||
        user.masterUid != profile!.uid ||
        user.isMaster) {
      throw StateError('Access denied');
    }
    _viewUid = user.uid;
    viewEmail = user.email;
    notifyListeners();
  }

  void viewOwn() {
    _viewUid = null;
    viewEmail = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    update(null);
    await FirebaseAuth.instance.signOut();
  }

  static Future<void> acceptInvitation({User? signedInUser}) async {
    final user = signedInUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign-in did not return an account. Try again.');
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('offline_profile_v1_${user.uid}');
    if (cached != null) {
      try {
        AccessProfile.fromMap(
          user.uid,
          Map<String, dynamic>.from(jsonDecode(cached)),
        );
        // Existing accounts open locally; MyApp's live profile listener
        // verifies permissions and account status in the background.
        return;
      } catch (_) {
        await prefs.remove('offline_profile_v1_${user.uid}');
      }
    }
    final db = FirebaseFirestore.instance;
    final ref = db.collection('accounts').doc(user.uid);
    final email = user.email!.toLowerCase();
    final account = await ref
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    if (account.exists) {
      await cacheProfile(user.uid, account.data()!);
      return;
    }
    if (!user.emailVerified) {
      await user.sendEmailVerification();
      throw StateError(
        'Verify your email using the link sent to your inbox, then sign in again.',
      );
    }
    await db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return;
      final invite = await tx.get(db.collection('invitations').doc(email));
      if (!invite.exists || invite.data()!['enabled'] != true) {
        throw StateError(
          'Ask your master administrator to invite this email first.',
        );
      }
      tx.set(ref, {
        'email': email,
        'role': 'user',
        'masterUid': invite.data()!['masterUid'],
        'enabled': true,
        'permissions': invite.data()!['permissions'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    final activated = await ref.get(const GetOptions(source: Source.server));
    await cacheProfile(user.uid, activated.data()!);
  }

  /// Store only access metadata; passwords and tokens remain with Firebase Auth.
  static Future<void> cacheProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline_profile_v1_$uid',
      jsonEncode({
        for (final key in [
          'email',
          'role',
          'masterUid',
          'enabled',
          'permissions',
        ])
          key: data[key],
      }),
    );
  }
}
