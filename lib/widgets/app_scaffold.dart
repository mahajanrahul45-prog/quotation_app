import 'package:flutter/material.dart';

/// Keeps forms and lists readable on desktop while retaining mobile space.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.scaffoldKey,
    this.appBar,
    this.body,
    this.endDrawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: appBar,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : SafeArea(top: false, child: _constrain(bottomNavigationBar!)),
      body: SafeArea(
        top: false,
        child: _constrain(body ?? const SizedBox.shrink()),
      ),
    );
  }

  Widget _constrain(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
