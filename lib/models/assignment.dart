class Assignment {
  final String id;
  final String courseId;
  final String title;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime createdAt;

  const Assignment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.dueDate,
    required this.isCompleted,
    required this.createdAt,
  });

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      title: (map['title'] as String?)?.trim() ?? '',
      dueDate: DateTime.parse(map['due_date'] as String).toLocal(),
      isCompleted: (map['is_completed'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'title': title.trim(),
    // Stored as UTC; the app always reads it back through toLocal().
    'due_date': dueDate.toUtc().toIso8601String(),
    'is_completed': isCompleted,
  };

  Assignment copyWith({String? title, DateTime? dueDate, bool? isCompleted}) {
    return Assignment(
      id: id,
      courseId: courseId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }
}
