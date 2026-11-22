import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reminder_gateway.dart';
import '../models/assignment.dart';
import '../models/attendance_record.dart';
import '../router.dart';
import '../utils/date_utils.dart';
import '../utils/reminder_plan.dart';
import 'assignment_providers.dart';
import 'attendance_providers.dart';
import 'core_providers.dart';
import 'course_providers.dart';
import 'routine_providers.dart';
import 'semester_providers.dart';
import 'study_providers.dart';

final reminderGatewayProvider = Provider<ReminderGateway>(
  (ref) => LocalReminderGateway(),
);

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  static const String _classesKey = 'reminders.classes';
  static const String _deadlinesKey = 'reminders.deadlines';
  static const String _leadKey = 'reminders.class_lead_minutes';

  @override
  ReminderSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    const defaults = ReminderSettings();
    return ReminderSettings(
      classes: prefs.getBool(_classesKey) ?? defaults.classes,
      deadlines: prefs.getBool(_deadlinesKey) ?? defaults.deadlines,
      classLeadMinutes: prefs.getInt(_leadKey) ?? defaults.classLeadMinutes,
    );
  }

  void save(ReminderSettings settings) {
    state = settings;
    ref.read(sharedPreferencesProvider)
      ..setBool(_classesKey, settings.classes)
      ..setBool(_deadlinesKey, settings.deadlines)
      ..setInt(_leadKey, settings.classLeadMinutes);
  }
}

/// How many notifications are currently planned, for the settings screen.
final plannedReminderCountProvider = Provider<int>((ref) {
  return ref.watch(_plannedRemindersProvider)?.length ?? 0;
});

/// Null while the data needed for a decision is not available. A failed load
/// must not read as "no classes" and wipe reminders that are already scheduled.
final _plannedRemindersProvider = Provider<List<PlannedReminder>?>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const [];

  final watched = [
    ref.watch(classSlotListProvider),
    ref.watch(assignmentListProvider),
    ref.watch(courseListProvider),
    ref.watch(semesterListProvider),
    ref.watch(vacationListProvider),
    ref.watch(attendanceListProvider),
    ref.watch(examListProvider),
  ];
  if (watched.any((list) => !list.hasValue)) return null;

  final now = DateTime.now();
  final today = AppDate.dayOf(now);
  final cancelled = {
    for (final r in ref.watch(attendanceListProvider).value ?? const [])
      if (r.status == AttendanceStatus.cancelled)
        (r.courseId, r.heldOn, r.session),
  };
  final upcoming = [
    for (var i = 0; i < kClassReminderDays; i++)
      for (final occurrence in ref.watch(
        classesOnDayProvider(AppDate.addDays(today, i)),
      ))
        if (!cancelled.contains((
          occurrence.course.id,
          occurrence.date,
          occurrence.session,
        )))
          occurrence,
  ];

  return planReminders(
    settings: ref.watch(reminderSettingsProvider),
    upcomingClasses: upcoming,
    assignments:
        ref.watch(assignmentListProvider).value ?? const <Assignment>[],
    exams: ref.watch(upcomingExamsProvider),
    courses: ref.watch(courseByIdProvider),
    courseRoute: AppRoutes.courseDetail,
    routineRoute: AppRoutes.routine,
    studyRoute: AppRoutes.study,
    now: now,
  );
});

/// Keeps the device's schedule matching the plan, rewriting it only on a change.
final reminderSyncProvider = Provider<void>((ref) {
  final gateway = ref.read(reminderGatewayProvider);
  String? applied;

  ref.listen(_plannedRemindersProvider, (_, plan) {
    if (plan == null) return;
    final signature = plan.map((r) => r.signature).join('\n');
    if (signature == applied) return;
    applied = signature;
    unawaited(
      gateway.replaceAll(plan).catchError((Object error) {
        // A reminder failing to schedule must not disturb the rest of the app.
        debugPrint('Could not schedule reminders: $error');
      }),
    );
  }, fireImmediately: true);
});
