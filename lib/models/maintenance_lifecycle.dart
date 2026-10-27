import 'maintenance_quotation.dart';

enum MaintenanceSystemStatus { active, expiringSoon, expired, archived }

enum MaintenanceView { all, active, expiringSoon, expired, renewed }

class MaintenanceLifecycle {
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static DateTime nextDay(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);

  /// Calendar months, clamped to the last valid day, with an inclusive end date.
  static DateTime periodEnd(DateTime start, int months) {
    final target = DateTime(start.year, start.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    final anniversary = DateTime(
      target.year,
      target.month,
      start.day > lastDay ? lastDay : start.day,
    );
    return DateTime(anniversary.year, anniversary.month, anniversary.day - 1);
  }

  static bool superseded(
    MaintenanceQuotation q,
    List<MaintenanceQuotation> all,
  ) => all.any(
    (other) => other.srNo != q.srNo && other.renewedFromSrNo == q.srNo,
  );

  static MaintenanceSystemStatus status(
    MaintenanceQuotation q,
    List<MaintenanceQuotation> all, {
    DateTime? now,
  }) {
    if (superseded(q, all)) return MaintenanceSystemStatus.archived;
    final today = day(now ?? DateTime.now());
    final end = day(q.endDate);
    if (end.isBefore(today)) return MaintenanceSystemStatus.expired;
    // Calendar-day arithmetic avoids expiring a contract at midnight on its last day.
    final remaining = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (remaining <= 30) return MaintenanceSystemStatus.expiringSoon;
    return MaintenanceSystemStatus.active;
  }

  static bool renewedThisMonth(MaintenanceQuotation q, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final renewed = q.renewedAt?.toLocal();
    return q.renewedFromSrNo != null &&
        renewed != null &&
        renewed.year == today.year &&
        renewed.month == today.month;
  }

  static bool matches(
    MaintenanceQuotation q,
    List<MaintenanceQuotation> all,
    MaintenanceView view, {
    DateTime? now,
  }) {
    final current = status(q, all, now: now);
    return switch (view) {
      MaintenanceView.all => true,
      MaintenanceView.active => current == MaintenanceSystemStatus.active,
      MaintenanceView.expiringSoon =>
        current == MaintenanceSystemStatus.expiringSoon,
      MaintenanceView.expired => current == MaintenanceSystemStatus.expired,
      MaintenanceView.renewed => renewedThisMonth(q, now: now),
    };
  }

  static MaintenanceQuotation renewalDraft(
    MaintenanceQuotation source, {
    DateTime? now,
  }) {
    final today = day(now ?? DateTime.now());
    final following = nextDay(source.endDate);
    final start = following.isAfter(today) ? following : today;
    return MaintenanceQuotation(
      srNo: (now ?? DateTime.now()).microsecondsSinceEpoch,
      offerDate: today,
      customerName: source.customerName,
      area: source.area,
      startDate: start,
      endDate: periodEnd(start, source.months),
      liftQty: source.liftQty,
      months: source.months,
      liftAmount: source.liftAmount,
      monthlyAmount: source.monthlyAmount,
      totalAmount: source.totalAmount,
      status: 'Active',
      renewedFromSrNo: source.srNo,
    );
  }
}
