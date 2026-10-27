import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'page_setup_page.dart';

class SettingsPage extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onResetApp;
  final VoidCallback onChangePin;
  final VoidCallback onBackup;
  final VoidCallback onRestore;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onResetApp,
    required this.onChangePin,
    required this.onBackup,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('settings')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 🌙 THEME SWITCH
          SwitchListTile(
            title: const Text("Theme Mode"),
            subtitle: const Text("Light / Dark mode"),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (_) => onToggleTheme(),
            secondary: const Icon(Icons.brightness_6),
          ),

          const Divider(),

          // 📄 PAGE SETUP
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Page Setup"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PageSetupPage()),
              );
            },
          ),

          const Divider(),

          // 🔐 RESET PIN
          if (AccountSession.instance.profile?.isMaster == true)
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text("Set / Change Reset PIN"),
              onTap: onChangePin,
            ),

          const Divider(),

          // 💾 BACKUP
          if (AccountSession.instance.profile?.isMaster == true)
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text("Backup Data"),
              subtitle: const Text(
                "Save workspace records, settings and attached images to a JSON file.",
              ),
              onTap: onBackup,
            ),

          // ♻️ RESTORE
          if (AccountSession.instance.profile?.isMaster == true)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text("Restore Data"),
              subtitle: const Text(
                "Import a backup and review before replacing matching data.",
              ),
              onTap: onRestore,
            ),

          const Divider(),

          // 🚨 RESET APP
          if (AccountSession.instance.profile?.isMaster == true)
            ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.red),
              title: const Text(
                "Reset Application",
                style: TextStyle(color: Colors.red),
              ),
              onTap: onResetApp,
            ),
        ],
      ),
    );
  }
}
