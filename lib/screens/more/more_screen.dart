import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/action_row.dart';
import '../../widgets/glass_container.dart';

/// Everything that is not a tab of its own, one tap away.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(
      IconData icon,
      Color color,
      String label,
      String subtitle,
      String route,
    ) {
      return ActionRow(
        icon: icon,
        iconColor: color,
        label: label,
        subtitle: subtitle,
        onTap: () => context.go(route),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              row(
                Icons.account_balance_wallet_rounded,
                AppColors.orange,
                'Expenses',
                'Budget, safe daily spend, categories',
                AppRoutes.expenses,
              ),
              const RowDivider(),
              row(
                Icons.campaign_rounded,
                AppColors.blue,
                'Notices',
                'Reminders to yourself',
                AppRoutes.notices,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              row(
                Icons.workspace_premium_rounded,
                AppColors.gold,
                'Results and CGPA',
                'Every semester\'s grades',
                AppRoutes.results,
              ),
              const RowDivider(),
              row(
                Icons.fact_check_rounded,
                AppColors.green,
                'Attendance',
                'Percentages and what you can still miss',
                AppRoutes.attendance,
              ),
              const RowDivider(),
              row(
                Icons.date_range_rounded,
                AppColors.cyan,
                'Semesters and vacations',
                'Start dates, breaks, end of classes',
                AppRoutes.profileSemesters,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              row(
                Icons.notifications_rounded,
                AppColors.warning,
                'Reminders',
                'Before classes and deadlines',
                AppRoutes.reminders,
              ),
              const RowDivider(),
              row(
                Icons.person_rounded,
                AppColors.textPrimary,
                'Profile',
                'Name, current semester, password',
                AppRoutes.profile,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
