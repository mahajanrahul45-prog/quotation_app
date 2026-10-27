import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_panel.dart';
import 'account_session.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    required this.onThemeToggle,
    required this.isDarkMode,
    this.auth,
    this.verifyAccount,
  });
  final Future<void> Function(User) onLoginSuccess;
  final VoidCallback onThemeToggle;
  final FirebaseAuth? auth;
  final Future<void> Function(User)? verifyAccount;
  final bool isDarkMode;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;
  String _progress = 'Signing in...';
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 'Signing in...';
    });
    AccountSession.authenticating = true;
    try {
      final credential = await _auth
          .signInWithEmailAndPassword(
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 15));
      final user = credential.user;
      if (user == null) {
        throw StateError('Sign-in did not return an account. Try again.');
      }
      if (!mounted) return;
      setState(() => _progress = 'Checking account access...');
      await (widget.verifyAccount?.call(user) ??
              AccountSession.acceptInvitation(signedInUser: user))
          .timeout(const Duration(seconds: 15));
      AccountSession.authenticating = false;
      if (!mounted) return;
      setState(() => _progress = 'Opening workspace...');
      await widget.onLoginSuccess(user);
    } catch (e) {
      try {
        await _auth.signOut().timeout(const Duration(seconds: 4));
      } catch (cleanupError) {
        debugPrint('Sign-in cleanup: $cleanupError');
      }
      if (mounted) setState(() => _error = authError(e));
    } finally {
      AccountSession.authenticating = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above to reset your password.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If this account exists, a password reset email has been sent.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthPanel(
      title: 'Welcome back',
      subtitle: 'Sign in once online. Keep working offline on this device.',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter email'
                  : !v.contains('@')
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!_busy) _login();
              },
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: 'Show or hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter password' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _login,
                child: Text(_busy ? _progress : 'Login'),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    ),
              child: const Text('Activate invited user account'),
            ),
            const Text(
              'Your master administrator controls your access. Each user has a private workspace.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

String authError(Object error) {
  if (error is TimeoutException) {
    return 'Sign-in is taking too long. Check your internet connection and try again.';
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email already has an account. Sign in or reset your password.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-disabled':
        return 'This account is disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Cannot connect. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in must be enabled in Firebase.';
      case 'configuration-not-found':
        return 'Firebase Authentication is not configured for this app. '
            'The administrator must enable Authentication in elevatorquotationapp. '
            'Then fully close and reopen the updated app.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'Firebase rejected this app configuration. Contact the '
            'administrator to check the API key and registered app.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      default:
        return error.message ?? 'Sign-in failed. Please try again.';
    }
  }
  return error.toString().replaceFirst('Bad state: ', '');
}
