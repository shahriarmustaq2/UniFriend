import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/core_providers.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/courses/course_detail_screen.dart';
import 'screens/ct_marks/ct_marks_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/notices/notice_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reminders/reminders_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/routine/routine_screen.dart';
import 'screens/semester/marks_screen.dart';
import 'screens/semester/semester_screen.dart';
import 'screens/semester/semesters_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/study/study_screen.dart';
import 'screens/today/today_screen.dart';

/// Central place for route paths so no screen builds a path by string concat.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String resetPassword = '/reset-password';

  // The five tabs.
  static const String home = '/';
  static const String routine = '/routine';
  static const String semester = '/semester';
  static const String study = '/study';
  static const String more = '/more';

  // Pages inside a tab. Each path extends its tab's path, which is what gives a
  // page a parent for the back button and for Android's system back.
  static const String marks = '/semester/marks';
  static const String results = '/semester/results';
  static const String attendance = '/semester/attendance';
  static const String ctMarks = '/semester/ct-marks';
  static const String semesters = '/semester/manage';
  static const String expenses = '/more/expenses';
  static const String notices = '/more/notices';
  static const String reminders = '/more/reminders';
  static const String profile = '/more/profile';
  static const String profileSemesters = '/more/profile/semesters';

  static String courseDetail(String courseId) => '$semester/$courseId';

  /// Where the back button of the page at [path] leads.
  static String parentOf(String path) {
    final cut = path.lastIndexOf('/');
    return cut <= 0 ? home : path.substring(0, cut);
  }
}

/// Bridges auth changes into go_router.
///
/// `GoRouter.redirect` is only re-evaluated when something tells it to look
/// again. It listens to the user id, not the raw auth stream, so a token refresh
/// does not re-run navigation. Reading it through `ref.read` inside the redirect
/// keeps a single router instance alive instead of rebuilding (and losing
/// navigation state) on every auth change.
class _AuthSignal extends ChangeNotifier {
  _AuthSignal(Ref ref) {
    ref.listen(currentUserIdProvider, (_, _) => notifyListeners());
    ref.listen(passwordRecoveryProvider, (_, _) => notifyListeners());
  }
}

GoRoute _page(
  String path,
  Widget Function() build, {
  List<RouteBase>? routes,
}) =>
    GoRoute(path: path, builder: (_, _) => build(), routes: routes ?? const []);

final routerProvider = Provider<GoRouter>((ref) {
  final authSignal = _AuthSignal(ref);
  ref.onDispose(authSignal.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authSignal,
    redirect: (context, state) {
      final signedIn = ref.read(currentUserIdProvider) != null;
      final recovering = ref.read(passwordRecoveryProvider);
      final atLogin = state.matchedLocation == AppRoutes.login;
      final atReset = state.matchedLocation == AppRoutes.resetPassword;

      if (!signedIn) return atLogin ? null : AppRoutes.login;
      if (recovering) return atReset ? null : AppRoutes.resetPassword;
      if (atLogin || atReset) return AppRoutes.home;
      return null;
    },
    routes: [
      _page(AppRoutes.login, () => const LoginScreen()),
      _page(AppRoutes.resetPassword, () => const ResetPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [_page(AppRoutes.home, () => const TodayScreen())],
          ),
          StatefulShellBranch(
            routes: [_page(AppRoutes.routine, () => const RoutineScreen())],
          ),
          StatefulShellBranch(
            routes: [
              _page(
                AppRoutes.semester,
                () => const SemesterScreen(),
                routes: [
                  // The fixed pages come before the course id, which would
                  // otherwise match them.
                  _page('marks', () => const MarksScreen()),
                  _page('results', () => const ResultsScreen()),
                  _page('attendance', () => const AttendanceScreen()),
                  _page('ct-marks', () => const CtMarksScreen()),
                  _page('manage', () => const SemestersScreen()),
                  GoRoute(
                    path: ':courseId',
                    builder: (context, state) => CourseDetailScreen(
                      courseId: state.pathParameters['courseId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [_page(AppRoutes.study, () => const StudyScreen())],
          ),
          StatefulShellBranch(
            routes: [
              _page(
                AppRoutes.more,
                () => const MoreScreen(),
                routes: [
                  _page('expenses', () => const ExpensesScreen()),
                  _page('notices', () => const NoticeListScreen()),
                  _page('reminders', () => const RemindersScreen()),
                  _page(
                    'profile',
                    () => const ProfileScreen(),
                    routes: [_page('semesters', () => const SemestersScreen())],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
