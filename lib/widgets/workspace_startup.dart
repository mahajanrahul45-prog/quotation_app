import 'dart:async';
import 'package:flutter/material.dart';

/// Draws the first frame before plugin initialization and offers bounded retry.
class WorkspaceStartup extends StatefulWidget {
  const WorkspaceStartup({
    super.key,
    required this.initialize,
    required this.child,
    this.timeout = const Duration(seconds: 15),
  });
  final Future<void> Function() initialize;
  final Widget child;
  final Duration timeout;
  @override
  State<WorkspaceStartup> createState() => _WorkspaceStartupState();
}

class _WorkspaceStartupState extends State<WorkspaceStartup> {
  bool _ready = false;
  String? _error;
  Future<void>? _initialization;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() => _error = null);
    final operation = _initialization ??= Future.sync(widget.initialize);
    try {
      await operation.timeout(widget.timeout);
      if (mounted && attempt == _attempt) setState(() => _ready = true);
    } on TimeoutException {
      if (mounted && attempt == _attempt) {
        setState(
          () => _error =
              'Startup is taking longer than expected. Check your connection and try again.',
        );
      }
      // Reuse the same operation on retry; do not initialize plugins twice.
    } catch (e) {
      _initialization = null;
      if (mounted && attempt == _attempt) {
        setState(() => _error = 'Could not start the workspace.\n$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error == null) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Opening workspace...'),
                    ] else ...[
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _start,
                        child: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
}
