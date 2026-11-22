import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/ct_mark.dart';
import '../utils/ct_summary.dart';
import 'personal_list_notifier.dart';

final ctMarkListProvider =
    AsyncNotifierProvider<CtMarkListNotifier, List<CtMark>>(
      CtMarkListNotifier.new,
    );

class CtMarkListNotifier extends PersonalListNotifier<CtMark> {
  @override
  TableSpec<CtMark> get spec => Tables.ctMarks;

  /// Oldest first, so CT 1 reads above CT 2.
  @override
  int compare(CtMark a, CtMark b) => a.createdAt.compareTo(b.createdAt);
}

final ctMarksForCourseProvider = Provider.family<List<CtMark>, String>((
  ref,
  courseId,
) {
  final all = ref.watch(ctMarkListProvider).value ?? const <CtMark>[];
  return all.where((m) => m.courseId == courseId).toList(growable: false);
});

final ctSummaryForCourseProvider = Provider.family<CtSummary, String>((
  ref,
  courseId,
) {
  return CtSummary.of(ref.watch(ctMarksForCourseProvider(courseId)));
});
