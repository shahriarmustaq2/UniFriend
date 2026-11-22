import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/assignment.dart';
import 'package:unifriend/models/class_slot.dart';
import 'package:unifriend/models/course.dart';
import 'package:unifriend/models/study_plan.dart';
import 'package:unifriend/utils/academic_calendar.dart';
import 'package:unifriend/utils/reminder_plan.dart';

final _course = Course(
  id: 'c',
  code: 'CSE2100',
  title: 'Software',
  credits: 3,
  semesterId: 's',
  createdAt: DateTime(2026),
);

ClassOccurrence _class(DateTime day, int startMinute, {String? room}) =>
    ClassOccurrence(
      slot: ClassSlot(
        id: 'slot-$startMinute',
        courseId: 'c',
        weekday: day.weekday,
        startMinute: startMinute,
        endMinute: startMinute + 50,
        room: room,
      ),
      course: _course,
      date: day,
      session: 1,
    );

Assignment _assignment(DateTime due, {bool done = false}) => Assignment(
  id: 'a${due.millisecondsSinceEpoch}',
  courseId: 'c',
  title: 'Report',
  dueDate: due,
  isCompleted: done,
  createdAt: DateTime(2026),
);

List<PlannedReminder> _plan({
  ReminderSettings settings = const ReminderSettings(
    classes: true,
    deadlines: true,
  ),
  List<ClassOccurrence> classes = const [],
  List<Assignment> assignments = const [],
  List<Exam> exams = const [],
  required DateTime now,
}) => planReminders(
  settings: settings,
  upcomingClasses: classes,
  assignments: assignments,
  exams: exams,
  courses: {'c': _course},
  courseRoute: (id) => '/semester/$id',
  routineRoute: '/routine',
  studyRoute: '/study',
  now: now,
);

void main() {
  final now = DateTime(2026, 11, 23, 7, 0);
  final today = DateTime(2026, 11, 23);

  test('nothing is planned while both kinds are off', () {
    expect(
      _plan(
        settings: const ReminderSettings(),
        classes: [_class(today, 600)],
        assignments: [_assignment(DateTime(2026, 11, 25, 23, 59))],
        now: now,
      ),
      isEmpty,
    );
  });

  test('a class is reminded the lead time before it starts', () {
    final plan = _plan(
      classes: [_class(today, 600, room: 'Room 301')],
      now: now,
    );
    expect(plan.single.at, DateTime(2026, 11, 23, 9, 45));
    expect(plan.single.title, 'CSE2100 in 15 minutes');
    expect(plan.single.body, '10:00 AM  ·  Room 301');
    expect(plan.single.route, '/routine');
  });

  test('a class whose reminder time has passed is skipped', () {
    expect(_plan(classes: [_class(today, 430)], now: now), isEmpty);
  });

  test('a lead time can reach back into the previous evening', () {
    final plan = _plan(
      settings: const ReminderSettings(classes: true, classLeadMinutes: 30),
      classes: [_class(DateTime(2026, 11, 24), 10)],
      now: now,
    );
    expect(plan.single.at, DateTime(2026, 11, 23, 23, 40));
  });

  test('deadlines get a day-before and an hour-before reminder', () {
    final due = DateTime(2026, 11, 25, 23, 59);
    final plan = _plan(assignments: [_assignment(due)], now: now);
    expect(plan.map((r) => r.at), [
      due.subtract(const Duration(days: 1)),
      due.subtract(const Duration(hours: 1)),
    ]);
    expect(plan.first.route, '/semester/c');
    expect(plan.first.body, 'CSE2100: Report');
  });

  test('finished work is not reminded', () {
    expect(
      _plan(
        assignments: [_assignment(DateTime(2026, 11, 25), done: true)],
        now: now,
      ),
      isEmpty,
    );
  });

  test('an exam is reminded the evening before', () {
    final plan = _plan(
      exams: [
        Exam(
          id: 'e',
          courseId: 'c',
          title: 'CT 3',
          kind: ExamKind.ct,
          heldOn: DateTime(2026, 11, 26),
          createdAt: DateTime(2026),
        ),
      ],
      now: now,
    );
    expect(plan.single.at, DateTime(2026, 11, 25, kExamReminderHour));
    expect(plan.single.title, 'Class test tomorrow');
    expect(plan.single.route, '/study');
  });

  test('class reminders are capped, soonest first', () {
    final classes = [
      for (var day = 0; day < 7; day++)
        for (var slot = 0; slot < 6; slot++)
          _class(DateTime(2026, 11, 24 + day), 480 + slot * 60),
    ];
    final plan = _plan(classes: classes, now: now);
    expect(plan, hasLength(kMaxClassReminders));
    expect(plan.first.at, DateTime(2026, 11, 24, 7, 45));
  });
}
