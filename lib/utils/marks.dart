import '../models/course.dart';
import 'attendance.dart';
import 'ct_summary.dart';
import 'grades.dart';

/// One part of a course's 100 marks.
enum MarkPart {
  attendance('attendance', 'Attendance'),
  ct('ct', 'Class tests'),
  assignment('assignment', 'Assignments'),
  finalExam('final', 'Final exam'),
  quiz('quiz', 'Quiz'),
  performance('performance', 'Lab performance'),
  viva('viva', 'Viva');

  /// The key in `courses.marks`.
  final String key;
  final String label;

  const MarkPart(this.key, this.label);
}

/// A part and its share of the 100 marks.
typedef MarkShare = ({MarkPart part, double weight});

/// How each kind of course divides its 100 marks. Change the numbers here if
/// your university divides them differently.
///
/// Theory: 10 attendance, 20 class tests, 10 assignments, 60 final exam.
/// Sessional: 75 for the lab (20 quiz, 10 attendance, 45 performance) and 25
/// for the viva at the end.
const Map<CourseKind, List<MarkShare>> kMarkScheme = {
  CourseKind.theory: [
    (part: MarkPart.attendance, weight: 10),
    (part: MarkPart.ct, weight: 20),
    (part: MarkPart.assignment, weight: 10),
    (part: MarkPart.finalExam, weight: 60),
  ],
  CourseKind.sessional: [
    (part: MarkPart.quiz, weight: 20),
    (part: MarkPart.attendance, weight: 10),
    (part: MarkPart.performance, weight: 45),
    (part: MarkPart.viva, weight: 25),
  ],
};

/// Where a part's number came from.
enum MarkSource {
  /// Typed in by the student.
  entered,

  /// Worked out from attendance or CT marks already recorded.
  auto,

  /// Not known yet.
  missing,
}

class MarkLine {
  final MarkPart part;
  final double weight;
  final double? value;
  final MarkSource source;

  /// What the app would fill in by itself, shown even when overridden.
  final double? suggested;

  const MarkLine({
    required this.part,
    required this.weight,
    required this.value,
    required this.source,
    this.suggested,
  });

  /// Whether this part can be worked out from other records.
  bool get canAuto => part == MarkPart.attendance || part == MarkPart.ct;
}

/// A course's marks, part by part, and the grade they add up to.
class MarkSheet {
  final CourseKind kind;
  final List<MarkLine> lines;

  const MarkSheet({required this.kind, required this.lines});

  /// Builds the sheet for [course]. Attendance marks follow the attendance
  /// percentage, and CT marks the best-[kCtBestCount] average, unless the
  /// student has typed in their own number.
  factory MarkSheet.of(
    Course course, {
    required AttendanceSummary attendance,
    required CtSummary ct,
  }) {
    final lines = <MarkLine>[];
    for (final share in kMarkScheme[course.kind]!) {
      final suggested = switch (share.part) {
        MarkPart.attendance =>
          attendance.percent == null
              ? null
              : attendanceMarks(attendance.percent!, share.weight),
        // Sessional quizzes are not class tests, so only theory borrows CTs.
        MarkPart.ct =>
          ct.bestAveragePercent == null
              ? null
              : roundMark(ct.bestAveragePercent! * share.weight / 100),
        _ => null,
      };
      final entered = course.marks[share.part.key];
      lines.add(
        MarkLine(
          part: share.part,
          weight: share.weight,
          value: entered ?? suggested,
          source: entered != null
              ? MarkSource.entered
              : suggested != null
              ? MarkSource.auto
              : MarkSource.missing,
          suggested: suggested,
        ),
      );
    }
    return MarkSheet(kind: course.kind, lines: lines);
  }

  /// Marks so far, out of 100.
  double get total =>
      roundMark(lines.fold(0.0, (sum, line) => sum + (line.value ?? 0)));

  /// The marks still to come, out of 100.
  double get outstanding =>
      lines.where((l) => l.value == null).fold(0.0, (sum, l) => sum + l.weight);

  bool get isComplete => lines.every((line) => line.value != null);

  /// The grade the marks earn, once every part is known.
  double? get gradePoints => isComplete ? gradePointsForMarks(total) : null;
}

/// Attendance marks out of 10 for each step of attendance, checked from the
/// top down: 90% and over earns 10, then one mark less for every 5% lower, down
/// to 4 at 60%. Under 60% earns nothing.
const List<(double, double)> kAttendanceMarkSteps = [
  (90, 10),
  (85, 9),
  (80, 8),
  (75, 7),
  (70, 6),
  (65, 5),
  (60, 4),
];

/// Attendance marks for a percentage, on the steps above, scaled to the
/// part's share (which is 10 for both kinds of course).
double attendanceMarks(double percent, double weight) {
  for (final (cutoff, marks) in kAttendanceMarkSteps) {
    // A hair of tolerance, so 89.999% from a division still reads as 90%.
    if (percent >= cutoff - 0.0001) return roundMark(marks * weight / 10);
  }
  return 0;
}

/// Marks are kept to two decimals.
double roundMark(double value) => (value * 100).roundToDouble() / 100;

/// "8.5", "60" or "12.25".
String formatMark(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
