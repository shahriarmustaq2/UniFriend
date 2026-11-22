import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers/expense_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Quick add: an amount and a category is all it takes. Pass [expense] to edit.
Future<void> showExpenseEditor(BuildContext context, {Expense? expense}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _ExpenseEditorSheet(expense: expense),
  );
}

class _ExpenseEditorSheet extends ConsumerStatefulWidget {
  final Expense? expense;

  const _ExpenseEditorSheet({this.expense});

  @override
  ConsumerState<_ExpenseEditorSheet> createState() =>
      _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends ConsumerState<_ExpenseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : widget.expense!.amount
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'\.?0+$'), ''),
  );
  late final TextEditingController _title = TextEditingController(
    // A title that only repeats the category was filled in for the student,
    // so it is left out of the field.
    text: widget.expense?.title == widget.expense?.category.label
        ? ''
        : widget.expense?.title ?? '',
  );
  late ExpenseCategory _category =
      widget.expense?.category ?? ExpenseCategory.food;
  late DateTime _spentOn =
      widget.expense?.spentOn ?? AppDate.dayOf(DateTime.now());
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final notifier = ref.read(expenseListProvider.notifier);
    final navigator = Navigator.of(context);
    final title = _title.text.trim();
    final draft = Expense(
      id: widget.expense?.id ?? '',
      title: title.isEmpty ? _category.label : title,
      amount: double.parse(_amount.text.trim()),
      category: _category,
      spentOn: _spentOn,
      note: widget.expense?.note,
      createdAt: widget.expense?.createdAt ?? DateTime.now(),
    );

    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(draft);
      } else {
        await notifier.insert(draft);
      }
      navigator.pop();
    });
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    final notifier = ref.read(expenseListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.expense!.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = AppDate.dayOf(DateTime.now());
    final yesterday = AppDate.addDays(today, -1);
    final otherDay = _spentOn != today && _spentOn != yesterday;

    return GlassSheet(
      title: _isEditing ? 'Edit expense' : 'Add expense',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Add',
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _amount,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: AppTheme.tabular,
              ),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: '$kCurrencySymbol ',
                prefixStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: TextStyle(fontSize: 34, color: AppColors.textHint),
              ),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) return 'Enter an amount';
                if (amount >= 100000000) return 'That is too large';
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final category in ExpenseCategory.values)
                  ChoicePill(
                    label: category.label,
                    icon: category.icon,
                    color: category.color,
                    selected: category == _category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GlassTextField(
              controller: _title,
              label: 'What for (optional)',
              icon: Icons.short_text_rounded,
              hintText: _category.label,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoicePill(
                  label: 'Today',
                  selected: _spentOn == today,
                  onTap: () => setState(() => _spentOn = today),
                ),
                ChoicePill(
                  label: 'Yesterday',
                  selected: _spentOn == yesterday,
                  onTap: () => setState(() => _spentOn = yesterday),
                ),
                ChoicePill(
                  label: otherDay
                      ? AppDate.weekdayDayMonth(_spentOn)
                      : 'Pick a day',
                  icon: Icons.event_rounded,
                  selected: otherDay,
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context,
                      initialDate: _spentOn,
                    );
                    if (picked != null) {
                      setState(() => _spentOn = AppDate.dayOf(picked));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
