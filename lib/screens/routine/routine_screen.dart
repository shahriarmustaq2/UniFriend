import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/class_slot.dart';
import '../../providers/routine_providers.dart';
import '../../providers/semester_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_view.dart';
import '../../widgets/class_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_fab.dart';
import 'class_slot_editor_sheet.dart';

/// A real week of classes, one day at a time. Marks apply to the exact date
/// shown, alternate-week classes appear only in their weeks, and vacation days
/// are empty.
class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  DateTime _day = AppDate.dayOf(DateTime.now());

  DateTime get _weekStart => AppDate.startOfWeek(_day);

  void _shiftWeek(int weeks) =>
      setState(() => _day = AppDate.addDays(_day, weeks * 7));

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(classSlotListProvider);
    final today = AppDate.dayOf(DateTime.now());
    final semester = ref.watch(currentSemesterProvider);
    final calendar = ref.watch(calendarLookupProvider)(semester?.id);
    final week = calendar.weekNumber(_day);
    final weekEnd = AppDate.addDays(_weekStart, 6);
    final vacationWeek = calendar.isVacationWeek(_weekStart);

    final range =
        '${AppDate.dayMonth(_weekStart)} – ${AppDate.dayMonth(weekEnd)}';
    final weekLabel = vacationWeek
        ? 'Vacation  ·  $range'
        : week == null
        ? range
        : 'Week $week  ·  $range';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'New class',
        onPressed: () => showClassSlotEditor(context, weekday: _day.weekday),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppColors.textSecondary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _day = today),
                    child: Text(
                      weekLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayChip(
                      day: AppDate.addDays(_weekStart, i),
                      selected: AppDate.addDays(_weekStart, i) == _day,
                      isToday: AppDate.addDays(_weekStart, i) == today,
                      isVacation: calendar.isVacationDay(
                        AppDate.addDays(_weekStart, i),
                      ),
                      onTap: () =>
                          setState(() => _day = AppDate.addDays(_weekStart, i)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: AsyncView<List<ClassSlot>>(
              value: slots,
              onRetry: () => ref.invalidate(classSlotListProvider),
              builder: (context, _) {
                final classes = ref.watch(classesOnDayProvider(_day));
                final vacation = calendar.vacationOn(_day);
                if (classes.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                    children: [
                      vacation != null
                          ? EmptyState(
                              icon: Icons.beach_access_outlined,
                              accent: AppColors.cyan,
                              title: vacation.title.isEmpty
                                  ? 'Vacation'
                                  : vacation.title,
                              message:
                                  'No classes until '
                                  '${AppDate.weekdayDayMonth(vacation.endsOn)}. '
                                  'Week numbers pause through it.',
                            )
                          : EmptyState(
                              icon: Icons.event_available_outlined,
                              accent: AppColors.primary,
                              title:
                                  'No classes on ${AppDate.weekdayName(_day.weekday)}',
                              message:
                                  'Add your classes once, and they repeat every '
                                  'week, or every other week for alternate labs.',
                              actionLabel: 'Add a class',
                              onAction: () => showClassSlotEditor(
                                context,
                                weekday: _day.weekday,
                              ),
                            ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  itemCount: classes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => ClassCard(
                    occurrence: classes[index],
                    onEdit: () => showClassSlotEditor(
                      context,
                      weekday: _day.weekday,
                      slot: classes[index].slot,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool isVacation;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.isVacation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.midnight
        : isVacation
        ? AppColors.textHint
        : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: AppDate.weekdayDayMonth(day),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isToday && !selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: selected ? 0 : 0.06),
            ),
          ),
          child: Column(
            children: [
              Text(
                AppDate.weekdayShort(day.weekday).substring(0, 2),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: selected ? 0.8 : 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isVacation
                      ? AppColors.cyan
                      : isToday && !selected
                      ? AppColors.primary
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
