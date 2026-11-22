import 'package:intl/intl.dart';

import '../models/expense.dart';
import 'date_utils.dart';

/// The currency shown across the app. Change it here to switch currency. Plain
/// letters, because Roboto has no glyph for the taka sign and whether a device
/// falls back to a font that does cannot be relied on.
const String kCurrencySymbol = 'Tk';

class Money {
  Money._();

  static final NumberFormat _amount = NumberFormat('#,##0.##');

  static String format(double value) =>
      '$kCurrencySymbol ${_amount.format(value)}';

  static double total(Iterable<Expense> expenses) =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Expenses dated in the same calendar month as [month].
  static List<Expense> inMonth(Iterable<Expense> expenses, DateTime month) {
    return expenses
        .where(
          (e) => e.spentOn.year == month.year && e.spentOn.month == month.month,
        )
        .toList(growable: false);
  }

  /// Spending per category, largest first. Categories with no spending are
  /// left out.
  static List<(ExpenseCategory, double)> byCategory(
    Iterable<Expense> expenses,
  ) {
    final totals = <ExpenseCategory, double>{};
    for (final expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return [for (final e in totals.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// [expenses] grouped by day, newest day first.
  static List<(DateTime, List<Expense>)> byDay(Iterable<Expense> expenses) {
    final days = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      days.putIfAbsent(AppDate.dayOf(expense.spentOn), () => []).add(expense);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final day in keys) (day, days[day]!)];
  }

  /// Days of [month] still to spend in, today included. Zero for a past month,
  /// and the whole month for a future one.
  static int daysLeft(DateTime month, {DateTime? now}) {
    final today = AppDate.dayOf(now ?? DateTime.now());
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month, AppDate.daysInMonth(month));
    if (today.isAfter(last)) return 0;
    if (today.isBefore(first)) return AppDate.daysInMonth(month);
    return last.day - today.day + 1;
  }

  /// What can be spent each remaining day of [month] and still stay within
  /// [budget]. Null when there is no budget or the month is over; zero once
  /// the budget is used up.
  static double? safePerDay({
    required double? budget,
    required double spent,
    required DateTime month,
    DateTime? now,
  }) {
    if (budget == null) return null;
    final days = daysLeft(month, now: now);
    if (days == 0) return null;
    final left = budget - spent;
    return left <= 0 ? 0 : left / days;
  }
}
