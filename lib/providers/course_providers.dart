import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/course.dart';
import '../utils/date_utils.dart';
import '../utils/marks.dart';
import 'assignment_providers.dart';
import 'attendance_providers.dart';
import 'ct_mark_providers.dart';
import 'personal_list_notifier.dart';
import 'routine_providers.dart';
import 'semester_providers.dart';
import 'study_providers.dart';

final courseListProvider =
    AsyncNotifierProvider<CourseListNotifier, List<Course>>(
      CourseListNotifier.new,
    );

class CourseListNotifier extends PersonalListNotifier<Course> {
  @override
  TableSpec<Course> get spec => Tables.courses;

  /// By code, so a semester's courses read in timetable order.
  @override
  int compare(Course a, Course b) {
    final byCode = a.code.toLowerCase().compareTo(b.code.toLowerCase());
    return byCode != 0 ? byCode : a.createdAt.compareTo(b.createdAt);
  }

  /// Passing `null` goes back to working the grade out from the marks.
  Future<void> setGrade(String courseId, double? gradePoints) =>
      patch(courseId, {'grade_points': gradePoints});

  /// Records one part of the marks. Passing `null` clears it, which lets the
  /// app fill in attendance and CT marks by itself again.
  Future<void> setMark(String courseId, MarkPart part, double? value) async {
    final course = byId(courseId);
    if (course == null) return;
    final marks = {...course.marks};
    if (value == null) {
      marks.remove(part.key);
    } else {
      marks[part.key] = roundMark(value);
    }
    await patch(courseId, {'marks': marks});
  }

  /// Marks the course's classes as over from [on], or reopens them with null.
  Future<void> setClassesEnded(String courseId, DateTime? on) => patch(
    courseId,
    {'classes_ended_on': on == null ? null : AppDate.toDbDate(on)},
  );

  /// Deleting a course cascades in Postgres to everything that belongs to it,
  /// and detaches its study records, so those lists have to be reloaded too.
  Future<void> remove(String courseId) async {
    await delete(courseId);
    invalidateCourseData(ref, includeCourses: false);
  }
}

/// Reloads every list that hangs off a course, after the database changed
/// them by itself (a cascade or a cleared link).
void invalidateCourseData(Ref ref, {bool includeCourses = true}) {
  if (includeCourses) ref.invalidate(courseListProvider);
  ref
    ..invalidate(assignmentListProvider)
    ..invalidate(classSlotListProvider)
    ..invalidate(attendanceListProvider)
    ..invalidate(ctMarkListProvider)
    ..invalidate(studySessionListProvider)
    ..invalidate(studyTaskListProvider)
    ..invalidate(examListProvider);
}

final courseByIdProvider = Provider<Map<String, Course>>((ref) {
  final courses = ref.watch(courseListProvider).value ?? const <Course>[];
  return {for (final course in courses) course.id: course};
});

/// One semester's courses, by code. Null gathers the courses in no semester.
final coursesInSemesterProvider = Provider.family<List<Course>, String?>((
  ref,
  semesterId,
) {
  final courses = ref.watch(courseListProvider).value ?? const <Course>[];
  return courses
      .where((c) => c.semesterId == semesterId)
      .toList(growable: false);
});

/// Courses whose classes are still running: those in the current semester
/// that have not been marked as ended. With no semesters set up yet, every
/// unfinished course counts.
final activeCoursesProvider = Provider<List<Course>>((ref) {
  final courses = ref.watch(courseListProvider).value ?? const <Course>[];
  final current = ref.watch(currentSemesterProvider);
  if (current != null && current.hasEnded) return const [];
  return courses
      .where((c) => c.classesEndedOn == null)
      .where((c) => current == null || c.semesterId == current.id)
      .toList(growable: false);
});
