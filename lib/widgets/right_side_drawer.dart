import '../auth/account_session.dart';
import '../pages/user_management_page.dart';
import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';
import '../pages/quotations_page.dart';
//import '../pages/add_product_page.dart';
import '../pages/active_inquiries_page.dart';
import '../pages/customers_page.dart';
import '../pages/product_list_page.dart';
import '../pages/page_setup_page.dart';
import '../pages/company_details_page.dart';
import '../pages/settings_page.dart';
import '../pages/maintenance_quotation_page.dart';
import '../pages/service_report_page.dart'; // ✅ ADD THIS

class RightSideDrawer extends StatelessWidget {
  final VoidCallback toggleTheme;
  final VoidCallback onResetApp;
  final VoidCallback onChangePin; // ✅ ADD THIS
  final VoidCallback onBackup;
  final VoidCallback onRestore;

  const RightSideDrawer({
    super.key,
    required this.toggleTheme,
    required this.onResetApp,
    required this.onChangePin, // ✅ ADD
    required this.onBackup,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF16324F)),
            child: Center(
              child: Text(
                'Quotation Workspace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardPage(toggleTheme: toggleTheme),
                ),
              );
            },
          ),

          if (AccountSession.instance.can('quotations'))
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Quotations'),
              onTap: () {
                Navigator.pop(context); // Close the menu before opening the page.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuotationsPage(),
                  ),
                );
              },
            ),

          if (AccountSession.instance.can('maintenance'))
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Maintenance Quotation'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaintenanceQuotationPage(),
                  ),
                );
              },
            ),

          // ----------------------------
          // 🧾 Service Report (NEW)
          // Placed below Maintenance Quotation
          // ----------------------------
          if (AccountSession.instance.can('service'))
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Service Report'),
              onTap: () {
                Navigator.pop(context); // close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceReportPage()),
                );
              },
            ),

          if (AccountSession.instance.can('settings'))
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Company Details'),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompanyDetailsPage()),
                );
              },
            ),

          // <-- MOVED and UPDATED Product List entry: directly below Quotations
          if (AccountSession.instance.can('products'))
            ListTile(
              leading: const Icon(
                Icons.shopping_cart,
              ), // using old 'Products' icon
              title: const Text('Product List'),
              onTap: () {
                Navigator.pop(context); // Close the menu before opening the page.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductListPage(),
                  ),
                );
              },
            ),

          // If you still need an Add Product page, uncomment below or change the title/icon as desired:
          /*
          ListTile(
            leading: const Icon(Icons.add_box),
            title: const Text('Add Product'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AddProductPage()),
              );
            },
          ),
          */
          if (AccountSession.instance.can('quotations'))
            ListTile(
              leading: const Icon(Icons.question_answer),
              title: const Text('Active Inquiry'),
              onTap: () {
                Navigator.pop(context); // Close the menu before opening the page.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveInquiriesPage(),
                  ),
                );
              },
            ),

          // 🌓 Optional: Add a theme toggle option in the drawer
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Toggle Theme'),
            onTap: toggleTheme,
          ),
          if (AccountSession.instance.can('customers'))
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Customers'),
              onTap: () {
                Navigator.pop(context); // Close the menu before opening the page.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomersPage(),
                  ),
                );
              },
            ),
          if (AccountSession.instance.can('settings'))
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      isDarkMode:
                          Theme.of(context).brightness == Brightness.dark,
                      onToggleTheme: toggleTheme,
                      onResetApp: onResetApp,
                      onChangePin: onChangePin,
                      onBackup: onBackup,
                      onRestore: onRestore,
                    ),
                  ),
                );
              },
            ),

          if (AccountSession.instance.profile?.isMaster == true)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Reset PIN'),
              onTap: () {
                Navigator.pop(context); // close drawer
                onChangePin();
              },
            ),

          // Page Setup
          if (AccountSession.instance.can('settings'))
            ListTile(
              title: const Text('Page Setup'),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PageSetupPage(),
                  ),
                );
              },
            ),

          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(AccountSession.instance.profile?.email ?? ''),
            subtitle: Text(
              AccountSession.instance.viewingUser
                  ? 'Viewing: ${AccountSession.instance.viewEmail}'
                  : AccountSession.instance.profile?.isMaster == true
                  ? 'Master administrator'
                  : 'User workspace',
            ),
          ),
          if (AccountSession.instance.profile?.isMaster == true)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Users & permissions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManagementPage()),
                );
              },
            ),
          if (AccountSession.instance.viewingUser)
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Return to master workspace'),
              onTap: () => AccountSession.instance.viewOwn(),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => AccountSession.instance.signOut(),
          ),
          const SizedBox(height: 12), // a little spacing at the bottom
        ],
      ),
    );
  }
}
