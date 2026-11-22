import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reminder_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../utils/reminder_plan.dart';
import '../../widgets/action_row.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  static const List<int> _leadOptions = [5, 10, 15, 30];

  /// Turning a reminder on is the moment to ask, when the reason is obvious.
  Future<void> _enable(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings next,
  ) async {
    final granted = await ref.read(reminderGatewayProvider).requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      showGlassSnack(
        context,
        'Notifications are off for UniFriend. Allow them in system settings.',
        icon: Icons.notifications_off_outlined,
        isError: true,
      );
      return;
    }
    ref.read(reminderSettingsProvider.notifier).save(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.watch(reminderGatewayProvider);
    final settings = ref.watch(reminderSettingsProvider);
    final count = ref.watch(plannedReminderCountProvider);
    final notifier = ref.read(reminderSettingsProvider.notifier);

    if (!gateway.isSupported) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Text(
              'Reminders work on the Android, iOS and macOS apps.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SwitchRow(
                icon: Icons.calendar_view_week_rounded,
                color: AppColors.cyan,
                label: 'Before each class',
                subtitle: 'Skips cancelled classes and vacations',
                value: settings.classes,
                onChanged: (value) => value
                    ? _enable(context, ref, settings.copyWith(classes: true))
                    : notifier.save(settings.copyWith(classes: false)),
              ),
              if (settings.classes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final minutes in _leadOptions)
                        ChoicePill(
                          label: '$minutes min',
                          selected: settings.classLeadMinutes == minutes,
                          onTap: () => notifier.save(
                            settings.copyWith(classLeadMinutes: minutes),
                          ),
                        ),
                    ],
                  ),
                ),
              const RowDivider(),
              _SwitchRow(
                icon: Icons.assignment_late_rounded,
                color: AppColors.warning,
                label: 'Deadlines and exams',
                subtitle: 'A day and an hour before work is due, and the evening before an exam',
                value: settings.deadlines,
                onChanged: (value) => value
                    ? _enable(context, ref, settings.copyWith(deadlines: true))
                    : notifier.save(settings.copyWith(deadlines: false)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${AppDate.plural(count, 'reminder')} scheduled on this device. '
            'Android may deliver them a few minutes late to save battery.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          child: ActionRow(
            icon: Icons.notifications_active_outlined,
            label: 'Send a test notification',
            onTap: () async {
              final granted = await gateway.requestPermission();
              if (granted) await gateway.showTest();
            },
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.cyan,
          ),
        ],
      ),
    );
  }
}
