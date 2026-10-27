import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/storage/service_buildings.dart';
import 'package:elevator_quotation_app/storage/customer_directory.dart';
import 'package:elevator_quotation_app/pages/service_report_page.dart';

void main() {
  tearDown(() {
    AccountSession.instance.update(null);
    CloudPreferences.clearMock();
  });
  test(
    'Master display keeps existing customer and collapses matching building names',
    () {
      final customer = {'customerName': 'Sunrise Tower', 'phone': '123'};
      final result = uniqueBuildings([
        customer,
        {'customerName': '  SUNRISE   tower ', '_serviceBuilding': true},
        {'customerName': 'Other Tower', '_serviceBuilding': true},
      ]);
      expect(result, hasLength(2));
      expect(result.first, same(customer));
      expect(customer['phone'], '123');
      expect(featureForKey(ServiceBuildings.storageKey), 'service');
    },
  );
  testWidgets('Service user sees own common directory and adds a building', (
    tester,
  ) async {
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'user-a',
        email: 'user@example.com',
        role: 'user',
        masterUid: 'master',
        enabled: true,
        permissions: {'service': true},
      ),
    );
    CloudPreferences.setMockInitialValues({
      'customers': [
        jsonEncode({'customerName': 'Existing own customer'}),
      ],
    });
    await tester.pumpWidget(const MaterialApp(home: ServiceReportPage()));
    await tester.pumpAndSettle();
    expect(
      (await CustomerDirectory.load()).map((c) => c['customerName']),
      contains('Existing own customer'),
    );
    await tester.tap(find.textContaining('Add building'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Sunrise Tower');
    await tester.enterText(fields.at(1), 'Mumbai');
    await tester.tap(find.textContaining('Save building'));
    await tester.pumpAndSettle();
    final prefs = await CloudPreferences.getInstance();
    final buildings = ServiceBuildings.decode(
      prefs.getStringList(ServiceBuildings.storageKey)!,
    );
    expect(buildings.single['customerName'], 'Sunrise Tower');
    expect(buildings.single['area'], 'Mumbai');
    expect(find.textContaining('Sunrise Tower'), findsWidgets);
    expect(
      (await CustomerDirectory.load()).map((c) => c['customerName']),
      contains('Existing own customer'),
    );
    expect(prefs.getStringList('customers'), hasLength(1));
  });
  testWidgets('Directory failure shows a clean retry panel and recovers', (
    tester,
  ) async {
    AccountSession.instance.update(
      const AccessProfile(
        uid: 'user-a',
        email: 'user@example.com',
        role: 'user',
        masterUid: 'master',
        enabled: true,
        permissions: {'service': true},
      ),
    );
    CloudPreferences.setMockInitialValues({
      'service_buildings': ['invalid json'],
    });
    await tester.pumpWidget(const MaterialApp(home: ServiceReportPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer / Building Name'), findsOneWidget);
    expect(
      find.text('Unable to load customers and buildings. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    CloudPreferences.setMockInitialValues({
      'service_buildings': [
        jsonEncode({'customerName': 'Recovered Tower'}),
      ],
    });
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    final selector = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Recovered Tower'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
