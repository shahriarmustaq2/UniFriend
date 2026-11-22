import '../utils/date_utils.dart';
import 'row_values.dart';

/// One repeating class in the routine.
class ClassSlot {
  final String id;
  final String courseId;

  /// 1 = Monday ... 7 = Sunday, the same numbering as [DateTime.weekday].
  final int weekday;

  /// Minutes after midnight. A class time is a wall clock, not an instant, so
  /// it never goes through a time zone conversion.
  final int startMinute;
  final int endMinute;
  final String? room;

  /// 1 for every week, 2 for a class held every other week, such as a 0.75
  /// credit sessional.
  final int repeatWeeks;

  /// For a class every other week: the date of one class it really had, from
  /// which the rhythm is counted. Vacation weeks do not count.
  final DateTime? anchorDate;

  const ClassSlot({
    required this.id,
    required this.courseId,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.room,
    this.repeatWeeks = 1,
    this.anchorDate,
  });

  factory ClassSlot.fromMap(Map<String, dynamic> map) {
    return ClassSlot(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      weekday: (map['weekday'] as num).toInt(),
      startMinute: (map['start_minute'] as num).toInt(),
      endMinute: (map['end_minute'] as num).toInt(),
      room: readText(map['room']),
      repeatWeeks: (map['repeat_weeks'] as num?)?.toInt() ?? 1,
      anchorDate: readDate(map['anchor_date']),
    );
  }

  bool get isAlternate => repeatWeeks == 2;

  int get durationMinutes => endMinute - startMinute;

  String get timeLabel =>
      '${AppDate.minuteOfDay(startMinute)} – ${AppDate.minuteOfDay(endMinute % 1440)}';

  /// Two alternate-week classes can share a time without clashing, since they
  /// may fall in different weeks. The warning stays, since they might not.
  bool overlaps(ClassSlot other) =>
      weekday == other.weekday &&
      startMinute < other.endMinute &&
      other.startMinute < endMinute;

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'weekday': weekday,
    'start_minute': startMinute,
    'end_minute': endMinute,
    'room': room,
    'repeat_weeks': repeatWeeks,
    'anchor_date': isAlternate ? writeDate(anchorDate) : null,
  };
}
