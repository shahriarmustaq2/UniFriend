import 'dart:math' as math;

import '../models/ct_mark.dart';

/// How many of a course's class tests count towards its result. Many
/// universities count the best few, so this is shown next to the plain average.
const int kCtBestCount = 3;

/// Class test performance for one course, or across all of them.
class CtSummary {
  final int count;

  /// Percentages rather than raw marks, so a CT out of 15 and one out of 20
  /// weigh the same. `null` when there are no marks yet.
  final double? averagePercent;
  final double? bestAveragePercent;
  final double? highestPercent;

  const CtSummary({
    this.count = 0,
    this.averagePercent,
    this.bestAveragePercent,
    this.highestPercent,
  });

  factory CtSummary.of(Iterable<CtMark> marks, {int best = kCtBestCount}) {
    final percents = marks.map((m) => m.percent).toList()
      ..sort((a, b) => b.compareTo(a));
    if (percents.isEmpty) return const CtSummary();

    double mean(Iterable<double> values) =>
        values.reduce((a, b) => a + b) / values.length;

    return CtSummary(
      count: percents.length,
      averagePercent: mean(percents),
      bestAveragePercent: mean(percents.take(math.max(best, 1))),
      highestPercent: percents.first,
    );
  }
}
