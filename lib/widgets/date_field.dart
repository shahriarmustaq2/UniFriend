import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'glass_container.dart';

Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
  data: Theme.of(context).copyWith(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.midnight,
      surface: AppColors.surface,
      onSurface: Colors.white,
    ),
  ),
  child: child!,
);

/// The app's date picker. The range always includes [initialDate], because the
/// picker throws when given a starting date outside its range, which is what
/// an old record being edited would otherwise be.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) {
  final now = DateTime.now();
  final first = DateTime(now.year - 6);
  final last = DateTime(now.year + 6);
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: initialDate.isBefore(first) ? initialDate : first,
    lastDate: initialDate.isAfter(last) ? initialDate : last,
    builder: _pickerTheme,
  );
}

Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: _pickerTheme,
  );
}

/// A form row that shows a date and opens the picker when tapped.
class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showAppDatePicker(context, initialDate: value);
        if (picked != null) onChanged(picked);
      },
      child: PickerBox(
        icon: Icons.event_rounded,
        label: label,
        value: AppDate.dayMonthYear(value),
      ),
    );
  }
}

/// The label-over-value box shared by the date and time pickers.
class PickerBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const PickerBox({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
