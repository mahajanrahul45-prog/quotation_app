import 'widgets/workspace_startup.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/expiry_notification_service.dart';
import 'storage/cloud_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'auth/access_profile.dart';
import 'auth/account_session.dart';
import 'auth/login_page.dart';
import 'pages/dashboard_page.dart';
import 'utils/app_theme.dart';

final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        WorkspaceStartup(
          initialize: () async {
            if (Firebase.apps.isEmpty) {
              await Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              );
            }
            if (kIsWeb) {
              await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
            }
            FirebaseFirestore.instance.settings = const Settings(
              persistenceEnabled: true,
            );
            // Credential cleanup must not delay opening the workspace.
            unawaited(
              CloudPreferences.eraseLegacyCredentials().catchError((Object e) {
                debugPrint('Credential cleanup: $e');
              }),
            );
          },
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Could not complete the action. Check your connection and reopen the page.\n$error',
          ),
        ),
      );
      debugPrint('Workspace error: $error');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.auth, this.firestore, this.verifyAccount});
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final Future<void> Function(User)? verifyAccount;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _dark = false, _loading = true;
  String? _error;
  String? _authUid;
  String? _profileFingerprint;
  String? _notificationsUid;
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  final session = AccountSession.instance;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _sessionAttempt = 0;
  bool _authResolved = false;
  FirebaseAuth get _firebaseAuth => widget.auth ?? FirebaseAuth.instance;
  Timer? _accessTimeout;
  @override
  void initState() {
    super.initState();
    session.addListener(_sessionChanged);
    _armAccessTimeout();
    _auth = _firebaseAuth.authStateChanges().listen(
      _handleUserChanged,
      onError: (Object e) =>
          _accessFailed('Could not restore your sign-in. $e'),
    );
    // Firebase initialization has already restored auth persistence. Do not
    // depend on the stream delivering its initial event to open the first page.
    unawaited(_handleUserChanged(_firebaseAuth.currentUser));
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload preserves State, including a loading state created before
    // the startup watchdog was installed.
    if (_loading) _armAccessTimeout();
  }

  void _sessionChanged() {
    if (mounted) {
      setState(() => _navigatorKey = GlobalKey<NavigatorState>());
    }
  }

  void _accessFailed(String message) {
    _accessTimeout?.cancel();
    if (mounted) {
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  void _armAccessTimeout() {
    _accessTimeout?.cancel();
    _accessTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _loading) {
        _accessFailed(
          'Could not verify your account in time. Check your connection and tap Try again.',
        );
      }
    });
  }

  Future<void> _handleUserChanged(User? user, {bool force = false}) async {
    try {
      await _userChanged(user, force: force);
    } catch (e) {
      _accessFailed('Could not open your account. $e');
    }
  }

  Future<void> _userChanged(User? user, {bool force = false}) async {
    if (AccountSession.authenticating) return;
    if (!force && _authResolved && _authUid == user?.uid) return;
    _authResolved = true;
    final attempt = ++_sessionAttempt;
    _armAccessTimeout();
    _authUid = user?.uid;
    CloudPreferences.stopSync();
    _profileFingerprint = null;
    _notificationsUid = null;
    unawaited(
      ExpiryNotificationService.deactivate().catchError((Object e) {
        debugPrint('Reminder cleanup: $e');
      }),
    );
    final previousProfile = _profile;
    _profile = null;
    if (previousProfile != null) unawaited(previousProfile.cancel());
    session.update(null);
    if (!mounted) return;
    setState(() {
      _loading = user != null;
      _error = null;
    });
    if (user == null) {
      _accessTimeout?.cancel();
      return;
    }
    CloudPreferences.conflicts.clear();
    final localPrefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 4),
    );
    final cachedProfile = localPrefs.getString(
      'offline_profile_v1_${user.uid}',
    );
    if (!mounted || _authUid != user.uid || attempt != _sessionAttempt) {
      return;
    }
    if (cachedProfile != null) {
      try {
        session.update(
          AccessProfile.fromMap(
            user.uid,
            Map<String, dynamic>.from(jsonDecode(cachedProfile)),
          ),
        );
        _accessTimeout?.cancel();
        setState(() => _loading = false);
        CloudPreferences.startSync();
      } catch (e) {
        debugPrint('Ignoring invalid cached access profile: $e');
        unawaited(localPrefs.remove('offline_profile_v1_${user.uid}'));
      }
    }
    // Account provisioning happens during activation/login. Existing sessions
    // use only their server-controlled access profile.
    _profile = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('accounts')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (doc) {
            try {
              if (!mounted ||
                  _authUid != user.uid ||
                  attempt != _sessionAttempt) {
                return;
              }
              final data = doc.data();
              if (doc.metadata.isFromCache && data == null) {
                // Keep waiting for the first server response within the startup deadline.
                return;
              }
              _accessTimeout?.cancel();
              if (data == null) {
                unawaited(localPrefs.remove('offline_profile_v1_${user.uid}'));
                if (!mounted ||
                    _authUid != user.uid ||
                    attempt != _sessionAttempt) {
                  return;
                }
                session.update(null);
                _profileFingerprint = null;
                setState(() {
                  _loading = false;
                  _error = data == null
                      ? 'Your account has not been activated. Ask the master administrator to invite your email, then sign in again.'
                      : 'Connect to the internet to verify account access.';
                });
                return;
              }
              unawaited(
                localPrefs
                    .setString(
                      'offline_profile_v1_${user.uid}',
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
                    )
                    .then<void>((_) {})
                    .catchError((Object e) {
                      debugPrint('Access cache: $e');
                    }),
              );
              if (!mounted ||
                  _authUid != user.uid ||
                  attempt != _sessionAttempt) {
                return;
              }
              final fingerprint =
                  '${doc.id}:${data['role']}:${data['masterUid']}:${data['enabled']}:${jsonEncode(data['permissions'])}';
              if (_profileFingerprint != fingerprint ||
                  session.profile == null) {
                _profileFingerprint = fingerprint;
                session.update(AccessProfile.fromMap(doc.id, data));
              }
              CloudPreferences.startSync();
              if (session.can('maintenance') && _notificationsUid != user.uid) {
                _notificationsUid = user.uid;
                unawaited(
                  ExpiryNotificationService.initialize().catchError((Object e) {
                    debugPrint('Reminder setup: $e');
                  }),
                );
              } else if (!session.can('maintenance') &&
                  _notificationsUid != null) {
                _notificationsUid = null;
                unawaited(
                  ExpiryNotificationService.deactivate().catchError((Object e) {
                    debugPrint('Reminder cleanup: $e');
                  }),
                );
              }
              setState(() {
                _loading = false;
                _error = null;
              });
            } catch (e) {
              if (mounted && attempt == _sessionAttempt) {
                _accessFailed('Could not read your account profile. $e');
              }
            }
          },
          onError: (Object e) {
            if (_authUid != user.uid || attempt != _sessionAttempt) return;
            if (e is FirebaseException &&
                ['unavailable', 'deadline-exceeded'].contains(e.code) &&
                session.profile != null) {
              CloudPreferences.syncStatus.value =
                  'Offline - changes saved on this device';
              return;
            }
            unawaited(localPrefs.remove('offline_profile_v1_${user.uid}'));
            session.update(null);
            _profileFingerprint = null;
            if (mounted && _authUid == user.uid) {
              setState(() {
                _loading = false;
                _error =
                    'Cannot verify account access. Check your connection. $e';
              });
            }
          },
        );
  }

  @override
  void dispose() {
    CloudPreferences.stopSync();
    _accessTimeout?.cancel();
    _auth?.cancel();
    _profile?.cancel();
    session.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_loading) {
      home = Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _authUid == null
                    ? 'Restoring sign-in...'
                    : 'Checking account access...',
              ),
            ],
          ),
        ),
      );
    } else if (_error != null ||
        session.profile != null && !session.profile!.enabled) {
      home = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ??
                      'Your account is disabled. Contact your master administrator.',
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  FilledButton(
                    onPressed: () {
                      _authResolved = false;
                      unawaited(_handleUserChanged(_firebaseAuth.currentUser));
                    },
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: () => session.signOut(),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (session.profile != null) {
      home = DashboardPage(toggleTheme: () => setState(() => _dark = !_dark));
    } else {
      home = LoginPage(
        auth: _firebaseAuth,
        verifyAccount: widget.verifyAccount,
        onLoginSuccess: (user) => _handleUserChanged(user, force: true),
        onThemeToggle: () => setState(() => _dark = !_dark),
        isDarkMode: _dark,
      );
    }
    return MaterialApp(
      scaffoldMessengerKey: appMessengerKey,
      navigatorKey: _navigatorKey,
      title: 'Quotation Workspace',
      debugShowCheckedModeBanner: false,
      theme: _dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => Column(
        children: [
          if (session.profile?.enabled == true)
            ValueListenableBuilder<String>(
              valueListenable: CloudPreferences.syncStatus,
              builder: (context, status, _) => status.isEmpty
                  ? const SizedBox.shrink()
                  : Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: SafeArea(
                        bottom: false,
                        child: InkWell(
                          onTap: () async {
                            if (CloudPreferences.conflicts.isEmpty) {
                              await CloudPreferences.synchronize();
                              return;
                            }
                            final keep = await showDialog<bool>(
                              context: _navigatorKey
                                  .currentState!
                                  .overlay!
                                  .context,
                              builder: (context) => AlertDialog(
                                title: const Text('Resolve sync conflict'),
                                content: Text(
                                  'Changed on another device: ${CloudPreferences.conflicts.keys.join(', ')}. Keeping this device replaces the online version. Keeping online discards the conflicting local changes.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Keep online'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Keep this device'),
                                  ),
                                ],
                              ),
                            );
                            if (keep != null) {
                              await CloudPreferences.resolveConflicts(
                                keepLocal: keep,
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_sync, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(status)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: home,
    );
  }
}
