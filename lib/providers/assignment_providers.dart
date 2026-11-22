import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/assignment.dart';
import 'personal_list_notifier.dart';

final assignmentListProvider =
    AsyncNotifierProvider<AssignmentListNotifier, List<Assignment>>(
      AssignmentListNotifier.new,
    );

class AssignmentListNotifier extends PersonalListNotifier<Assignment> {
  @override
  TableSpec<Assignment> get spec => Tables.assignments;

  @override
  int compare(Assignment a, Assignment b) => a.dueDate.compareTo(b.dueDate);

  Future<void> toggleCompleted(String id, bool isCompleted) =>
      patch(id, {'is_completed': isCompleted});
}

/// Open work, soonest deadline first.
final openAssignmentsProvider = Provider<List<Assignment>>((ref) {
  final all = ref.watch(assignmentListProvider).value ?? const <Assignment>[];
  return all.where((a) => !a.isCompleted).toList(growable: false);
});

/// Deadlines that have already passed.
final overdueCountProvider = Provider<int>((ref) {
  final now = DateTime.now();
  return ref
      .watch(openAssignmentsProvider)
      .where((a) => a.dueDate.isBefore(now))
      .length;
});

/// Assignments belonging to one course, soonest first.
final assignmentsForCourseProvider = Provider.family<List<Assignment>, String>((
  ref,
  courseId,
) {
  final all = ref.watch(assignmentListProvider).value ?? const <Assignment>[];
  return all.where((a) => a.courseId == courseId).toList(growable: false);
});

final openAssignmentCountForCourseProvider = Provider.family<int, String>((
  ref,
  courseId,
) {
  return ref
      .watch(assignmentsForCourseProvider(courseId))
      .where((a) => !a.isCompleted)
      .length;
});
