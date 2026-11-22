import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/assignment.dart';
import 'package:unifriend/models/attendance_record.dart';
import 'package:unifriend/models/class_slot.dart';
import 'package:unifriend/models/course.dart';
import 'package:unifriend/models/ct_mark.dart';
import 'package:unifriend/models/expense.dart';
import 'package:unifriend/models/notice.dart';
import 'package:unifriend/models/profile.dart';
import 'package:unifriend/models/semester.dart';
import 'package:unifriend/models/study_plan.dart';
import 'package:unifriend/models/study_session.dart';

void main() {
  group('Course', () {
    Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
      'id': 'c1',
      'code': ' CSE2100 ',
      'title': 'Software Engineering',
      'credits': '0.75',
      'semester_id': 's1',
      'grade_points': null,
      'created_at': '2026-03-01T10:00:00Z',
      ...extra,
    };

    test('reads credits written as text, and keeps lab credits exact', () {
      final course = Course.fromMap(row());
      expect(course.code, 'CSE2100');
      expect(course.credits, 0.75);
      expect(course.creditsLabel, '0.75');
    });

    test('defaults to a theory course with no marks', () {
      final course = Course.fromMap(row());
      expect(course.kind, CourseKind.theory);
      expect(course.marks, isEmpty);
      expect(course.classesEndedOn, isNull);
    });

    test('reads the kind, marks and end of classes', () {
      final course = Course.fromMap(
        row({
          'kind': 'sessional',
          'marks': {'quiz': 15, 'viva': '20.5', 'junk': 'x'},
          'classes_ended_on': '2026-06-30',
        }),
      );
      expect(course.isSessional, isTrue);
      expect(course.marks, {'quiz': 15.0, 'viva': 20.5});
      expect(course.classesEndedOn, DateTime(2026, 6, 30));
      expect(course.runsOn(DateTime(2026, 6, 30, 15)), isTrue);
      expect(course.runsOn(DateTime(2026, 7, 1)), isFalse);
    });

    test('falls back to 3 credits when the column is unusable', () {
      expect(Course.fromMap(row({'credits': null})).credits, 3.0);
    });

    test('toRow carries every column the table needs, but no owner or id', () {
      final course = Course.fromMap(
        row({
          'kind': 'sessional',
          'marks': {'quiz': 15},
        }),
      );
      final out = course.toRow();
      expect(out.containsKey('id'), isFalse);
      expect(out.containsKey('user_id'), isFalse);
      expect(out['kind'], 'sessional');
      expect(out['semester_id'], 's1');
      expect(out['marks'], {'quiz': 15.0});
      expect(out['classes_ended_on'], isNull);
    });

    test('copyWith can clear a nullable field and leaves others alone', () {
      final course = Course.fromMap(row({'grade_points': 3.5}));
      expect(course.copyWith(gradePoints: null).gradePoints, isNull);
      expect(course.copyWith(title: 'New').gradePoints, 3.5);
      expect(course.copyWith(title: 'New').id, 'c1');
    });
  });

  group('Semester and Vacation', () {
    test('a semester runs from its start until classes end', () {
      final semester = Semester.fromMap({
        'id': 's1',
        'name': ' Level 2 Term 1 ',
        'starts_on': '2026-07-06',
        'classes_ended_on': '2026-11-30',
        'created_at': '2026-07-01T00:00:00Z',
      });
      expect(semester.name, 'Level 2 Term 1');
      expect(semester.runsOn(DateTime(2026, 7, 5)), isFalse);
      expect(semester.runsOn(DateTime(2026, 7, 6)), isTrue);
      expect(semester.runsOn(DateTime(2026, 12, 1)), isFalse);
      expect(semester.toRow()['starts_on'], '2026-07-06');
    });

    test('a vacation covers both of its end days', () {
      final vacation = Vacation.fromMap({
        'id': 'v',
        'semester_id': 's1',
        'title': 'Eid',
        'starts_on': '2026-07-18',
        'ends_on': '2026-07-24',
      });
      expect(vacation.covers(DateTime(2026, 7, 18, 9)), isTrue);
      expect(vacation.covers(DateTime(2026, 7, 24, 23)), isTrue);
      expect(vacation.covers(DateTime(2026, 7, 25)), isFalse);
      expect(vacation.days, 7);
    });
  });

  group('Assignment.fromMap', () {
    test('converts the stored UTC deadline to local time', () {
      final assignment = Assignment.fromMap({
        'id': 'a1',
        'course_id': 'c1',
        'title': ' Lab 05 ',
        'due_date': '2026-03-15T23:59:00Z',
        'is_completed': false,
        'created_at': '2026-03-01T10:00:00Z',
      });

      expect(assignment.title, 'Lab 05');
      expect(assignment.dueDate.isUtc, isFalse);
      expect(assignment.isCompleted, isFalse);
    });

    test('writes the deadline back as UTC', () {
      final assignment = Assignment(
        id: 'a1',
        courseId: 'c1',
        title: 'Lab 05',
        dueDate: DateTime(2026, 3, 15, 23, 59),
        isCompleted: false,
        createdAt: DateTime(2026, 3, 1),
      );

      final row = assignment.toRow();
      expect(row['due_date'], endsWith('Z'));
    });

    test('defaults a missing created_at instead of throwing', () {
      final assignment = Assignment.fromMap({
        'id': 'a1',
        'course_id': 'c1',
        'title': 'Lab 05',
        'due_date': '2026-03-15T23:59:00Z',
        'is_completed': false,
        'created_at': null,
      });

      expect(assignment.createdAt, isA<DateTime>());
    });
  });

  group('Notice.fromMap', () {
    test('collapses a blank body to null', () {
      final notice = Notice.fromMap({
        'id': 'n1',
        'title': ' Library books due ',
        'body': '   ',
        'is_pinned': true,
        'created_at': '2026-03-01T10:00:00Z',
      });

      expect(notice.title, 'Library books due');
      expect(notice.body, isNull);
      expect(notice.isPinned, isTrue);
    });

    test('keeps a real body', () {
      final notice = Notice.fromMap({
        'id': 'n1',
        'title': 'Library books due',
        'body': 'Return or renew everything borrowed this term.',
        'is_pinned': false,
        'created_at': '2026-03-01T10:00:00Z',
      });

      expect(notice.body, isNotNull);
    });

    test('copyWith cannot clear the body, only the editor can', () {
      final notice = Notice(
        id: 'n1',
        title: 'Library books due',
        body: 'Return everything.',
        isPinned: false,
        createdAt: DateTime(2026, 3, 1),
      );

      expect(notice.copyWith(title: 'New title').body, 'Return everything.');
    });
  });

  group('resolveDisplayName', () {
    test('prefers the profile row over auth metadata', () {
      final name = resolveDisplayName(
        profileName: 'Shahriar M',
        authName: 'stale name',
        email: 'a@b.com',
      );

      expect(name, 'Shahriar M');
    });

    test('falls back to auth metadata when the profile is blank', () {
      final name = resolveDisplayName(
        profileName: '   ',
        authName: 'Auth Name',
        email: 'a@b.com',
      );

      expect(name, 'Auth Name');
    });

    test('falls back to the email local part', () {
      expect(resolveDisplayName(email: 'student@uni.edu'), 'student');
    });

    test('has a last resort', () {
      expect(resolveDisplayName(), 'Student');
    });
  });

  group('Profile', () {
    test('renders its initial from the resolved name', () {
      final profile = Profile(
        id: 'p1',
        fullName: 'shahriar',
        createdAt: DateTime(2026, 1, 5),
      );

      expect(profile.initial(), 'S');
    });

    test('falls back to S when there is no name at all', () {
      final profile = Profile(
        id: 'p1',
        fullName: null,
        createdAt: DateTime(2026, 1, 5),
      );

      expect(profile.initial(email: 'student@uni.edu'), 'S');
    });
  });

  group('companion models', () {
    test('ClassSlot blanks an empty room and defaults to every week', () {
      final slot = ClassSlot.fromMap({
        'id': 's',
        'course_id': 'c',
        'weekday': 1,
        'start_minute': 480,
        'end_minute': 530,
        'room': '  ',
      });
      expect(slot.room, isNull);
      expect(slot.isAlternate, isFalse);
      expect(slot.toRow()['anchor_date'], isNull);
    });

    test('an alternate-week ClassSlot keeps its anchor date', () {
      final slot = ClassSlot.fromMap({
        'id': 's',
        'course_id': 'c',
        'weekday': 1,
        'start_minute': 600,
        'end_minute': 770,
        'room': 'Lab 2',
        'repeat_weeks': 2,
        'anchor_date': '2026-07-06',
      });
      expect(slot.isAlternate, isTrue);
      expect(slot.anchorDate, DateTime(2026, 7, 6));
      expect(slot.toRow()['anchor_date'], '2026-07-06');
      expect(slot.toRow()['repeat_weeks'], 2);
    });

    test('AttendanceRecord stores a calendar day, and can be cancelled', () {
      final record = AttendanceRecord.fromMap({
        'id': 'r',
        'course_id': 'c',
        'held_on': '2026-03-15',
        'session': 2,
        'status': 'cancelled',
      });
      expect(record.heldOn, DateTime(2026, 3, 15));
      expect(record.status, AttendanceStatus.cancelled);
      expect(record.toRow()['held_on'], '2026-03-15');
      expect(
        AttendanceStatus.taken,
        isNot(contains(AttendanceStatus.cancelled)),
      );
    });

    test('CtMark computes its percentage', () {
      final mark = CtMark.fromMap({
        'id': 'm',
        'course_id': 'c',
        'title': 'CT 1',
        'obtained': 15,
        'total': 20,
        'held_on': null,
        'created_at': '2026-03-01T10:00:00Z',
      });
      expect(mark.percent, 75);
    });

    test('StudySession can stand without a course', () {
      final session = StudySession.fromMap({
        'id': 's',
        'course_id': null,
        'topic': 'Graphs',
        'minutes': 45,
        'studied_on': '2026-03-15',
        'notes': ' ',
        'created_at': '2026-03-15T10:00:00Z',
      });
      expect(session.courseId, isNull);
      expect(session.notes, isNull);
    });

    test('old expense categories read as their new home', () {
      expect(ExpenseCategory.fromName('education'), ExpenseCategory.study);
      expect(ExpenseCategory.fromName('housing'), ExpenseCategory.other);
      expect(ExpenseCategory.fromName('fun'), ExpenseCategory.other);
      expect(ExpenseCategory.fromName('food'), ExpenseCategory.food);
      expect(ExpenseCategory.fromName('nonsense'), ExpenseCategory.other);
      expect(ExpenseCategory.values, hasLength(6));
    });

    test('Profile reads its targets and current semester', () {
      final profile = Profile.fromMap({
        'id': 'p',
        'full_name': 'A',
        'created_at': '2026-01-01T00:00:00Z',
        'monthly_budget': 5000,
        'current_semester_id': 's1',
      });
      expect(profile.weeklyStudyGoalMinutes, kDefaultWeeklyStudyGoalMinutes);
      expect(profile.monthlyBudget, 5000);
      expect(profile.currentSemesterId, 's1');
    });

    test('an Exam writes "final" for a final exam', () {
      final exam = Exam.fromMap({
        'id': 'e',
        'course_id': null,
        'title': 'OS final',
        'kind': 'final',
        'held_on': '2026-12-10',
        'created_at': '2026-11-01T00:00:00Z',
      });
      expect(exam.kind, ExamKind.finalExam);
      expect(exam.toRow()['kind'], 'final');
      expect(exam.daysLeft(now: DateTime(2026, 12, 8, 22)), 2);
    });

    test('a StudyTask round-trips its plan day', () {
      final task = StudyTask.fromMap({
        'id': 't',
        'course_id': 'c',
        'exam_id': null,
        'title': 'Deadlocks',
        'planned_for': '2026-11-23',
        'is_done': false,
        'created_at': '2026-11-22T00:00:00Z',
      });
      expect(task.plannedFor, DateTime(2026, 11, 23));
      expect(task.copyWith(isDone: true).isDone, isTrue);
      expect(task.toRow()['planned_for'], '2026-11-23');
    });
  });
}
