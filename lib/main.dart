import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
   const MyApp({super.key}); // ✅ Clean, modern, warning-free
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quotation App',
      theme: isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: DashboardPage(
        toggleTheme: () {
          setState(() => isDarkMode = !isDarkMode);
        },
      ),
    );
  }
}
