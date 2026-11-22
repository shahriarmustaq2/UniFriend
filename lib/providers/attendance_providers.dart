import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/attendance_record.dart';
import '../utils/attendance.dart';
import '../utils/date_utils.dart';
import 'personal_list_notifier.dart';

final attendanceListProvider =
    AsyncNotifierProvider<AttendanceListNotifier, List<AttendanceRecord>>(
      AttendanceListNotifier.new,
    );

class AttendanceListNotifier extends PersonalListNotifier<AttendanceRecord> {
  @override
  TableSpec<AttendanceRecord> get spec => Tables.attendance;

  /// Newest class first.
  @override
  int compare(AttendanceRecord a, AttendanceRecord b) {
    final byDay = b.heldOn.compareTo(a.heldOn);
    return byDay != 0 ? byDay : b.session.compareTo(a.session);
  }

  /// Records or corrects one class, cancelling included. Marking the same class
  /// again replaces the earlier mark, so nothing is ever counted twice.
  Future<void> mark({
    required String courseId,
    required DateTime heldOn,
    required int session,
    required AttendanceStatus status,
  }) async {
    final record = AttendanceRecord(
      id: '',
      courseId: courseId,
      heldOn: AppDate.dayOf(heldOn),
      session: session,
      status: status,
    );
    final row = await store.upsertByKey(
      spec.name,
      record.toRow(),
      keyColumns: const ['user_id', 'course_id', 'held_on', 'session'],
    );
    applyLocal(spec.decode(row));
  }

  /// The session number that adds a new class on [day] rather than overwriting
  /// one already recorded.
  int nextSession(String courseId, DateTime day) {
    final target = AppDate.dayOf(day);
    final used = (state.value ?? const <AttendanceRecord>[])
        .where((r) => r.courseId == courseId && r.heldOn == target)
        .map((r) => r.session);
    return used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;
  }
}

final attendanceForCourseProvider =
    Provider.family<List<AttendanceRecord>, String>((ref, courseId) {
      final all =
          ref.watch(attendanceListProvider).value ?? const <AttendanceRecord>[];
      return all.where((r) => r.courseId == courseId).toList(growable: false);
    });

final attendanceSummaryForCourseProvider =
    Provider.family<AttendanceSummary, String>((ref, courseId) {
      final records = ref.watch(attendanceForCourseProvider(courseId));
      return AttendanceSummary.of(records.map((r) => r.status));
    });

/// The mark already recorded for one class on one day, if any.
final attendanceRecordProvider =
    Provider.family<AttendanceRecord?, (String, DateTime, int)>((ref, key) {
      final (courseId, day, session) = key;
      final records = ref.watch(attendanceForCourseProvider(courseId));
      return records
          .where((r) => r.heldOn == day && r.session == session)
          .firstOrNull;
    });
