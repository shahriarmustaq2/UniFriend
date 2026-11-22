/// Matches the column default on `profiles.weekly_study_goal_minutes`.
const int kDefaultWeeklyStudyGoalMinutes = 600;

class Profile {
  final String id;
  final String? fullName;
  final DateTime createdAt;

  /// Study target for one week, in minutes.
  final int weeklyStudyGoalMinutes;

  /// Spending limit for one month. Null until the student sets one.
  final double? monthlyBudget;

  /// The semester the student is in now, chosen in Profile.
  final String? currentSemesterId;

  const Profile({
    required this.id,
    required this.fullName,
    required this.createdAt,
    this.weeklyStudyGoalMinutes = kDefaultWeeklyStudyGoalMinutes,
    this.monthlyBudget,
    this.currentSemesterId,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      weeklyStudyGoalMinutes:
          (map['weekly_study_goal_minutes'] as num?)?.toInt() ??
          kDefaultWeeklyStudyGoalMinutes,
      monthlyBudget: (map['monthly_budget'] as num?)?.toDouble(),
      currentSemesterId: map['current_semester_id'] as String?,
    );
  }

  /// Falls back to the auth metadata name, then the email local-part, so the
  /// header always has something to render even for a half-populated row.
  String displayName({String? authName, String? email}) => resolveDisplayName(
    profileName: fullName,
    authName: authName,
    email: email,
  );

  String initial({String? authName, String? email}) {
    final name = displayName(authName: authName, email: email);
    return name.isEmpty ? 'S' : name[0].toUpperCase();
  }
}

/// Single source of truth for "what should the app call this student", so the
/// header, the profile tab and the login greeting can never disagree.
String resolveDisplayName({
  String? profileName,
  String? authName,
  String? email,
}) {
  for (final candidate in [profileName, authName]) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  final local = email?.split('@').first.trim();
  if (local != null && local.isNotEmpty) return local;
  return 'Student';
}
