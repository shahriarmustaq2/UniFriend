import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_record.dart';
import '../providers/attendance_providers.dart';
import '../theme/app_colors.dart';
import '../utils/academic_calendar.dart';
import '../utils/date_utils.dart';
import 'feedback.dart';
import 'glass_container.dart';

extension AttendanceStatusColor on AttendanceStatus {
  Color get color => switch (this) {
    AttendanceStatus.present => AppColors.success,
    AttendanceStatus.late => AppColors.warning,
    AttendanceStatus.absent => AppColors.error,
    AttendanceStatus.cancelled => AppColors.textHint,
  };
}

/// One class on one date: time, course, room, and the attendance mark.
///
/// A class in the future can be cancelled but not marked, since it has not
/// happened yet. A cancelled class shows as such, with a way to restore it.
class ClassCard extends ConsumerWidget {
  final ClassOccurrence occurrence;
  final VoidCallback? onEdit;

  const ClassCard({super.key, required this.occurrence, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = occurrence.slot;
    final course = occurrence.course;
    final record = ref.watch(
      attendanceRecordProvider((
        course.id,
        occurrence.date,
        occurrence.session,
      )),
    );
    final cancelled = record?.status == AttendanceStatus.cancelled;
    final isFuture = occurrence.date.isAfter(AppDate.dayOf(DateTime.now()));

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color:
                    (cancelled
                            ? AppColors.textHint
                            : course.isSessional
                            ? AppColors.cyan
                            : AppColors.primary)
                        .withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (cancelled) 'Cancelled' else slot.timeLabel,
                        ?slot.room,
                        if (slot.isAlternate) 'Alt. week',
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cancelled
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!cancelled && !isFuture)
              AttendanceMarker(
                selected: record?.status,
                onSelected: (status) => _mark(context, ref, record, status),
              ),
            _ClassMenu(
              cancelled: cancelled,
              onCancel: () => _setCancelled(context, ref, record, true),
              onRestore: () => _setCancelled(context, ref, record, false),
              onEdit: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  /// Tapping the mark that is already selected removes it, so a slip of the
  /// finger never leaves a class wrongly recorded.
  Future<void> _mark(
    BuildContext context,
    WidgetRef ref,
    AttendanceRecord? record,
    AttendanceStatus status,
  ) {
    final notifier = ref.read(attendanceListProvider.notifier);
    return runAction(context, () {
      if (record != null && record.status == status) {
        return notifier.delete(record.id);
      }
      return notifier.mark(
        courseId: occurrence.course.id,
        heldOn: occurrence.date,
        session: occurrence.session,
        status: status,
      );
    });
  }

  Future<void> _setCancelled(
    BuildContext context,
    WidgetRef ref,
    AttendanceRecord? record,
    bool cancel,
  ) {
    final notifier = ref.read(attendanceListProvider.notifier);
    return runAction(
      context,
      () async {
        if (cancel) {
          await notifier.mark(
            courseId: occurrence.course.id,
            heldOn: occurrence.date,
            session: occurrence.session,
            status: AttendanceStatus.cancelled,
          );
        } else if (record != null) {
          await notifier.delete(record.id);
        }
      },
      successMessage: cancel
          ? '${occurrence.course.code} cancelled for '
                '${AppDate.weekdayDayMonth(occurrence.date)}'
          : null,
    );
  }
}

class _ClassMenu extends StatelessWidget {
  final bool cancelled;
  final VoidCallback onCancel;
  final VoidCallback onRestore;
  final VoidCallback? onEdit;

  const _ClassMenu({
    required this.cancelled,
    required this.onCancel,
    required this.onRestore,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      useRootNavigator: true,
      tooltip: 'Class options',
      padding: EdgeInsets.zero,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: AppColors.textHint,
        ),
      ),
      onSelected: (value) {
        if (value == 'cancel') onCancel();
        if (value == 'restore') onRestore();
        if (value == 'edit') onEdit?.call();
      },
      itemBuilder: (context) => [
        if (cancelled)
          const PopupMenuItem(value: 'restore', child: Text('Restore class'))
        else
          const PopupMenuItem(value: 'cancel', child: Text('Class cancelled')),
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Edit in routine')),
      ],
    );
  }
}

/// Three small buttons: Present, Late, Absent.
class AttendanceMarker extends StatelessWidget {
  final AttendanceStatus? selected;
  final ValueChanged<AttendanceStatus> onSelected;

  const AttendanceMarker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final status in AttendanceStatus.taken)
          Tooltip(
            message: status.label,
            child: GestureDetector(
              onTap: () => onSelected(status),
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                selected: selected == status,
                label: status.label,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2.5,
                    vertical: 6,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected == status
                          ? status.color
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: selected == status
                            ? status.color
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      status.short,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected == status
                            ? AppColors.midnight
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
