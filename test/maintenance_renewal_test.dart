import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_quotation_app/auth/account_session.dart';
import 'package:elevator_quotation_app/auth/access_profile.dart';
import 'package:elevator_quotation_app/models/maintenance_quotation.dart';
import 'package:elevator_quotation_app/models/maintenance_lifecycle.dart';
import 'package:elevator_quotation_app/storage/cloud_preferences.dart';
import 'package:elevator_quotation_app/storage/maintenance_quotation_storage.dart';
import 'package:elevator_quotation_app/pages/saved_maintenance_quotations_page.dart';
import 'package:elevator_quotation_app/pages/maintenance_quotation_page.dart';
import 'package:elevator_quotation_app/utils/app_theme.dart';

MaintenanceQuotation contract({
  int id = 1,
  DateTime? end,
  int? parent,
  DateTime? renewed,
}) => MaintenanceQuotation(
  srNo: id,
  offerDate: DateTime(2026, 1, 1),
  customerName: 'Sunrise Tower',
  area: 'Pune',
  startDate: DateTime(2026, 1, 1),
  endDate: end ?? DateTime(2026, 12, 31),
  liftQty: 2,
  months: 12,
  liftAmount: 12000,
  monthlyAmount: 1000,
  totalAmount: 24000,
  status: 'Active',
  renewedFromSrNo: parent,
  renewedAt: renewed,
);

void main() {
  tearDown(() {
    CloudPreferences.clearMock();
    AccountSession.instance.update(null);
  });

  for (final width in [320.0, 1200.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Maintenance views and renewal form fit width $width, dark $dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          AccountSession.instance.update(
            const AccessProfile(
              uid: 'user',
              email: 'user@example.com',
              role: 'user',
              masterUid: 'master',
              enabled: true,
              permissions: {'maintenance': true},
            ),
          );
          final today = DateTime.now();
          final old = contract(
            end: DateTime(today.year, today.month, today.day - 1),
          );
          final next = contract(
            id: 2,
            end: DateTime(today.year + 1, today.month, today.day),
            parent: 1,
            renewed: today,
          );
          CloudPreferences.setMockInitialValues({
            'maintenance_quotations': [
              jsonEncode(old.toMap()),
              jsonEncode(next.toMap()),
            ],
          });
          final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          for (final view in MaintenanceView.values) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: SavedMaintenanceQuotationsPage(
                  key: ValueKey(view),
                  initialView: view,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MaintenanceQuotationPage(quotationToRenew: old),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.widgetWithText(
            ElevatedButton,
            'Renew Maintenance',
          );
          await tester.scrollUntilVisible(
            button,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  test('Expiry uses inclusive end dates and a 30 calendar day window', () {
    final now = DateTime(2026, 10, 24, 23, 59);
    final active = contract(end: DateTime(2026, 11, 24));
    final near = contract(end: DateTime(2026, 11, 23));
    final today = contract(end: DateTime(2026, 10, 24));
    final expired = contract(end: DateTime(2026, 10, 23));
    expect(
      MaintenanceLifecycle.status(active, [active], now: now),
      MaintenanceSystemStatus.active,
    );
    expect(
      MaintenanceLifecycle.status(near, [near], now: now),
      MaintenanceSystemStatus.expiringSoon,
    );
    expect(
      MaintenanceLifecycle.status(today, [today], now: now),
      MaintenanceSystemStatus.expiringSoon,
    );
    expect(
      MaintenanceLifecycle.status(expired, [expired], now: now),
      MaintenanceSystemStatus.expired,
    );
  });

  test(
    'Renewed is a current-calendar-month activity view; active persists after rollover',
    () {
      final old = contract(end: DateTime(2026, 10, 20));
      final renewed = contract(
        id: 2,
        end: DateTime(2027, 10, 23),
        parent: 1,
        renewed: DateTime(2026, 10, 24),
      );
      final all = [old, renewed];
      expect(
        MaintenanceLifecycle.status(old, all, now: DateTime(2026, 10, 24)),
        MaintenanceSystemStatus.archived,
      );
      expect(
        MaintenanceLifecycle.matches(
          renewed,
          all,
          MaintenanceView.active,
          now: DateTime(2026, 10, 24),
        ),
        isTrue,
      );
      expect(
        MaintenanceLifecycle.matches(
          renewed,
          all,
          MaintenanceView.renewed,
          now: DateTime(2026, 10, 31),
        ),
        isTrue,
      );
      expect(
        MaintenanceLifecycle.matches(
          renewed,
          all,
          MaintenanceView.renewed,
          now: DateTime(2026, 11, 1),
        ),
        isFalse,
      );
      expect(
        MaintenanceLifecycle.matches(
          renewed,
          all,
          MaintenanceView.active,
          now: DateTime(2026, 11, 1),
        ),
        isTrue,
      );
      expect(
        MaintenanceLifecycle.matches(
          renewed,
          all,
          MaintenanceView.renewed,
          now: DateTime(2027, 10, 1),
        ),
        isFalse,
      );
    },
  );

  test('Same customer name does not silently renew an unrelated quotation', () {
    final old = contract(end: DateTime(2025, 12, 31));
    final separate = contract(id: 2);
    expect(
      MaintenanceLifecycle.status(old, [
        old,
        separate,
      ], now: DateTime(2026, 10, 24)),
      MaintenanceSystemStatus.expired,
    );
    expect(
      MaintenanceLifecycle.renewedThisMonth(
        separate,
        now: DateTime(2026, 1, 1),
      ),
      isFalse,
    );
  });

  test(
    'Renewal draft retains pricing and correctly calculates future or lapsed periods',
    () {
      final current = contract();
      final early = MaintenanceLifecycle.renewalDraft(
        current,
        now: DateTime(2026, 10, 24),
      );
      expect(early.startDate, DateTime(2027, 1, 1));
      expect(early.endDate, DateTime(2027, 12, 31));
      expect(early.liftAmount, current.liftAmount);
      expect(early.liftQty, current.liftQty);
      expect(early.renewedAt, isNull);
      final late = MaintenanceLifecycle.renewalDraft(
        current,
        now: DateTime(2027, 2, 3),
      );
      expect(late.startDate, DateTime(2027, 2, 3));
      expect(late.endDate, DateTime(2028, 2, 2));
      expect(
        MaintenanceLifecycle.periodEnd(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 27),
      );
      expect(
        MaintenanceLifecycle.periodEnd(DateTime(2024, 2, 29), 12),
        DateTime(2025, 2, 27),
      );
    },
  );

  test(
    'Storage preserves history and renewal metadata, rejects a duplicate renewal',
    () async {
      final old = contract(end: DateTime(2026, 10, 23));
      CloudPreferences.setMockInitialValues({
        'maintenance_quotations': [jsonEncode(old.toMap())],
      });
      final next = MaintenanceQuotation.fromMap({
        ...MaintenanceLifecycle.renewalDraft(
          old,
          now: DateTime(2026, 10, 24),
        ).toMap(),
        'renewedAt': DateTime(2026, 10, 24).toIso8601String(),
      });
      await MaintenanceQuotationStorage.save(next);
      final loaded = await MaintenanceQuotationStorage.load();
      expect(loaded, hasLength(2));
      expect(loaded.first.toMap(), old.toMap());
      expect(loaded.last.renewedFromSrNo, old.srNo);
      expect(loaded.last.renewedAt, DateTime(2026, 10, 24));
      final duplicate = MaintenanceQuotation.fromMap({
        ...next.toMap(),
        'srNo': next.srNo + 1,
      });
      await expectLater(
        MaintenanceQuotationStorage.save(duplicate),
        throwsStateError,
      );
      // Editing a renewal must retain the original event date and link.
      final edited = MaintenanceQuotation.fromMap({
        ...next.toMap(),
        'liftAmount': 15000.0,
        'totalAmount': 30000.0,
      });
      await MaintenanceQuotationStorage.save(edited);
      final saved = (await MaintenanceQuotationStorage.load()).last;
      expect(saved.liftAmount, 15000);
      expect(saved.renewedAt, next.renewedAt);
    },
  );

  testWidgets(
    'Saved quotation menu opens a prefilled renewal and saves updated amount as a new contract',
    (tester) async {
      AccountSession.instance.update(
        const AccessProfile(
          uid: 'user',
          email: 'user@example.com',
          role: 'user',
          masterUid: 'master',
          enabled: true,
          permissions: {'maintenance': true},
        ),
      );
      final now = DateTime.now();
      final old = contract(end: DateTime(now.year, now.month, now.day - 1));
      CloudPreferences.setMockInitialValues({
        'maintenance_quotations': [jsonEncode(old.toMap())],
      });
      await tester.pumpWidget(
        const MaterialApp(home: SavedMaintenanceQuotationsPage()),
      );
      await tester.pumpAndSettle();
      final menu = find.byTooltip('Quotation actions');
      await tester.scrollUntilVisible(
        menu,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renew maintenance'));
      await tester.pumpAndSettle();
      expect(find.text('Sunrise Tower'), findsWidgets);
      final amount = find.widgetWithText(TextField, 'Lift Amount');
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '18000');
      final save = find.widgetWithText(ElevatedButton, 'Renew Maintenance');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final all = await MaintenanceQuotationStorage.load();
      expect(all, hasLength(2));
      expect(all.last.renewedFromSrNo, old.srNo);
      expect(all.last.liftAmount, 18000);
      expect(all.last.totalAmount, 36000);
      expect(MaintenanceLifecycle.renewedThisMonth(all.last), isTrue);
      expect(
        MaintenanceLifecycle.status(all.first, all),
        MaintenanceSystemStatus.archived,
      );
      expect(
        MaintenanceLifecycle.status(all.last, all),
        MaintenanceSystemStatus.active,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
