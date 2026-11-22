import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/attendance_record.dart';
import 'package:unifriend/models/course.dart';
import 'package:unifriend/providers/assignment_providers.dart';
import 'package:unifriend/providers/attendance_providers.dart';
import 'package:unifriend/providers/core_providers.dart';
import 'package:unifriend/providers/course_providers.dart';
import 'package:unifriend/providers/ct_mark_providers.dart';
import 'package:unifriend/providers/expense_providers.dart';
import 'package:unifriend/providers/notice_providers.dart';
import 'package:unifriend/providers/reminder_providers.dart';
import 'package:unifriend/providers/results_providers.dart';
import 'package:unifriend/providers/routine_providers.dart';
import 'package:unifriend/providers/semester_providers.dart';
import 'package:unifriend/providers/study_providers.dart';
import 'package:unifriend/providers/sync_providers.dart';
import 'package:unifriend/utils/date_utils.dart';
import 'package:unifriend/utils/marks.dart';
import 'package:unifriend/utils/reminder_plan.dart';

import 'support/fakes.dart';

ProviderContainer _container(FakeBackend db) {
  // Riverpod retries failed loads for about 40 seconds by default, which would
  // keep a test waiting on a failure it set up on purpose.
  final container = ProviderContainer(
    overrides: db.overrides,
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

/// Loads every list the tests below look at.
Future<void> _load(ProviderContainer c) async {
  await Future.wait<Object?>([
    c.read(profileProvider.future),
    c.read(semesterListProvider.future),
    c.read(vacationListProvider.future),
    c.read(courseListProvider.future),
    c.read(classSlotListProvider.future),
    c.read(attendanceListProvider.future),
    c.read(ctMarkListProvider.future),
    c.read(assignmentListProvider.future),
    c.read(noticeListProvider.future),
    c.read(studySessionListProvider.future),
    c.read(studyTaskListProvider.future),
    c.read(examListProvider.future),
    c.read(expenseListProvider.future),
  ]);
}

void main() {
  setUp(resetDeviceStorage);

  final today = AppDate.dayOf(DateTime.now());

  group('switching accounts', () {
    test("the next student never sees the previous student's data", () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      await _load(c);
      expect(c.read(courseListProvider).value, hasLength(4));

      db.user = 'b';
      c.read(testUserProvider.notifier).set('b');
      expect(await c.read(courseListProvider.future), isEmpty);
      expect(await c.read(semesterListProvider.future), isEmpty);
      expect(c.read(currentSemesterProvider), isNull);
    });

    test('a running study timer does not follow the next student', () async {
      final db = FakeBackend()..user = 'a';
      final c = _container(db);
      c.read(studyTimerProvider.notifier).start();
      expect(c.read(studyTimerProvider), isNotNull);

      c.read(testUserProvider.notifier).set('b');
      expect(c.read(studyTimerProvider), isNull);
      c.read(testUserProvider.notifier).set('a');
      expect(c.read(studyTimerProvider), isNotNull);
    });
  });

  group('semesters', () {
    test('the current one is the one chosen in Profile', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);
      expect(c.read(currentSemesterProvider)?.id, seeded.semesterId);
      // It started 40 days ago, which is week 6 or 7 depending on the weekday.
      expect(c.read(semesterTodayProvider)?.week, inInclusiveRange(6, 7));
    });

    test('the first semester added becomes the current one', () async {
      final db = FakeBackend()..user = 'new';
      db.add('profiles', {'id': 'new', 'full_name': 'New'});
      final c = _container(db);
      await _load(c);

      final created = await c
          .read(semesterListProvider.notifier)
          .add(name: 'Level 1 Term 1', startsOn: today);
      expect(c.read(profileProvider).value?.currentSemesterId, created.id);
      expect(c.read(currentSemesterProvider)?.name, 'Level 1 Term 1');
    });

    test('deleting one takes its courses and their records with it', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);

      await c.read(semesterListProvider.notifier).remove(seeded.semesterId);
      await _load(c);

      expect(c.read(courseListProvider).value, hasLength(1));
      expect(c.read(classSlotListProvider).value, isEmpty);
      expect(c.read(attendanceListProvider).value, isEmpty);
      // Study records stay, detached.
      expect(c.read(studySessionListProvider).value, hasLength(1));
      expect(c.read(studySessionListProvider).value!.single.courseId, isNull);
      // The current semester falls back to the one that is left.
      expect(c.read(currentSemesterProvider)?.name, 'Level 1 Term 2');
    });
  });

  group('the routine', () {
    test('every seeded course has a class today, in time order', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      await _load(c);
      final classes = c.read(classesOnDayProvider(today));
      expect(classes.map((o) => o.course.code), [
        'CSE2100',
        'CSE2104',
        'CSE2102',
      ]);
    });

    test('the alternate-week lab skips next week', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      await _load(c);
      final next = c.read(classesOnDayProvider(AppDate.addDays(today, 7)));
      expect(next.map((o) => o.course.code), ['CSE2100', 'CSE2104']);
      final after = c.read(classesOnDayProvider(AppDate.addDays(today, 14)));
      expect(after.map((o) => o.course.code), contains('CSE2102'));
    });

    test('a vacation empties the day, and ending a course drops it', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      db.add('vacations', {
        'semester_id': seeded.semesterId,
        'title': 'Break',
        'starts_on': AppDate.toDbDate(AppDate.addDays(today, 7)),
        'ends_on': AppDate.toDbDate(AppDate.addDays(today, 7)),
      });
      final c = _container(db);
      await _load(c);
      expect(c.read(classesOnDayProvider(AppDate.addDays(today, 7))), isEmpty);

      await c
          .read(courseListProvider.notifier)
          .setClassesEnded(seeded.osId, AppDate.addDays(today, -1));
      expect(
        c.read(classesOnDayProvider(today)).map((o) => o.course.code),
        isNot(contains('CSE2104')),
      );
      expect(
        c.read(activeCoursesProvider).map((x) => x.code),
        isNot(contains('CSE2104')),
      );
    });
  });

  group('attendance', () {
    test(
      'marking the same class twice corrects it, never doubles it',
      () async {
        final db = FakeBackend()..user = 'a';
        final seeded = seed(db, 'a');
        final c = _container(db);
        await _load(c);
        final notifier = c.read(attendanceListProvider.notifier);

        for (final status in [
          AttendanceStatus.present,
          AttendanceStatus.late,
        ]) {
          await notifier.mark(
            courseId: seeded.seId,
            heldOn: today,
            session: 1,
            status: status,
          );
        }
        final records = c.read(attendanceForCourseProvider(seeded.seId));
        expect(records.where((r) => r.heldOn == today), hasLength(1));
        expect(records.first.status, AttendanceStatus.late);
      },
    );

    test('a cancelled class is kept out of the percentage', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);
      final before = c.read(attendanceSummaryForCourseProvider(seeded.seId));

      await c
          .read(attendanceListProvider.notifier)
          .mark(
            courseId: seeded.seId,
            heldOn: today,
            session: 1,
            status: AttendanceStatus.cancelled,
          );
      final after = c.read(attendanceSummaryForCourseProvider(seeded.seId));
      expect(after.total, before.total);
      expect(after.percent, before.percent);
    });

    test('a makeup class that day takes the next session', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);
      final notifier = c.read(attendanceListProvider.notifier);
      await notifier.mark(
        courseId: seeded.seId,
        heldOn: today,
        session: 1,
        status: AttendanceStatus.present,
      );
      expect(notifier.nextSession(seeded.seId, today), 2);
    });
  });

  group('marks and grades', () {
    test('attendance and CT marks fill in, the rest is entered', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);

      final sheet = c.read(markSheetProvider(seeded.seId))!;
      // 1 of 1 present: 10 of 10. CTs 13.5, 14.5, 15.5, 16.5: best three
      // average 77.5%, so 15.5 of 20. Assignment 9 was entered.
      expect(sheet.lines.map((l) => l.value), [10, 15.5, 9, null]);
      expect(c.read(courseGradeProvider(seeded.seId)).isGraded, isFalse);

      await c
          .read(courseListProvider.notifier)
          .setMark(seeded.seId, MarkPart.finalExam, 46);
      // 10 + 15.5 + 9 + 46 = 80.5: an A+.
      final grade = c.read(courseGradeProvider(seeded.seId));
      expect(grade.points, 4.0);
      expect(grade.source, GradeSource.marks);
      expect(
        db.rows('courses').firstWhere((r) => r['id'] == seeded.seId)['marks'],
        {'assignment': 9, 'final': 46.0},
      );
    });

    test(
      'a direct grade wins, and clearing it goes back to the marks',
      () async {
        final db = FakeBackend()..user = 'a';
        final seeded = seed(db, 'a');
        final c = _container(db);
        await _load(c);
        final courses = c.read(courseListProvider.notifier);

        await courses.setMark(seeded.seId, MarkPart.finalExam, 46);
        await courses.setGrade(seeded.seId, 3.0);
        expect(c.read(courseGradeProvider(seeded.seId)).points, 3.0);
        expect(
          c.read(courseGradeProvider(seeded.seId)).source,
          GradeSource.direct,
        );

        await courses.setGrade(seeded.seId, null);
        expect(c.read(courseGradeProvider(seeded.seId)).points, 4.0);
      },
    );

    test('the CGPA weighs fractional lab credits', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);
      final courses = c.read(courseListProvider.notifier);

      // CSE1101 already has 3.75 over 3 credits.
      await courses.setGrade(seeded.labId, 4.0);
      // (3 * 3.75 + 0.75 * 4.0) / 3.75 = 3.8
      expect(c.read(cgpaProvider), 3.8);
      expect(c.read(semesterGpaProvider(seeded.semesterId)), 4.0);
      expect(c.read(creditsEarnedProvider), 3.75);
    });

    test(
      'clearing an entered attendance mark goes back to the automatic one',
      () async {
        final db = FakeBackend()..user = 'a';
        final seeded = seed(db, 'a');
        final c = _container(db);
        await _load(c);
        final courses = c.read(courseListProvider.notifier);

        await courses.setMark(seeded.seId, MarkPart.attendance, 7);
        expect(c.read(markSheetProvider(seeded.seId))!.lines.first.value, 7);
        await courses.setMark(seeded.seId, MarkPart.attendance, null);
        expect(
          c.read(markSheetProvider(seeded.seId))!.lines.first.source,
          MarkSource.auto,
        );
      },
    );
  });

  group('deleting a course', () {
    test('reloads everything the database removed or detached', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);

      await c.read(courseListProvider.notifier).remove(seeded.osId);
      await _load(c);

      expect(c.read(attendanceForCourseProvider(seeded.osId)), isEmpty);
      expect(
        c.read(assignmentListProvider).value!.map((a) => a.courseId),
        isNot(contains(seeded.osId)),
      );
      expect(c.read(examListProvider).value!.single.courseId, isNull);
      expect(c.read(studyTaskListProvider).value!.single.courseId, isNull);
    });
  });

  group('the study plan', () {
    test('unfinished tasks from earlier days carry over to today', () async {
      final db = FakeBackend()..user = 'a';
      db.add('study_tasks', {
        'title': 'Left over',
        'planned_for': AppDate.toDbDate(AppDate.addDays(today, -2)),
        'is_done': false,
      });
      db.add('study_tasks', {
        'title': 'Done earlier',
        'planned_for': AppDate.toDbDate(AppDate.addDays(today, -2)),
        'is_done': true,
      });
      db.add('study_tasks', {
        'title': 'Tomorrow',
        'planned_for': AppDate.toDbDate(AppDate.addDays(today, 1)),
        'is_done': false,
      });
      final c = _container(db);
      await _load(c);

      expect(c.read(todayPlanProvider).map((t) => t.title), ['Left over']);
      expect(c.read(upcomingPlanProvider).map((t) => t.title), ['Tomorrow']);
    });

    test("an exam counts its topics, and deleting it keeps them", () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      await _load(c);
      final exam = c.read(upcomingExamsProvider).single;
      final task = c.read(todayPlanProvider).single;

      expect(c.read(examProgressProvider(exam.id)), (0, 1));
      await c.read(studyTaskListProvider.notifier).setDone(task.id, true);
      expect(c.read(examProgressProvider(exam.id)), (1, 1));

      await c.read(examListProvider.notifier).remove(exam.id);
      await _load(c);
      expect(c.read(studyTaskListProvider).value!.single.examId, isNull);
    });
  });

  group('live sync', () {
    test('a change from another device reloads just that table', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      c.listen(liveSyncProvider, (_, _) {});
      await _load(c);

      db.add('notices', {'title': 'From the laptop', 'is_pinned': false});
      final readsBefore = db.reads;
      db.feed.emit('notices', 'elsewhere');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await c.read(noticeListProvider.future);

      expect(c.read(noticeListProvider).value, hasLength(2));
      expect(db.reads - readsBefore, 1);
    });

    test('its own writes coming back do not cause a reload', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      c.listen(liveSyncProvider, (_, _) {});
      await _load(c);

      final course = c.read(courseListProvider).value!.first;
      await c.read(courseListProvider.notifier).setGrade(course.id, 3.0);
      final readsBefore = db.reads;
      db.feed.emit('courses', course.id);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(db.reads, readsBefore);
    });

    test("another student's delete does not cause a reload", () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = _container(db);
      c.listen(liveSyncProvider, (_, _) {});
      await _load(c);

      final readsBefore = db.reads;
      db.feed.emit('notices', 'not-mine', isDelete: true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(db.reads, readsBefore);
    });

    test('stops listening on sign-out', () async {
      final db = FakeBackend()..user = 'a';
      final c = _container(db);
      c.listen(liveSyncProvider, (_, _) {});
      expect(db.feed.isListening, isTrue);
      c.read(testUserProvider.notifier).set(null);
      c.read(liveSyncProvider);
      expect(db.feed.isListening, isFalse);
    });
  });

  group('reminders', () {
    Future<ProviderContainer> start(FakeBackend db) async {
      final c = _container(db);
      c
          .read(reminderSettingsProvider.notifier)
          .save(
            const ReminderSettings(
              classes: true,
              deadlines: true,
              classLeadMinutes: 5,
            ),
          );
      c.listen(reminderSyncProvider, (_, _) {});
      await _load(c);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test(
      'cover the coming days, and drop a class once it is cancelled',
      () async {
        final db = FakeBackend()..user = 'a';
        final seeded = seed(db, 'a');
        final tomorrow = AppDate.addDays(today, 1);
        db.add('class_slots', {
          'course_id': seeded.seId,
          'weekday': tomorrow.weekday,
          'start_minute': 600,
          'end_minute': 650,
          'room': null,
          'repeat_weeks': 1,
          'anchor_date': null,
        });
        final c = await start(db);
        bool remindsTomorrow() => db.reminders.scheduled.any(
          (r) =>
              r.kind == ReminderKind.classSlot &&
              r.at ==
                  DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 55),
        );
        expect(remindsTomorrow(), isTrue);

        // The seeded SE class is today's weekday, so tomorrow's is session 1.
        await c
            .read(attendanceListProvider.notifier)
            .mark(
              courseId: seeded.seId,
              heldOn: tomorrow,
              session: 1,
              status: AttendanceStatus.cancelled,
            );
        await Future<void>.delayed(Duration.zero);
        expect(remindsTomorrow(), isFalse);
      },
    );

    test('skip the off week of an alternate-week lab', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      await start(db);
      final labs = db.reminders.scheduled.where(
        (r) => r.title.startsWith('CSE2102'),
      );
      // Only today's lab can be in the next seven days; next week is off.
      expect(labs.length, lessThanOrEqualTo(1));
    });

    test('include the exam the evening before', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      await start(db);
      expect(
        db.reminders.scheduled.map((r) => r.title),
        contains('Class test tomorrow'),
      );
    });

    test('only rewrite the schedule when the plan changes', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = await start(db);
      final writes = db.reminders.writes;
      c.invalidate(noticeListProvider);
      await c.read(noticeListProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(db.reminders.writes, writes);
    });

    test('a failed load does not wipe what is already scheduled', () async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final c = await start(db);
      final scheduled = db.reminders.scheduled;
      expect(scheduled, isNotEmpty);

      db.failReads = true;
      c.invalidate(classSlotListProvider);
      await expectLater(
        c.read(classSlotListProvider.future),
        throwsA(anything),
      );
      await Future<void>.delayed(Duration.zero);
      expect(db.reminders.scheduled, same(scheduled));
    });
  });

  group('courses', () {
    test('a new course lands in the semester it was added to', () async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final c = _container(db);
      await _load(c);
      await c
          .read(courseListProvider.notifier)
          .insert(
            Course(
              id: '',
              code: 'MATH2101',
              title: 'Linear Algebra',
              credits: 3,
              semesterId: seeded.semesterId,
              createdAt: DateTime.now(),
            ),
          );
      expect(
        c.read(coursesInSemesterProvider(seeded.semesterId)).map((x) => x.code),
        contains('MATH2101'),
      );
      expect(db.rows('courses').last['user_id'], 'a');
    });
  });

  test('signing out wipes the saved copy and stops the session', () async {
    final db = FakeBackend()..user = 'a';
    seed(db, 'a');
    final c = _container(db);
    await _load(c);
    expect(
      testPrefs.getKeys().where((k) => k.startsWith('rows.a.')),
      isNotEmpty,
    );

    await c.read(signOutAction)();
    expect(db.auth.signOuts, 1);
    expect(testPrefs.getKeys().where((k) => k.startsWith('rows.a.')), isEmpty);
    unawaited(Future<void>.value());
  });
}
