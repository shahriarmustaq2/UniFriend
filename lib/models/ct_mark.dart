import '../utils/date_utils.dart';

/// One class test result.
class CtMark {
  final String id;
  final String courseId;
  final String title;
  final double obtained;
  final double total;
  final DateTime? heldOn;
  final DateTime createdAt;

  const CtMark({
    required this.id,
    required this.courseId,
    required this.title,
    required this.obtained,
    required this.total,
    required this.heldOn,
    required this.createdAt,
  });

  factory CtMark.fromMap(Map<String, dynamic> map) {
    final heldOn = map['held_on'] as String?;
    return CtMark(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      title: (map['title'] as String?)?.trim() ?? '',
      obtained: (map['obtained'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      heldOn: heldOn == null ? null : AppDate.fromDbDate(heldOn),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  double get percent => total == 0 ? 0 : obtained / total * 100;

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'title': title,
    'obtained': obtained,
    'total': total,
    'held_on': heldOn == null ? null : AppDate.toDbDate(heldOn!),
  };
}
