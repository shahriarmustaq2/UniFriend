import '../models/attendance_record.dart';

/// The attendance share a student is expected to keep. Change it here if your
/// university sets a different minimum.
const int kAttendanceTargetPercent = 75;

/// Under this share of classes, the student has to register for the course
/// again.
const int kAttendanceRegisterBelowPercent = 50;

/// Attendance totals for one course, or across all of them.
class AttendanceSummary {
  final int present;
  final int late;
  final int absent;

  const AttendanceSummary({this.present = 0, this.late = 0, this.absent = 0});

  factory AttendanceSummary.of(Iterable<AttendanceStatus> statuses) {
    var present = 0;
    var late = 0;
    var absent = 0;
    for (final status in statuses) {
      switch (status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.cancelled:
          // A class that did not happen is not counted either way.
          break;
      }
    }
    return AttendanceSummary(present: present, late: late, absent: absent);
  }

  int get total => present + late + absent;

  /// A late arrival still counts as having attended.
  int get attended => present + late;

  /// `null` when no class has been recorded, which is different from 0%.
  double? get percent => total == 0 ? null : attended / total * 100;

  /// Under [kAttendanceRegisterBelowPercent]: the course must be registered
  /// for again. Never true before any class is recorded.
  bool get mustRegister =>
      total > 0 && attended * 100 < kAttendanceRegisterBelowPercent * total;

  bool meetsTarget([int target = kAttendanceTargetPercent]) =>
      total == 0 || attended * 100 >= target * total;

  /// Consecutive classes the student must attend to climb back to [target].
  /// Integer arithmetic, so the answer cannot be off by one from float noise.
  int classesNeeded([int target = kAttendanceTargetPercent]) {
    final shortfall = target * total - 100 * attended;
    if (shortfall <= 0) return 0;
    final step = 100 - target;
    return (shortfall + step - 1) ~/ step;
  }

  /// Classes the student can still miss and stay at or above [target].
  int canMiss([int target = kAttendanceTargetPercent]) {
    if (total == 0) return 0;
    final spare = 100 * attended - target * total;
    return spare <= 0 ? 0 : spare ~/ target;
  }
}
