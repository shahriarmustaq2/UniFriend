class Notice {
  final String id;
  final String title;
  final String? body;
  final bool isPinned;
  final DateTime createdAt;

  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.createdAt,
  });

  factory Notice.fromMap(Map<String, dynamic> map) {
    final body = (map['body'] as String?)?.trim();
    return Notice(
      id: map['id'] as String,
      title: (map['title'] as String?)?.trim() ?? '',
      body: (body == null || body.isEmpty) ? null : body,
      isPinned: (map['is_pinned'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() => {
    'title': title.trim(),
    'body': body,
    'is_pinned': isPinned,
  };

  /// Only for fields that genuinely cannot be null. Use an explicit
  /// `Notice(...)` rebuild when a nullable field such as [body] may need to be
  /// cleared, so that "set to null" is never confused with "leave unchanged".
  Notice copyWith({String? title, bool? isPinned}) => Notice(
    id: id,
    title: title ?? this.title,
    body: body,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt,
  );
}
