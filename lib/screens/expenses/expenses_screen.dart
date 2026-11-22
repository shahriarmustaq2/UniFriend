import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers/core_providers.dart';
import '../../providers/expense_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../widgets/amount_sheet.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_fab.dart';
import '../../widgets/meter_bar.dart';
import 'expense_editor_sheet.dart';

/// A month of spending: how much against the budget, what is safe to spend
/// per day, where it went, and the list by day.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'Add expense',
        onPressed: () => showExpenseEditor(context),
      ),
      body: AsyncView<List<Expense>>(
        value: expenses,
        onRetry: () => ref.invalidate(expenseListProvider),
        builder: (context, all) {
          final inMonth = Money.inMonth(all, _month);
          final days = Money.byDay(inMonth);

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              _MonthSwitcher(
                month: _month,
                canGoForward: !_isCurrentMonth,
                onShift: _shift,
              ),
              const SizedBox(height: 12),
              _BudgetCard(month: _month, spent: Money.total(inMonth)),
              if (inMonth.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CategoryBar(expenses: inMonth),
              ],
              const SizedBox(height: 22),
              if (inMonth.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  accent: AppColors.orange,
                  title: 'Nothing spent in ${AppDate.monthYear(_month)}',
                  message: 'Add what you spend as you go. It takes a second.',
                  actionLabel: _isCurrentMonth ? 'Add expense' : null,
                  onAction: _isCurrentMonth
                      ? () => showExpenseEditor(context)
                      : null,
                )
              else
                for (final (day, items) in days) ...[
                  _DayHeader(day: day, total: Money.total(items)),
                  const SizedBox(height: 6),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        for (final expense in items)
                          _ExpenseRow(expense: expense),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final bool canGoForward;
  final ValueChanged<int> onShift;

  const _MonthSwitcher({
    required this.month,
    required this.canGoForward,
    required this.onShift,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () => onShift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.textSecondary,
        ),
        Expanded(
          child: Text(
            AppDate.monthYear(month),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: canGoForward ? () => onShift(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppColors.textSecondary,
          disabledColor: AppColors.textHint.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final DateTime month;
  final double spent;

  const _BudgetCard({required this.month, required this.spent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(monthlyBudgetProvider);
    final perDay = Money.safePerDay(budget: budget, spent: spent, month: month);
    final daysLeft = Money.daysLeft(month);
    final over = budget != null && spent > budget;
    final fraction = budget == null || budget == 0 ? 0.0 : spent / budget;
    final barColor = over
        ? AppColors.error
        : fraction > 0.85
        ? AppColors.warning
        : AppColors.primary;

    void editBudget() => showAmountSheet(
      context,
      title: 'Monthly budget',
      label: 'Amount in $kCurrencySymbol',
      icon: Icons.savings_outlined,
      initial: budget,
      max: 10000000,
      onSave: (value) =>
          ref.read(profileProvider.notifier).setMonthlyBudget(value),
      onClear: () => ref.read(profileProvider.notifier).setMonthlyBudget(null),
    );

    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPENT',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(spent),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: over ? AppColors.error : AppColors.textPrimary,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: editBudget,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        budget == null
                            ? 'Set budget'
                            : 'of ${Money.format(budget)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: budget == null
                              ? AppColors.primaryMedium
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (budget != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (budget != null) ...[
            const SizedBox(height: 12),
            MeterBar(fraction: fraction, color: barColor),
            const SizedBox(height: 12),
            Text(
              over
                  ? 'Over budget by ${Money.format(spent - budget)}'
                  : perDay == null
                  ? '${Money.format(budget - spent)} left over'
                  : 'Safe to spend ${Money.format(perDay.floorToDouble())} a day'
                        ' for the next ${AppDate.plural(daysLeft, 'day')}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: over ? AppColors.error : AppColors.success,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Set a monthly budget to see what you can spend each day.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// One bar split by category, with the amounts underneath.
class _CategoryBar extends StatelessWidget {
  final List<Expense> expenses;

  const _CategoryBar({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final split = Money.byCategory(expenses);
    final total = Money.total(expenses);

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final (category, amount) in split)
                    Expanded(
                      flex: (amount / total * 1000).round().clamp(1, 1000),
                      child: Container(
                        color: category.color,
                        margin: const EdgeInsets.only(right: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final (category, amount) in split)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${category.label}  ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      Money.format(amount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final double total;

  const _DayHeader({required this.day, required this.total});

  @override
  Widget build(BuildContext context) {
    final days = AppDate.daysUntil(day);
    final label = days == 0
        ? 'Today'
        : days == -1
        ? 'Yesterday'
        : AppDate.weekdayDayMonth(day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            Money.format(total),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;

  const _ExpenseRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    final category = expense.category;
    return InkWell(
      onTap: () => showExpenseEditor(context, expense: expense),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.icon, size: 17, color: category.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                expense.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              Money.format(expense.amount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
