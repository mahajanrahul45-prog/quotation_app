import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';
import '../pages/quotations_page.dart';
import '../pages/add_product_page.dart';
import '../pages/active_inquiries_page.dart';
import '../pages/customers_page.dart';
import '../pages/product_list_page.dart';
import '../pages/page_setup_page.dart';




class RightSideDrawer extends StatelessWidget {
  final VoidCallback toggleTheme; // ✅ required parameter

  const RightSideDrawer({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 8,
      backgroundColor: Colors.grey[100],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Center(
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.blue),
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

          ListTile(
            leading: const Icon(Icons.description, color: Colors.green),
            title: const Text('Quotations'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const QuotationsPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.shopping_cart, color: Colors.orange),
            title: const Text('Products'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AddProductPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.question_answer, color: Colors.purple),
            title: const Text('Active Inquiry'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const ActiveInquiriesPage()),
              );
            },
          ),

          // 🌓 Optional: Add a theme toggle option in the drawer
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Colors.black),
            title: const Text('Toggle Theme'),
            onTap: toggleTheme,
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.teal),
            title: const Text('Customers'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CustomersPage()),
    );
  },
),
// Add a “Page Setup” button
ListTile(
  title: const Text('Page Setup'),
  leading: const Icon(Icons.settings),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PageSetupPage()),
    );
  },
),



// inside RightSideDrawer ListView:
ListTile(
  leading: const Icon(Icons.list_alt),
  title: const Text('Product List'),
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ProductListPage()),
    );
  },
),
          
        ],
      ),
    );
  }
}
