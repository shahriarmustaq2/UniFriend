import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/expense.dart';
import '../utils/money.dart';
import 'core_providers.dart';
import 'personal_list_notifier.dart';

final expenseListProvider =
    AsyncNotifierProvider<ExpenseListNotifier, List<Expense>>(
      ExpenseListNotifier.new,
    );

class ExpenseListNotifier extends PersonalListNotifier<Expense> {
  @override
  TableSpec<Expense> get spec => Tables.expenses;

  /// Newest first.
  @override
  int compare(Expense a, Expense b) {
    final byDay = b.spentOn.compareTo(a.spentOn);
    return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
  }
}

/// Spending in the current calendar month.
final spentThisMonthProvider = Provider<double>((ref) {
  final all = ref.watch(expenseListProvider).value ?? const <Expense>[];
  return Money.total(Money.inMonth(all, DateTime.now()));
});

final monthlyBudgetProvider = Provider<double?>((ref) {
  return ref.watch(profileProvider).value?.monthlyBudget;
});
