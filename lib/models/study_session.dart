import '../utils/date_utils.dart';

class StudySession {
  final String id;

  /// Null for general study, or when the course has since been deleted.
  final String? courseId;
  final String topic;
  final int minutes;
  final DateTime studiedOn;
  final String? notes;
  final DateTime createdAt;

  const StudySession({
    required this.id,
    required this.courseId,
    required this.topic,
    required this.minutes,
    required this.studiedOn,
    required this.notes,
    required this.createdAt,
  });

  factory StudySession.fromMap(Map<String, dynamic> map) {
    final notes = (map['notes'] as String?)?.trim();
    return StudySession(
      id: map['id'] as String,
      courseId: map['course_id'] as String?,
      topic: (map['topic'] as String?)?.trim() ?? '',
      minutes: (map['minutes'] as num).toInt(),
      studiedOn: AppDate.fromDbDate(map['studied_on'] as String),
      notes: (notes == null || notes.isEmpty) ? null : notes,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'topic': topic,
    'minutes': minutes,
    'studied_on': AppDate.toDbDate(studiedOn),
    'notes': notes,
  };
}
