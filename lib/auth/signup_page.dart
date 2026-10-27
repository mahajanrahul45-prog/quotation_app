import 'account_session.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_panel.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    AccountSession.authenticating = true;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check your inbox to verify your email, then sign in to activate your invited account.',
            ),
          ),
        );
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _error = authError(e));
    } finally {
      AccountSession.authenticating = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activate account')),
    body: AuthPanel(
      title: 'Join your workspace',
      subtitle: 'Use the email your master administrator invited.',
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => v == null || v.length < 8
                  ? 'Use at least 8 characters'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _activate,
              child: Text(_busy ? 'Please wait...' : 'Activate account'),
            ),
          ],
        ),
      ),
    ),
  );
}
