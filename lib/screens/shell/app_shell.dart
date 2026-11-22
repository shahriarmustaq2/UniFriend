import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';
import '../../providers/semester_providers.dart';
import '../../providers/sync_providers.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';
import 'nav_item.dart';

/// Tab metadata. Kept in one list so the header, the nav bar and the tab index
/// can never drift apart.
class AppTab {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData activeIcon;

  const AppTab({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeIcon,
  });
}

const List<AppTab> kAppTabs = [
  AppTab(
    label: 'Today',
    title: 'Today',
    subtitle: '',
    icon: Icons.wb_twilight_outlined,
    activeIcon: Icons.wb_twilight_rounded,
  ),
  AppTab(
    label: 'Routine',
    title: 'Routine',
    subtitle: 'Your week, class by class',
    icon: Icons.calendar_view_week_outlined,
    activeIcon: Icons.calendar_view_week_rounded,
  ),
  AppTab(
    label: 'Semester',
    title: 'Semester',
    subtitle: 'Courses, marks and results',
    icon: Icons.school_outlined,
    activeIcon: Icons.school_rounded,
  ),
  AppTab(
    label: 'Study',
    title: 'Study',
    subtitle: 'Plan, exams and focus time',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories_rounded,
  ),
  AppTab(
    label: 'More',
    title: 'More',
    subtitle: 'Expenses, notices and account',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
  ),
];

/// Titles for the pages inside a tab, as (title, subtitle). Anything under
/// /semester that is not listed here is a course page.
const Map<String, (String, String)> _kInnerPages = {
  AppRoutes.marks: ('Marks', 'Enter marks or a grade for each course'),
  AppRoutes.results: ('Results', 'Grades, semester GPA and CGPA'),
  AppRoutes.attendance: ('Attendance', 'Percentages and what you can miss'),
  AppRoutes.ctMarks: ('CT marks', 'Class test results by course'),
  AppRoutes.semesters: ('Semesters', 'Terms, start dates and vacations'),
  AppRoutes.profileSemesters: ('Semesters', 'Terms, start dates and vacations'),
  AppRoutes.expenses: ('Expenses', 'Where your money goes'),
  AppRoutes.notices: ('Notices', 'Reminders to yourself'),
  AppRoutes.profile: ('Profile', 'Your account and semester'),
  AppRoutes.reminders: ('Reminders', 'Notifications on this device'),
};

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  /// The current path, which decides between a tab header and an inner page's.
  final String location;

  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  int get _index => navigationShell.currentIndex;

  bool get _isTabRoot =>
      location == AppRoutes.home ||
      AppRoutes.parentOf(location) == AppRoutes.home;

  @override
  Widget build(BuildContext context) {
    // The background sits behind the whole Scaffold, so the nav bar is glass
    // over it while the body, and each page's add button, stay above the bar.
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _isTabRoot
                  ? _TabHeader(tab: kAppTabs[_index], isToday: _index == 0)
                  : _InnerPageHeader(location: location),
              const _OfflineBanner(),
              Expanded(
                child: navigationShell.animate().fadeIn(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  void _onTabTapped(int index) {
    // Tapping the tab you are already on pops that branch back to its root,
    // which is what every other mobile app does.
    navigationShell.goBranch(index, initialLocation: index == _index);
  }

  Widget _buildNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassContainer(
          frosted: true,
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          tint: AppColors.surfaceRaised,
          opacity: 0.78,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < kAppTabs.length; i++)
                NavItem(
                  tab: kAppTabs[i],
                  isActive: _index == i,
                  onTap: () => _onTabTapped(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says so when the app is showing its saved copy, so nobody mistakes what is
/// on screen for the latest, or expects a change to save.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offlineProvider)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 15, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline. Showing what was last saved; changes need a connection.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back button and title for a page inside a tab. The back button matters: the
/// bottom bar alone gives no hint that this page has a parent.
class _InnerPageHeader extends StatelessWidget {
  final String location;

  const _InnerPageHeader({required this.location});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) =
        _kInnerPages[location] ?? ('Course', 'Everything about this course');

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.go(AppRoutes.parentOf(location)),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _HeaderText(title: title, subtitle: subtitle),
          ),
        ],
      ),
    );
  }
}

/// A greeting on Today, the tab's title elsewhere.
class _TabHeader extends ConsumerWidget {
  final AppTab tab;
  final bool isToday;

  const _TabHeader({required this.tab, required this.isToday});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(displayNameProvider).split(' ').first;
    final initial = ref.watch(displayInitialProvider);
    final term = ref.watch(semesterTodayProvider);

    final title = isToday ? '${_greeting()}, $name' : tab.title;
    final subtitle = isToday
        ? (term?.label ?? 'Add your semester in Profile')
        : tab.subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          Expanded(
            // Cross-fade so switching tabs does not jump.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: _HeaderText(
                key: ValueKey(tab.title),
                title: title,
                subtitle: subtitle,
                large: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Profile',
            child: GestureDetector(
              onTap: () => context.go(AppRoutes.profile),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.periwinkle],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.midnight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool large;

  const _HeaderText({
    super.key,
    required this.title,
    required this.subtitle,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: large ? 24 : 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
