import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/course_providers.dart';
import '../../providers/results_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/grades.dart';
import '../../utils/marks.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Enters one part of a course's marks. The mark can be typed as it was
/// given, such as 150 out of 210, and is scaled to the part's share.
Future<void> showMarkEntry(
  BuildContext context, {
  required Course course,
  required MarkPart part,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _MarkEntrySheet(course: course, part: part),
  );
}

class _MarkEntrySheet extends ConsumerStatefulWidget {
  final Course course;
  final MarkPart part;

  const _MarkEntrySheet({required this.course, required this.part});

  @override
  ConsumerState<_MarkEntrySheet> createState() => _MarkEntrySheetState();
}

class _MarkEntrySheetState extends ConsumerState<_MarkEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final double _weight = kMarkScheme[widget.course.kind]!
      .firstWhere((s) => s.part == widget.part)
      .weight;
  late final TextEditingController _obtained = TextEditingController(
    text: widget.course.marks[widget.part.key] == null
        ? ''
        : formatMark(widget.course.marks[widget.part.key]!),
  );
  late final TextEditingController _outOf = TextEditingController(
    text: formatMark(_weight),
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _obtained.dispose();
    _outOf.dispose();
    super.dispose();
  }

  double? get _scaled {
    final obtained = double.tryParse(_obtained.text.trim());
    final outOf = double.tryParse(_outOf.text.trim());
    if (obtained == null || outOf == null || outOf <= 0) return null;
    return roundMark(obtained / outOf * _weight);
  }

  Future<void> _run(double? value) async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await ref
          .read(courseListProvider.notifier)
          .setMark(widget.course.id, widget.part, value);
      navigator.pop();
    });
    if (mounted) setState(() => _isSaving = false);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _run(_scaled);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = ref.watch(markSheetProvider(widget.course.id));
    final line = sheet?.lines.where((l) => l.part == widget.part).firstOrNull;
    final hasEntered = widget.course.marks.containsKey(widget.part.key);
    final scaled = _scaled;

    // What the total would come to with this mark in place, and the grade
    // once nothing else is missing.
    double? projected;
    var completes = false;
    if (sheet != null && scaled != null) {
      projected = roundMark(sheet.total - (line?.value ?? 0) + scaled);
      completes = sheet.lines.every(
        (l) => l.part == widget.part || l.value != null,
      );
    }

    return GlassSheet(
      title: '${widget.course.code}  ·  ${widget.part.label}',
      actions: [
        if (hasEntered)
          SheetAction(
            label: line?.canAuto == true ? 'Use auto' : 'Clear',
            icon: line?.canAuto == true
                ? Icons.auto_fix_high_rounded
                : Icons.backspace_outlined,
            isSecondary: true,
            onPressed: _isSaving ? null : () => _run(null),
          ),
        SheetAction(label: 'Save', onPressed: _save, isBusy: _isSaving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: GlassTextField(
                    controller: _obtained,
                    label: 'Marks',
                    icon: Icons.edit_rounded,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final obtained = double.tryParse((v ?? '').trim());
                      final outOf = double.tryParse(_outOf.text.trim());
                      if (obtained == null) return 'Enter a number';
                      if (outOf != null && obtained > outOf) {
                        return 'More than the total';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GlassTextField(
                    controller: _outOf,
                    label: 'Out of',
                    icon: Icons.percent_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final outOf = double.tryParse((v ?? '').trim());
                      if (outOf == null || outOf <= 0) return 'Above 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassContainer(
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(
                    label: 'Counts as',
                    value: scaled == null
                        ? '— of ${formatMark(_weight)}'
                        : '${formatMark(scaled)} of ${formatMark(_weight)}',
                  ),
                  if (line?.suggested != null)
                    _InfoLine(
                      label: widget.part == MarkPart.attendance
                          ? 'From attendance'
                          : 'From best 3 CTs',
                      value: formatMark(line!.suggested!),
                      color: AppColors.cyan,
                    ),
                  if (projected != null)
                    _InfoLine(
                      label: completes ? 'Total and grade' : 'Total so far',
                      value: completes
                          ? '${formatMark(projected)}  ·  '
                                '${gradeLetter(gradePointsForMarks(projected))}'
                          : formatMark(projected),
                      color: AppColors.success,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoLine({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
