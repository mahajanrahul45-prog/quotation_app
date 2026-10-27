import 'package:flutter/material.dart';

class AccessDenied extends StatelessWidget {
  const AccessDenied({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Access restricted')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48),
            SizedBox(height: 16),
            Text(
              'Your master administrator has not granted access to this function.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
