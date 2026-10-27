import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/widgets/workspace_startup.dart';

void main() {
  testWidgets(
    'A hung startup stops spinning and retry reuses the pending operation',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        WorkspaceStartup(
          initialize: () {
            calls++;
            return pending.future;
          },
          timeout: const Duration(seconds: 2),
          child: const MaterialApp(home: Text('Workspace ready')),
        ),
      );
      expect(find.text('Opening workspace...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Workspace ready'), findsOneWidget);
    },
  );
  testWidgets('A failed initialization can be retried successfully', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      WorkspaceStartup(
        initialize: () async {
          if (++calls == 1) throw StateError('Plugin unavailable');
        },
        child: const MaterialApp(home: Text('Workspace ready')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Plugin unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Workspace ready'), findsOneWidget);
  });
}
