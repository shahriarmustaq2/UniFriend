import '../utils/date_utils.dart';
import 'row_values.dart';

/// Theory and sessional courses are marked differently. The names match the
/// check constraint on `courses.kind`.
enum CourseKind {
  theory('Theory'),
  sessional('Sessional');

  final String label;

  const CourseKind(this.label);

  static CourseKind fromName(String? name) => CourseKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => CourseKind.theory,
  );
}

class Course {
  final String id;
  final String code;
  final String title;
  final double credits;
  final CourseKind kind;

  /// Null only for a course created before semesters existed and never moved.
  final String? semesterId;

  /// A grade entered directly. When set it wins over the marks. 0.00 to 4.00.
  final double? gradePoints;

  /// Marks entered by hand, keyed by `MarkPart.key`, each out of that part's
  /// share of 100. Parts the app can work out itself may be left out.
  final Map<String, double> marks;

  /// The last day of classes, once the student marks the course as ended.
  final DateTime? classesEndedOn;
  final DateTime createdAt;

  const Course({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    this.kind = CourseKind.theory,
    required this.semesterId,
    this.gradePoints,
    this.marks = const {},
    this.classesEndedOn,
    required this.createdAt,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    final rawMarks = map['marks'];
    return Course(
      id: map['id'] as String,
      code: (map['code'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      credits: readDouble(map['credits']) ?? 3.0,
      kind: CourseKind.fromName(map['kind'] as String?),
      semesterId: map['semester_id'] as String?,
      gradePoints: readDouble(map['grade_points']),
      marks: {
        if (rawMarks is Map)
          for (final entry in rawMarks.entries)
            if (readDouble(entry.value) != null)
              entry.key.toString(): readDouble(entry.value)!,
      },
      classesEndedOn: readDate(map['classes_ended_on']),
      createdAt: readInstant(map['created_at']),
    );
  }

  bool get isSessional => kind == CourseKind.sessional;

  /// Whether classes are still running on [day], as far as the course itself
  /// says. Its semester can end them too.
  bool runsOn(DateTime day) {
    final ended = classesEndedOn;
    return ended == null || !AppDate.dayOf(day).isAfter(ended);
  }

  /// "3", "1.5" or "0.75", with no trailing zeros.
  String get creditsLabel => formatCredits(credits);

  static String formatCredits(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  Map<String, dynamic> toRow() => {
    'code': code.trim(),
    'title': title.trim(),
    'credits': credits,
    'kind': kind.name,
    'semester_id': semesterId,
    'grade_points': gradePoints,
    'marks': marks,
    'classes_ended_on': writeDate(classesEndedOn),
  };

  Course copyWith({
    String? code,
    String? title,
    double? credits,
    CourseKind? kind,
    Object? semesterId = unset,
    Object? gradePoints = unset,
    Map<String, double>? marks,
    Object? classesEndedOn = unset,
  }) {
    return Course(
      id: id,
      code: code ?? this.code,
      title: title ?? this.title,
      credits: credits ?? this.credits,
      kind: kind ?? this.kind,
      semesterId: identical(semesterId, unset)
          ? this.semesterId
          : semesterId as String?,
      gradePoints: identical(gradePoints, unset)
          ? this.gradePoints
          : gradePoints as double?,
      marks: marks ?? this.marks,
      classesEndedOn: identical(classesEndedOn, unset)
          ? this.classesEndedOn
          : classesEndedOn as DateTime?,
      createdAt: createdAt,
    );
  }
}
