import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/access_profile.dart';
import '../auth/account_session.dart';
import '../storage/cloud_preferences.dart';
import '../widgets/app_scaffold.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});
  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  bool _busy = false;
  String? _message;
  Future<void> _edit({
    AccessProfile? user,
    String? inviteEmail,
    Map<String, dynamic>? invitation,
  }) async {
    final email = TextEditingController(text: user?.email ?? inviteEmail ?? '');
    final permissions = <String, bool>{
      for (final key in featureLabels.keys)
        key: user?.permissions[key] ?? invitation?['permissions']?[key] == true,
    };
    var enabled =
        user?.enabled ?? (invitation == null || invitation['enabled'] == true);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(user == null ? 'Invite user' : 'User access'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: email,
                    enabled: user == null && inviteEmail == null,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'User email'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account enabled'),
                    value: enabled,
                    onChanged: (v) => update(() => enabled = v),
                  ),
                  const Text(
                    'Grant access to the functions this user needs. Their records stay in their own workspace.',
                  ),
                  for (final entry in featureLabels.entries)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: permissions[entry.key],
                      onChanged: (v) =>
                          update(() => permissions[entry.key] = v ?? false),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (email.text.trim().contains('@')) Navigator.pop(ctx, true);
              },
              child: const Text('Save access'),
            ),
          ],
        ),
      ),
    );
    final address = email.text.trim().toLowerCase();
    email.dispose();
    if (result != true) return;
    await _run(() async {
      final db = FirebaseFirestore.instance;
      final master = AccountSession.instance.profile!;
      if (user == null) {
        await db.collection('invitations').doc(address).set({
          'email': address,
          'masterUid': master.uid,
          'permissions': permissions,
          'enabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await db.collection('accounts').doc(user.uid).update({
          'permissions': permissions,
          'enabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return user == null
          ? 'Invitation saved. Ask the user to activate this email in the app.'
          : 'User access updated.';
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import existing device data?'),
        content: const Text(
          'This uploads the old quotations, customers, products and settings to your master workspace. Existing online collections are kept. Run this on the device holding your old data. Local source records are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () async =>
            'Imported ${await (await CloudPreferences.getInstance()).importLegacyData()} data collections/settings.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = AccountSession.instance.profile;
    if (master?.isMaster != true) {
      return const Scaffold(
        body: Center(child: Text('Master access required.')),
      );
    }
    final db = FirebaseFirestore.instance;
    return AppScaffold(
      appBar: AppBar(title: const Text('Users & permissions')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Master administrator',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(master!.email),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.person_add),
                label: const Text('Invite user'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || AccountSession.instance.viewingUser
                    ? null
                    : _import,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Import old device data'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!),
            ),
          const SizedBox(height: 24),
          Text(
            'User workspaces',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('accounts')
                .where('masterUid', isEqualTo: master.uid)
                .where('role', isEqualTo: 'user')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Cannot load users: ${snapshot.error}');
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No activated users yet. Invite a user to get started.',
                  ),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final user = AccessProfile.fromMap(doc.id, doc.data());
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(user.enabled ? 'Enabled' : 'Disabled'),
                          Text(
                            featureLabels.entries
                                .where((e) => user.permissions[e.key] == true)
                                .map((e) => e.value)
                                .join(', '),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _edit(user: user),
                                icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                                label: const Text('Manage access'),
                              ),
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => AccountSession.instance.viewUser(
                                        user,
                                      ),
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Open user data'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Invitations', style: Theme.of(context).textTheme.titleLarge),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('invitations')
                .where('masterUid', isEqualTo: master.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Cannot load invitations: ${snapshot.error}');
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Column(
                children: snapshot.data!.docs
                    .map(
                      (doc) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(doc.id),
                        subtitle: Text(
                          doc.data()['enabled'] == true
                              ? 'Invitation enabled'
                              : 'Invitation disabled',
                        ),
                        trailing: IconButton(
                          tooltip: 'Edit invitation',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: _busy
                              ? null
                              : () => _edit(
                                  inviteEmail: doc.id,
                                  invitation: doc.data(),
                                ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
