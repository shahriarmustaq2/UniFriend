import 'package:flutter/material.dart';

import '../models/ct_mark.dart';
import '../theme/app_colors.dart';
import '../utils/ct_summary.dart';
import 'glass_container.dart';
import 'meter_bar.dart';

Color ctColor(double? percent) {
  if (percent == null) return AppColors.textSecondary;
  if (percent >= 70) return AppColors.success;
  if (percent >= 50) return AppColors.warning;
  return AppColors.error;
}

String ctNumber(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// One course's class tests: the averages, then each test.
class CtCourseCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<CtMark> marks;
  final ValueChanged<CtMark> onTapMark;

  const CtCourseCard({
    super.key,
    required this.title,
    required this.marks,
    required this.onTapMark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final summary = CtSummary.of(marks);
    final average = summary.averagePercent;

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                average == null ? '--' : '${average.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ctColor(average),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MeterBar(fraction: (average ?? 0) / 100, color: ctColor(average)),
          if (summary.count > kCtBestCount) ...[
            const SizedBox(height: 8),
            Text(
              'Best $kCtBestCount average: '
              '${summary.bestAveragePercent!.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 6),
          for (final mark in marks)
            GestureDetector(
              onTap: () => onTapMark(mark),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        mark.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Text(
                      '${ctNumber(mark.obtained)} / ${ctNumber(mark.total)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ctColor(mark.percent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
