import 'package:intl/intl.dart';

enum BillFrequency { daily, weekly, monthly, yearly }

enum ReportPeriod { week, month, year }

class AppDateUtils {
  const AppDateUtils._();

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Advances [current] by [frequency], clamping end-of-month days safely
  /// (e.g., Jan 31 + 1 month -> Feb 28 or Feb 29).
  static DateTime advanceDueDate(DateTime current, BillFrequency frequency) {
    switch (frequency) {
      case BillFrequency.daily:
        return DateTime(current.year, current.month, current.day + 1);
      case BillFrequency.weekly:
        return DateTime(current.year, current.month, current.day + 7);
      case BillFrequency.monthly:
        final targetYear = current.year + ((current.month) ~/ 12);
        final targetMonth = (current.month % 12) + 1;
        final daysInTarget = daysInMonth(targetYear, targetMonth);
        final day = current.day > daysInTarget ? daysInTarget : current.day;
        return DateTime(targetYear, targetMonth, day);
      case BillFrequency.yearly:
        final targetYear = current.year + 1;
        final daysInTarget = daysInMonth(targetYear, current.month);
        final day = current.day > daysInTarget ? daysInTarget : current.day;
        return DateTime(targetYear, current.month, day);
    }
  }

  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Returns inclusive [start] (00:00:00) and exclusive [end] (00:00:00 next day).
  static ({DateTime start, DateTime end}) periodRange(
    ReportPeriod period,
    DateTime anchor,
  ) {
    final d = dateOnly(anchor);
    switch (period) {
      case ReportPeriod.week:
        final start = d.subtract(Duration(days: d.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return (start: start, end: end);
      case ReportPeriod.month:
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 1);
        return (start: start, end: end);
      case ReportPeriod.year:
        final start = DateTime(d.year, 1, 1);
        final end = DateTime(d.year + 1, 1, 1);
        return (start: start, end: end);
    }
  }

  static DateTime shiftAnchor(
    ReportPeriod period,
    DateTime anchor,
    int delta,
  ) {
    switch (period) {
      case ReportPeriod.week:
        return anchor.add(Duration(days: 7 * delta));
      case ReportPeriod.month:
        return DateTime(anchor.year, anchor.month + delta, 1);
      case ReportPeriod.year:
        return DateTime(anchor.year + delta, 1, 1);
    }
  }

  static String periodLabel(ReportPeriod period, DateTime anchor) {
    switch (period) {
      case ReportPeriod.week:
        final r = periodRange(period, anchor);
        final endInclusive = r.end.subtract(const Duration(days: 1));
        return '${DateFormat('d MMM').format(r.start)} – ${DateFormat('d MMM').format(endInclusive)}';
      case ReportPeriod.month:
        return DateFormat('MMMM yyyy').format(anchor);
      case ReportPeriod.year:
        return DateFormat('yyyy').format(anchor);
    }
  }

  static String dayGroupLabel(DateTime dt, {DateTime? now}) {
    final ref = dateOnly(now ?? DateTime.now());
    final target = dateOnly(dt);
    final diff = ref.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, dd MMM yyyy').format(target);
  }
}
