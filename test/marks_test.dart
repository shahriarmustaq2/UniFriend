import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/course.dart';
import 'package:unifriend/models/ct_mark.dart';
import 'package:unifriend/utils/attendance.dart';
import 'package:unifriend/utils/ct_summary.dart';
import 'package:unifriend/utils/grades.dart';
import 'package:unifriend/utils/marks.dart';

Course _course(CourseKind kind, [Map<String, double> marks = const {}]) =>
    Course(
      id: 'c',
      code: 'CSE2101',
      title: 'Course',
      credits: kind == CourseKind.sessional ? 0.75 : 3,
      kind: kind,
      semesterId: 's',
      marks: marks,
      createdAt: DateTime(2026),
    );

CtMark _ct(double obtained) => CtMark(
  id: 'm$obtained',
  courseId: 'c',
  title: 'CT',
  obtained: obtained,
  total: 20,
  heldOn: null,
  createdAt: DateTime(2026),
);

void main() {
  group('the mark scheme', () {
    test('every kind of course adds up to 100', () {
      for (final shares in kMarkScheme.values) {
        expect(shares.fold(0.0, (sum, s) => sum + s.weight), 100);
      }
    });

    test('theory is 10 attendance, 20 CT, 10 assignment, 60 final', () {
      expect(kMarkScheme[CourseKind.theory]!.map((s) => (s.part, s.weight)), [
        (MarkPart.attendance, 10),
        (MarkPart.ct, 20),
        (MarkPart.assignment, 10),
        (MarkPart.finalExam, 60),
      ]);
    });

    test('sessional is 75 for the lab (20, 10, 45) and 25 for the viva', () {
      final shares = kMarkScheme[CourseKind.sessional]!;
      final lab = shares
          .where((s) => s.part != MarkPart.viva)
          .fold(0.0, (sum, s) => sum + s.weight);
      expect(lab, 75);
      expect(shares.map((s) => s.weight), [20, 10, 45, 25]);
    });
  });

  group('MarkSheet', () {
    const attendance = AttendanceSummary(present: 17, absent: 3); // 85%

    test('fills in attendance and CT marks by itself', () {
      final sheet = MarkSheet.of(
        _course(CourseKind.theory),
        attendance: attendance,
        // Best three of 16, 18, 14, 10 out of 20: 80% of 20 = 16.
        ct: CtSummary.of([_ct(16), _ct(18), _ct(14), _ct(10)]),
      );
      final byPart = {for (final l in sheet.lines) l.part: l};
      expect(byPart[MarkPart.attendance]!.value, 9);
      expect(byPart[MarkPart.attendance]!.source, MarkSource.auto);
      expect(byPart[MarkPart.ct]!.value, 16);
      expect(byPart[MarkPart.finalExam]!.source, MarkSource.missing);
      expect(sheet.isComplete, isFalse);
      expect(sheet.gradePoints, isNull);
      expect(sheet.outstanding, 70);
    });

    test('a typed mark wins over the worked-out one', () {
      final sheet = MarkSheet.of(
        _course(CourseKind.theory, {'attendance': 10}),
        attendance: attendance,
        ct: const CtSummary(),
      );
      final line = sheet.lines.first;
      expect(line.value, 10);
      expect(line.source, MarkSource.entered);
      expect(line.suggested, 9);
    });

    test('a complete theory sheet earns a grade', () {
      final sheet = MarkSheet.of(
        _course(CourseKind.theory, {'assignment': 9, 'final': 48}),
        attendance: attendance,
        ct: CtSummary.of([_ct(16), _ct(16), _ct(16)]),
      );
      // 9 + 16 + 9 + 48 = 82
      expect(sheet.total, 82);
      expect(sheet.isComplete, isTrue);
      expect(sheet.gradePoints, 4.0);
    });

    test('sessional quizzes do not borrow CT marks', () {
      final sheet = MarkSheet.of(
        _course(CourseKind.sessional),
        attendance: attendance,
        ct: CtSummary.of([_ct(20)]),
      );
      final quiz = sheet.lines.firstWhere((l) => l.part == MarkPart.quiz);
      expect(quiz.value, isNull);
      expect(sheet.lines.map((l) => l.part), isNot(contains(MarkPart.ct)));
    });

    test('a complete sessional sheet earns a grade', () {
      final sheet = MarkSheet.of(
        _course(CourseKind.sessional, {
          'quiz': 15,
          'performance': 36,
          'viva': 18,
        }),
        attendance: attendance,
        ct: const CtSummary(),
      );
      // 15 + 9 + 36 + 18 = 78
      expect(sheet.total, 78);
      expect(sheet.gradePoints, 3.75);
    });

    test('with no attendance recorded, attendance is missing', () {
      final sheet = MarkSheet.of(
        _course(CourseKind.theory),
        attendance: const AttendanceSummary(),
        ct: const CtSummary(),
      );
      expect(sheet.lines.first.source, MarkSource.missing);
    });
  });

  group('grades from marks', () {
    test('follow the UGC cut-offs', () {
      expect(gradePointsForMarks(100), 4.0);
      expect(gradePointsForMarks(80), 4.0);
      expect(gradePointsForMarks(79.99), 3.75);
      expect(gradePointsForMarks(75), 3.75);
      expect(gradePointsForMarks(70), 3.5);
      expect(gradePointsForMarks(65), 3.25);
      expect(gradePointsForMarks(60), 3.0);
      expect(gradePointsForMarks(55), 2.75);
      expect(gradePointsForMarks(50), 2.5);
      expect(gradePointsForMarks(45), 2.25);
      expect(gradePointsForMarks(40), 2.0);
      expect(gradePointsForMarks(39.5), 0.0);
    });

    test('rounding noise just under a cut-off still makes it', () {
      expect(gradePointsForMarks(79.999), 4.0);
    });

    test('marks to the next grade', () {
      expect(marksToNextGrade(72), 3);
      expect(marksToNextGrade(85), isNull);
      expect(marksToNextGrade(10), 30);
    });

    test('attendance marks go in steps of 5%', () {
      expect(attendanceMarks(100, 10), 10);
      expect(attendanceMarks(90, 10), 10);
      expect(attendanceMarks(89.9, 10), 9);
      expect(attendanceMarks(85, 10), 9);
      expect(attendanceMarks(80, 10), 8);
      expect(attendanceMarks(75, 10), 7);
      expect(attendanceMarks(70, 10), 6);
      expect(attendanceMarks(65, 10), 5);
      expect(attendanceMarks(60, 10), 4);
      expect(attendanceMarks(59.9, 10), 0);
      expect(attendanceMarks(30, 10), 0);
    });

    test('a two-thirds division still lands on its step', () {
      // 2 of 3 is 66.67%: the 65% step.
      expect(attendanceMarks(2 / 3 * 100, 10), 5);
      // 9 of 10 is exactly 90%.
      expect(attendanceMarks(9 / 10 * 100, 10), 10);
    });
  });
}
