import '../utils/date_utils.dart';

enum AttendanceStatus {
  present('Present', 'P'),
  late('Late', 'L'),
  absent('Absent', 'A'),

  /// The class did not happen. It counts neither for nor against attendance.
  cancelled('Cancelled', 'C');

  final String label;
  final String short;

  const AttendanceStatus(this.label, this.short);

  /// The marks a student picks for a class that took place.
  static const List<AttendanceStatus> taken = [present, late, absent];

  /// Unknown values read as absent, the choice that cannot inflate a percentage.
  static AttendanceStatus fromName(String? name) => AttendanceStatus.values
      .firstWhere((s) => s.name == name, orElse: () => AttendanceStatus.absent);
}

class AttendanceRecord {
  final String id;
  final String courseId;
  final DateTime heldOn;

  /// Separates two classes of the same course on the same day.
  final int session;
  final AttendanceStatus status;

  const AttendanceRecord({
    required this.id,
    required this.courseId,
    required this.heldOn,
    required this.session,
    required this.status,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      heldOn: AppDate.fromDbDate(map['held_on'] as String),
      session: (map['session'] as num?)?.toInt() ?? 1,
      status: AttendanceStatus.fromName(map['status'] as String?),
    );
  }

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'held_on': AppDate.toDbDate(heldOn),
    'session': session,
    'status': status.name,
  };
}
