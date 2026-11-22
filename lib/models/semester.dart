import '../utils/date_utils.dart';
import 'row_values.dart';

/// One term, such as "Level 2 Term 1". Courses belong to a semester, and its
/// start date is what week numbers count from.
class Semester {
  final String id;
  final String name;
  final DateTime startsOn;

  /// The last day of classes, once the student marks them as ended. Results can
  /// still be entered afterwards.
  final DateTime? classesEndedOn;
  final DateTime createdAt;

  const Semester({
    required this.id,
    required this.name,
    required this.startsOn,
    this.classesEndedOn,
    required this.createdAt,
  });

  factory Semester.fromMap(Map<String, dynamic> map) => Semester(
    id: map['id'] as String,
    name: (map['name'] as String?)?.trim() ?? '',
    startsOn: AppDate.fromDbDate(map['starts_on'] as String),
    classesEndedOn: readDate(map['classes_ended_on']),
    createdAt: readInstant(map['created_at']),
  );

  /// Whether classes are still running on [day].
  bool runsOn(DateTime day) {
    final d = AppDate.dayOf(day);
    if (d.isBefore(startsOn)) return false;
    final ended = classesEndedOn;
    return ended == null || !d.isAfter(ended);
  }

  bool get hasEnded => classesEndedOn != null;

  Map<String, dynamic> toRow() => {
    'name': name.trim(),
    'starts_on': AppDate.toDbDate(startsOn),
    'classes_ended_on': writeDate(classesEndedOn),
  };

  Semester copyWith({
    String? name,
    DateTime? startsOn,
    Object? classesEndedOn = unset,
  }) => Semester(
    id: id,
    name: name ?? this.name,
    startsOn: startsOn ?? this.startsOn,
    classesEndedOn: identical(classesEndedOn, unset)
        ? this.classesEndedOn
        : classesEndedOn as DateTime?,
    createdAt: createdAt,
  );
}

/// A break inside a semester. No classes happen, and a week spent wholly on
/// vacation does not count towards the week number.
class Vacation {
  final String id;
  final String semesterId;
  final String title;
  final DateTime startsOn;
  final DateTime endsOn;

  const Vacation({
    required this.id,
    required this.semesterId,
    required this.title,
    required this.startsOn,
    required this.endsOn,
  });

  factory Vacation.fromMap(Map<String, dynamic> map) => Vacation(
    id: map['id'] as String,
    semesterId: map['semester_id'] as String,
    title: (map['title'] as String?)?.trim() ?? '',
    startsOn: AppDate.fromDbDate(map['starts_on'] as String),
    endsOn: AppDate.fromDbDate(map['ends_on'] as String),
  );

  bool covers(DateTime day) {
    final d = AppDate.dayOf(day);
    return !d.isBefore(startsOn) && !d.isAfter(endsOn);
  }

  int get days => AppDate.daysUntil(endsOn, now: startsOn) + 1;

  Map<String, dynamic> toRow() => {
    'semester_id': semesterId,
    'title': title.trim(),
    'starts_on': AppDate.toDbDate(startsOn),
    'ends_on': AppDate.toDbDate(endsOn),
  };
}
