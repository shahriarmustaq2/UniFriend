import '../models/assignment.dart';
import '../models/course.dart';
import '../models/study_plan.dart';
import 'academic_calendar.dart';
import 'date_utils.dart';

/// What the student wants to be reminded about, kept per device.
class ReminderSettings {
  final bool classes;
  final bool deadlines;
  final int classLeadMinutes;

  const ReminderSettings({
    this.classes = false,
    this.deadlines = false,
    this.classLeadMinutes = 15,
  });

  ReminderSettings copyWith({
    bool? classes,
    bool? deadlines,
    int? classLeadMinutes,
  }) => ReminderSettings(
    classes: classes ?? this.classes,
    deadlines: deadlines ?? this.deadlines,
    classLeadMinutes: classLeadMinutes ?? this.classLeadMinutes,
  );
}

enum ReminderKind { classSlot, deadline }

/// One notification to schedule, once, at [at].
class PlannedReminder {
  final ReminderKind kind;
  final String title;
  final String body;

  /// Where tapping the notification leads.
  final String route;
  final DateTime at;

  const PlannedReminder({
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.at,
  });

  /// Identity for working out whether the schedule actually changed.
  String get signature => '$kind|$title|$body|$route|$at';
}

/// How far ahead class reminders are planned. The plan is rebuilt whenever the
/// app is opened, so this only has to outlast a gap between openings.
const int kClassReminderDays = 7;

/// iOS keeps at most 64 pending notifications, and Android also limits alarms.
const int kMaxClassReminders = 30;
const int kMaxDeadlineReminders = 30;

/// The hour on the evening before an exam that its reminder fires.
const int kExamReminderHour = 20;

/// Decides every notification from the student's data. Pure, so it can be tested
/// without a device.
///
/// [upcomingClasses] are the classes actually taking place, so cancelled
/// classes, vacations and alternate weeks are already accounted for.
List<PlannedReminder> planReminders({
  required ReminderSettings settings,
  required Iterable<ClassOccurrence> upcomingClasses,
  required Iterable<Assignment> assignments,
  required Iterable<Exam> exams,
  required Map<String, Course> courses,
  required String Function(String courseId) courseRoute,
  required String routineRoute,
  required String studyRoute,
  required DateTime now,
}) {
  final plan = <PlannedReminder>[];

  if (settings.classes) {
    final lead = settings.classLeadMinutes;
    final classes = <PlannedReminder>[];
    for (final occurrence in upcomingClasses) {
      final at = occurrence.startsAt.subtract(Duration(minutes: lead));
      if (!at.isAfter(now)) continue;
      classes.add(
        PlannedReminder(
          kind: ReminderKind.classSlot,
          title: '${occurrence.course.code} in $lead minutes',
          body: [
            AppDate.minuteOfDay(occurrence.slot.startMinute),
            ?occurrence.slot.room,
          ].join('  ·  '),
          route: routineRoute,
          at: at,
        ),
      );
    }
    classes.sort((a, b) => a.at.compareTo(b.at));
    plan.addAll(classes.take(kMaxClassReminders));
  }

  if (settings.deadlines) {
    final upcoming = <PlannedReminder>[];
    for (final assignment in assignments) {
      if (assignment.isCompleted) continue;
      final course = courses[assignment.courseId];
      final label = course == null
          ? assignment.title
          : '${course.code}: ${assignment.title}';

      for (final (before, wording) in const [
        (Duration(days: 1), 'Due tomorrow'),
        (Duration(hours: 1), 'Due in an hour'),
      ]) {
        final at = assignment.dueDate.subtract(before);
        if (!at.isAfter(now)) continue;
        upcoming.add(
          PlannedReminder(
            kind: ReminderKind.deadline,
            title: wording,
            body: label,
            route: courseRoute(assignment.courseId),
            at: at,
          ),
        );
      }
    }
    for (final exam in exams) {
      final eve = AppDate.addDays(exam.heldOn, -1);
      final at = DateTime(eve.year, eve.month, eve.day, kExamReminderHour);
      if (!at.isAfter(now)) continue;
      final course = exam.courseId == null ? null : courses[exam.courseId];
      upcoming.add(
        PlannedReminder(
          kind: ReminderKind.deadline,
          title: '${exam.kind.label} tomorrow',
          body: course == null ? exam.title : '${course.code}: ${exam.title}',
          route: studyRoute,
          at: at,
        ),
      );
    }
    upcoming.sort((a, b) => a.at.compareTo(b.at));
    plan.addAll(upcoming.take(kMaxDeadlineReminders));
  }

  return plan;
}
