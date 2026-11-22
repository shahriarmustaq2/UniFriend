import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../utils/attendance.dart';
import '../utils/gpa.dart';
import '../utils/marks.dart';
import 'attendance_providers.dart';
import 'course_providers.dart';
import 'ct_mark_providers.dart';
import 'semester_providers.dart';

/// A course's marks, part by part. Keyed by id, not by [Course]: every edit
/// produces a new object, and each would otherwise leave a provider behind.
final markSheetProvider = Provider.family<MarkSheet?, String>((ref, courseId) {
  final course = ref.watch(courseByIdProvider)[courseId];
  if (course == null) return null;
  return MarkSheet.of(
    course,
    attendance: ref.watch(attendanceSummaryForCourseProvider(courseId)),
    ct: ref.watch(ctSummaryForCourseProvider(courseId)),
  );
});

/// Where a course's grade comes from.
enum GradeSource { direct, marks, none }

class CourseGrade {
  final double? points;
  final GradeSource source;

  const CourseGrade(this.points, this.source);

  bool get isGraded => points != null;
}

/// The grade that counts: one entered directly wins, otherwise the one the
/// marks add up to once every part is known.
final courseGradeProvider = Provider.family<CourseGrade, String>((
  ref,
  courseId,
) {
  final course = ref.watch(courseByIdProvider)[courseId];
  if (course == null) return const CourseGrade(null, GradeSource.none);
  if (course.gradePoints != null) {
    return CourseGrade(course.gradePoints, GradeSource.direct);
  }
  final fromMarks = ref.watch(markSheetProvider(courseId))?.gradePoints;
  return fromMarks == null
      ? const CourseGrade(null, GradeSource.none)
      : CourseGrade(fromMarks, GradeSource.marks);
});

/// Every graded course, ready for the GPA arithmetic.
final gpaEntriesProvider = Provider<List<GpaEntry>>((ref) {
  final courses = ref.watch(courseListProvider).value ?? const <Course>[];
  final semesters = ref.watch(semesterListProvider).value ?? const [];
  final order = {for (var i = 0; i < semesters.length; i++) semesters[i].id: i};
  return [
    for (final course in courses)
      if (ref.watch(courseGradeProvider(course.id)).points case final points?)
        GpaEntry(
          semesterId: course.semesterId,
          semesterOrder: order[course.semesterId] ?? semesters.length,
          credits: course.credits,
          gradePoints: points,
          courseCode: course.code,
          courseId: course.id,
        ),
  ];
});

/// Overall CGPA, or `null` while nothing has a grade yet.
final cgpaProvider = Provider<double?>((ref) {
  return Gpa.overall(ref.watch(gpaEntriesProvider));
});

/// One result per semester, earliest first.
final semesterGpaListProvider = Provider<List<SemesterGpa>>((ref) {
  return Gpa.bySemester(ref.watch(gpaEntriesProvider));
});

/// One semester's GPA from the courses graded so far.
final semesterGpaProvider = Provider.family<double?, String?>((ref, id) {
  return ref
      .watch(semesterGpaListProvider)
      .where((s) => s.semesterId == id)
      .firstOrNull
      ?.gpa;
});

/// Credits passed so far. An F counts towards the CGPA but earns none, and a
/// retaken course earns its credits once.
final creditsEarnedProvider = Provider<double>((ref) {
  return Gpa.counted(ref.watch(gpaEntriesProvider))
      .where((entry) => entry.gradePoints > 0)
      .fold(0.0, (sum, entry) => sum + entry.credits);
});

/// Attempts of a retaken course that no longer count towards the CGPA.
final supersededCourseIdsProvider = Provider<Set<String>>((ref) {
  return Gpa.superseded(ref.watch(gpaEntriesProvider));
});

/// Running courses whose attendance has fallen under the target.
final coursesBelowAttendanceTargetProvider = Provider<List<Course>>((ref) {
  return ref
      .watch(activeCoursesProvider)
      .where(
        (c) =>
            !ref.watch(attendanceSummaryForCourseProvider(c.id)).meetsTarget(),
      )
      .toList(growable: false);
});

/// Running courses under the registration line, which need registering again.
final coursesToRegisterProvider = Provider<List<Course>>((ref) {
  return ref
      .watch(activeCoursesProvider)
      .where(
        (c) => ref.watch(attendanceSummaryForCourseProvider(c.id)).mustRegister,
      )
      .toList(growable: false);
});

/// Attendance across one semester's courses.
final semesterAttendanceProvider = Provider.family<AttendanceSummary, String?>((
  ref,
  semesterId,
) {
  var present = 0, late = 0, absent = 0;
  for (final course in ref.watch(coursesInSemesterProvider(semesterId))) {
    final s = ref.watch(attendanceSummaryForCourseProvider(course.id));
    present += s.present;
    late += s.late;
    absent += s.absent;
  }
  return AttendanceSummary(present: present, late: late, absent: absent);
});
