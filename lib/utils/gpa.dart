/// Pure GPA arithmetic, kept free of Flutter and of the data layer so it can be
/// unit tested directly.
library;

/// Which attempt counts towards the CGPA when a course is taken more than once.
enum RetakePolicy { bestGrade, latestAttempt }

/// Change it here if your university counts retakes differently.
const RetakePolicy kRetakePolicy = RetakePolicy.bestGrade;

/// One graded course's contribution to a GPA calculation.
class GpaEntry {
  /// Null for a course that belongs to no semester.
  final String? semesterId;

  /// Position of the semester in time, earliest first. Decides which attempt of
  /// a retaken course is the later one, and the order of semester results.
  final int semesterOrder;
  final double credits;
  final double gradePoints;

  /// Attempts sharing a course code are one course taken more than once. Null
  /// means this entry never counts as a retake of anything.
  final String? courseCode;
  final String? courseId;

  const GpaEntry({
    this.semesterId,
    this.semesterOrder = 0,
    required this.credits,
    required this.gradePoints,
    this.courseCode,
    this.courseId,
  });
}

/// GPA for a single semester.
class SemesterGpa {
  final String? semesterId;

  /// `null` only when the graded courses add up to zero credits.
  final double? gpa;
  final int gradedCourses;
  final double totalCredits;

  const SemesterGpa({
    required this.semesterId,
    required this.gpa,
    required this.gradedCourses,
    required this.totalCredits,
  });
}

class Gpa {
  Gpa._();

  /// Credit-weighted average of [entries].
  ///
  /// Returns `null` when there is nothing to average, so callers can render a
  /// placeholder instead of a misleading 0.00. A retaken course counts once.
  static double? overall(Iterable<GpaEntry> entries) =>
      _average(counted(entries));

  /// [entries] without the attempts that a retake replaced.
  static List<GpaEntry> counted(
    Iterable<GpaEntry> entries, {
    RetakePolicy policy = kRetakePolicy,
  }) {
    final winners = <String, GpaEntry>{};
    final result = <GpaEntry>[];
    for (final entry in entries) {
      final key = entry.courseCode?.trim().toLowerCase();
      if (key == null || key.isEmpty) {
        result.add(entry);
        continue;
      }
      final current = winners[key];
      if (current == null || _replaces(entry, current, policy)) {
        winners[key] = entry;
      }
    }
    return [...result, ...winners.values];
  }

  /// Ids of the attempts left out of the CGPA, for labelling them on screen.
  static Set<String> superseded(
    Iterable<GpaEntry> entries, {
    RetakePolicy policy = kRetakePolicy,
  }) {
    final kept = counted(
      entries,
      policy: policy,
    ).map((e) => e.courseId).toSet();
    return {
      for (final entry in entries)
        if (entry.courseId != null && !kept.contains(entry.courseId))
          entry.courseId!,
    };
  }

  static bool _replaces(GpaEntry a, GpaEntry b, RetakePolicy policy) {
    final byTime = a.semesterOrder.compareTo(b.semesterOrder);
    if (policy == RetakePolicy.latestAttempt) return byTime > 0;
    // Equal grades keep the later attempt, which is the one on the transcript.
    return a.gradePoints > b.gradePoints ||
        (a.gradePoints == b.gradePoints && byTime > 0);
  }

  /// One [SemesterGpa] per semester, earliest first. Every attempt stays in its
  /// own semester's GPA, because that is what the student scored that term.
  /// Only the CGPA drops replaced attempts.
  static List<SemesterGpa> bySemester(Iterable<GpaEntry> entries) {
    final grouped = <String?, List<GpaEntry>>{};
    final order = <String?, int>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.semesterId, () => []).add(entry);
      order[entry.semesterId] = entry.semesterOrder;
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        // A course in no semester goes last.
        if (a == null) return 1;
        if (b == null) return -1;
        return order[a]!.compareTo(order[b]!);
      });
    return [
      for (final key in keys)
        SemesterGpa(
          semesterId: key,
          gpa: _average(grouped[key]!),
          gradedCourses: grouped[key]!.length,
          totalCredits: _round2(
            grouped[key]!.fold(0.0, (sum, e) => sum + e.credits),
          ),
        ),
    ];
  }

  static double? _average(Iterable<GpaEntry> entries) {
    var earned = 0.0;
    var credits = 0.0;
    for (final entry in entries) {
      earned += entry.gradePoints * entry.credits;
      credits += entry.credits;
    }
    if (credits == 0) return null;
    return _round2(earned / credits);
  }

  /// Rounds to the two decimals a transcript shows.
  static double _round2(double value) => (value * 100).roundToDouble() / 100;
}
