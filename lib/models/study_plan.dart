import '../utils/date_utils.dart';
import 'row_values.dart';

/// What sort of test an exam is. The names match the check constraint on
/// `exams.kind`.
enum ExamKind {
  ct('Class test'),
  quiz('Quiz'),
  midterm('Midterm'),
  finalExam('Final'),
  viva('Viva'),
  other('Other');

  final String label;

  const ExamKind(this.label);

  String get dbName => this == finalExam ? 'final' : name;

  static ExamKind fromName(String? name) => name == 'final'
      ? finalExam
      : ExamKind.values.firstWhere((k) => k.name == name, orElse: () => other);
}

/// An upcoming test to prepare for.
class Exam {
  final String id;
  final String? courseId;
  final String title;
  final ExamKind kind;
  final DateTime heldOn;
  final DateTime createdAt;

  const Exam({
    required this.id,
    required this.courseId,
    required this.title,
    required this.kind,
    required this.heldOn,
    required this.createdAt,
  });

  factory Exam.fromMap(Map<String, dynamic> map) => Exam(
    id: map['id'] as String,
    courseId: map['course_id'] as String?,
    title: (map['title'] as String?)?.trim() ?? '',
    kind: ExamKind.fromName(map['kind'] as String?),
    heldOn: AppDate.fromDbDate(map['held_on'] as String),
    createdAt: readInstant(map['created_at']),
  );

  /// Days from today; negative once it is over.
  int daysLeft({DateTime? now}) => AppDate.daysUntil(heldOn, now: now);

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'title': title.trim(),
    'kind': kind.dbName,
    'held_on': AppDate.toDbDate(heldOn),
  };
}

/// One thing to study, planned for a day. Unfinished tasks carry over until
/// they are ticked off.
class StudyTask {
  final String id;
  final String? courseId;

  /// The exam this topic prepares for, if any.
  final String? examId;
  final String title;
  final DateTime plannedFor;
  final bool isDone;
  final DateTime createdAt;

  const StudyTask({
    required this.id,
    required this.courseId,
    required this.examId,
    required this.title,
    required this.plannedFor,
    required this.isDone,
    required this.createdAt,
  });

  factory StudyTask.fromMap(Map<String, dynamic> map) => StudyTask(
    id: map['id'] as String,
    courseId: map['course_id'] as String?,
    examId: map['exam_id'] as String?,
    title: (map['title'] as String?)?.trim() ?? '',
    plannedFor: AppDate.fromDbDate(map['planned_for'] as String),
    isDone: (map['is_done'] as bool?) ?? false,
    createdAt: readInstant(map['created_at']),
  );

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'exam_id': examId,
    'title': title.trim(),
    'planned_for': AppDate.toDbDate(plannedFor),
    'is_done': isDone,
  };

  StudyTask copyWith({bool? isDone}) => StudyTask(
    id: id,
    courseId: courseId,
    examId: examId,
    title: title,
    plannedFor: plannedFor,
    isDone: isDone ?? this.isDone,
    createdAt: createdAt,
  );
}
