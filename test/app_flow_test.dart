import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:unifriend/app.dart';
import 'package:unifriend/providers/core_providers.dart';
import 'package:unifriend/providers/routine_providers.dart';
import 'package:unifriend/router.dart';
import 'package:unifriend/screens/auth/login_screen.dart';
import 'package:unifriend/screens/auth/reset_password_screen.dart';
import 'package:unifriend/utils/date_utils.dart';

import 'support/fakes.dart';

/// Starts the real app, with the real router, on an in-memory backend.
Future<(ProviderContainer, GoRouter)> startApp(
  WidgetTester tester,
  FakeBackend db, {
  Size size = const Size(360, 740),
}) async {
  usePhoneScreen(tester, size: size);
  final container = ProviderContainer(
    overrides: db.overrides,
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const UniFriendApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (container, container.read(routerProvider));
}

/// Unmounts the app, so its periodic timers do not outlive the test.
Future<void> stopApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> goTo(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFont);
  setUp(resetDeviceStorage);

  final routes = {
    AppRoutes.home: 'Classes today',
    AppRoutes.routine: 'Routine',
    AppRoutes.semester: 'Courses',
    AppRoutes.marks: 'Theory',
    AppRoutes.results: 'CGPA',
    AppRoutes.attendance: 'Attendance',
    AppRoutes.ctMarks: 'CT marks',
    AppRoutes.semesters: 'Semesters',
    AppRoutes.study: "Today's plan",
    AppRoutes.more: 'Expenses',
    AppRoutes.expenses: 'SPENT',
    AppRoutes.notices: 'Notices',
    AppRoutes.profile: 'Semester',
    AppRoutes.profileSemesters: 'Add vacation',
    AppRoutes.reminders: 'Reminders',
  };

  group('every screen renders without overflow', () {
    for (final size in const [Size(360, 740), Size(320, 568)]) {
      testWidgets('with data at ${size.width.toInt()} wide', (tester) async {
        final db = FakeBackend()..user = 'a';
        final seeded = seed(db, 'a');
        final (_, router) = await startApp(tester, db, size: size);

        for (final entry in routes.entries) {
          await goTo(tester, router, entry.key);
          expect(
            find.textContaining(entry.value),
            findsWidgets,
            reason: entry.key,
          );
        }
        for (final id in [seeded.seId, seeded.labId]) {
          await goTo(tester, router, AppRoutes.courseDetail(id));
          expect(find.text('RESULT'), findsOneWidget);
        }
        await stopApp(tester);
      });
    }

    testWidgets('for a brand new student with nothing yet', (tester) async {
      final db = FakeBackend()..user = 'new';
      final (_, router) = await startApp(tester, db);

      for (final path in routes.keys) {
        await goTo(tester, router, path);
      }
      await goTo(tester, router, AppRoutes.semester);
      expect(find.text('Start with your semester'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('and shows a load failure instead of an empty list', (
      tester,
    ) async {
      final db = FakeBackend()
        ..user = 'a'
        ..failReads = true;
      final (_, router) = await startApp(tester, db);

      await goTo(tester, router, AppRoutes.expenses);
      expect(find.text('Could not load this'), findsOneWidget);
      await stopApp(tester);
    });
  });

  group('navigation', () {
    testWidgets('signed out goes to login, and signing in leaves it', (
      tester,
    ) async {
      final db = FakeBackend();
      final (container, _) = await startApp(tester, db);
      expect(find.byType(LoginScreen), findsOneWidget);

      db.user = 'a';
      container.read(testUserProvider.notifier).set('a');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Classes today'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('signing out returns to login', (tester) async {
      final db = FakeBackend()..user = 'a';
      final (container, _) = await startApp(tester, db);

      db.user = null;
      container.read(testUserProvider.notifier).set(null);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets(
      'a course page has a back button that returns to the semester',
      (tester) async {
        final db = FakeBackend()..user = 'a';
        seed(db, 'a');
        final (_, router) = await startApp(tester, db);

        await goTo(tester, router, AppRoutes.semester);
        await tapVisible(tester, find.textContaining('Operating Systems Lab'));
        expect(router.state.uri.path, startsWith('${AppRoutes.semester}/'));

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.semester);
        await stopApp(tester);
      },
    );

    testWidgets('Android back from a course page returns to the semester', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);

      await goTo(tester, router, AppRoutes.semester);
      await tapVisible(tester, find.textContaining('Operating Systems Lab'));

      expect(router.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.semester);
      await stopApp(tester);
    });

    testWidgets('the nav bar has the five tabs', (tester) async {
      final db = FakeBackend()..user = 'a';
      final (_, router) = await startApp(tester, db);
      for (final (label, path) in [
        ('Routine', AppRoutes.routine),
        ('Semester', AppRoutes.semester),
        ('Study', AppRoutes.study),
        ('More', AppRoutes.more),
        ('Today', AppRoutes.home),
      ]) {
        await tester.tap(find.bySemanticsLabel(label).last);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, path, reason: label);
      }
      await stopApp(tester);
    });

    test('parentOf walks up one level', () {
      expect(AppRoutes.parentOf('/semester/abc'), '/semester');
      expect(AppRoutes.parentOf('/more/profile/semesters'), '/more/profile');
      expect(AppRoutes.parentOf('/more'), '/');
    });
  });

  group('semesters and courses', () {
    testWidgets('a new student adds a semester, then a sessional course', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'new';
      db.add('profiles', {'id': 'new', 'full_name': 'New Student'});
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.semester);

      await tester.tap(find.text('Add semester'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Level 1 Term 1',
      );
      await tester.tap(find.text('Add semester').last);
      await tester.pumpAndSettle();

      final semester = db.rows('semesters').single;
      expect(semester['name'], 'Level 1 Term 1');
      expect(db.rows('profiles').single['current_semester_id'], semester['id']);
      expect(find.textContaining('Week 1'), findsWidgets);

      await tester.tap(find.byTooltip('New course'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'CSE1102');
      await tester.enterText(fields.at(1), 'Programming Lab');
      await tester.tap(find.text('Sessional'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('0.75'));
      await tapVisible(tester, find.text('Add course'));

      final course = db.rows('courses').single;
      expect(course['kind'], 'sessional');
      expect(course['credits'], 0.75);
      expect(course['semester_id'], semester['id']);
      expect(find.text('Programming Lab'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('a vacation is added to a semester', (tester) async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.profileSemesters);

      await tester.tap(find.text('Add vacation').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Puja break');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();

      final vacation = db.rows('vacations').single;
      expect(vacation['semester_id'], seeded.semesterId);
      expect(vacation['title'], 'Puja break');
      // It starts today, so today has no classes and Today says so.
      await goTo(tester, router, AppRoutes.home);
      expect(find.textContaining('Puja break until'), findsOneWidget);
      expect(find.text('No classes during the vacation.'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('ending a course takes it off the routine', (tester) async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final (container, router) = await startApp(tester, db);
      final tomorrow = AppDate.addDays(AppDate.dayOf(DateTime.now()), 1);
      expect(
        container
            .read(classesOnDayProvider(AppDate.addDays(tomorrow, 6)))
            .map((o) => o.course.code),
        contains('CSE2104'),
      );

      await goTo(tester, router, AppRoutes.courseDetail(seeded.osId));
      await tester.tap(find.byTooltip('Course options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classes ended'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'End classes'));
      await tester.pumpAndSettle();

      expect(
        db
            .rows('courses')
            .firstWhere((r) => r['id'] == seeded.osId)['classes_ended_on'],
        isNotNull,
      );
      expect(
        container
            .read(classesOnDayProvider(AppDate.addDays(tomorrow, 6)))
            .map((o) => o.course.code),
        isNot(contains('CSE2104')),
      );
      await stopApp(tester);
    });
  });

  group('marks', () {
    testWidgets('entering the final exam completes the grade', (tester) async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.courseDetail(seeded.seId));

      expect(find.text('Not graded yet'), findsOneWidget);
      await tapVisible(tester, find.text('Final exam'));
      // Typed as it was given: 115 out of 150, scaled to 60 is 46.
      await tester.enterText(find.byType(TextFormField).at(0), '115');
      await tester.enterText(find.byType(TextFormField).at(1), '150');
      await tester.pump();
      expect(find.text('46 of 60'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final marks = db
          .rows('courses')
          .firstWhere((r) => r['id'] == seeded.seId)['marks'];
      expect(marks['final'], 46);
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('A+  ·  4.00'), findsOneWidget);
      expect(find.text('From 80.5 marks'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('the marks table opens a cell for entry', (tester) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.marks);

      expect(find.text('Theory'), findsOneWidget);
      expect(find.text('Sessional'), findsOneWidget);
      // The table scrolls sideways; the first empty cell starts off screen.
      await tapVisible(tester, find.text('—').first);
      expect(find.text('Counts as'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('a retaken course is labelled on the results', (tester) async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      db.user = 'a';
      db.add('courses', {
        'code': 'CSE1101',
        'title': 'Structured Programming again',
        'credits': 3,
        'kind': 'theory',
        'semester_id': seeded.semesterId,
        'grade_points': 2.0,
        'marks': <String, double>{},
      });
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.results);

      await tester.ensureVisible(find.textContaining('Retaken').first);
      expect(find.textContaining('Retaken'), findsWidgets);
      expect(find.text('3.75'), findsWidgets);
      await stopApp(tester);
    });
  });

  group('today', () {
    testWidgets('marking a class, then correcting and clearing it', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.home);
      final today = AppDate.toDbDate(DateTime.now());
      List<Map<String, dynamic>> marks() => db
          .rows('attendance_records')
          .where((r) => r['held_on'] == today)
          .toList();

      await tester.tap(find.text('P').first);
      await tester.pumpAndSettle();
      expect(marks().single['status'], 'present');

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      expect(marks().single['status'], 'absent');

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      expect(marks(), isEmpty);
      await stopApp(tester);
    });

    testWidgets('a class can be cancelled for the day, and restored', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.home);

      await tester.tap(find.byTooltip('Class options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class cancelled'));
      await tester.pumpAndSettle();

      final record = db.rows('attendance_records').last;
      expect(record['status'], 'cancelled');
      expect(find.textContaining('Cancelled  ·'), findsOneWidget);

      await tester.tap(find.byTooltip('Class options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore class'));
      await tester.pumpAndSettle();
      expect(
        db.rows('attendance_records').where((r) => r['status'] == 'cancelled'),
        isEmpty,
      );
      await stopApp(tester);
    });

    testWidgets('the quick actions open the expense and plan sheets', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.home);

      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Plan a topic'), findsOneWidget);
      await stopApp(tester);
    });
  });

  group('other flows', () {
    testWidgets('a quick expense updates the month and the safe daily spend', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.expenses);
      expect(find.textContaining('Safe to spend'), findsOneWidget);

      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();

      // Saving blank is refused.
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '250');
      await tester.tap(find.text('Transport'));
      await tester.pump();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();

      final added = db.rows('expenses').last;
      expect(added['amount'], 250);
      expect(added['category'], 'transport');
      // No title typed, so the category names it.
      expect(added['title'], 'Transport');
      expect(find.text('Tk 2,050'), findsWidgets);
      await stopApp(tester);
    });

    testWidgets('adding a class needs a course, and warns about a clash', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (container, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.routine);

      await tester.tap(find.byTooltip('New class'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Add class').last);
      expect(find.text('Choose a course'), findsWidgets);

      // The default 8:00 slot runs into the seeded 8:00 class.
      expect(find.textContaining('Overlaps with'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CSE2104').last);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Every other week'));
      expect(find.textContaining('Date of one class'), findsOneWidget);
      await tapVisible(tester, find.text('Add class').last);

      expect(container.read(classSlotListProvider).value, hasLength(4));
      expect(db.rows('class_slots').last['repeat_weeks'], 2);
      expect(db.rows('class_slots').last['anchor_date'], isNotNull);
      await stopApp(tester);
    });

    testWidgets('the study timer keeps running after leaving the screen', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.study);

      await tester.tap(find.text('Start focus timer'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Stop & log'), findsOneWidget);

      await goTo(tester, router, AppRoutes.home);
      await goTo(tester, router, AppRoutes.study);
      expect(find.text('Stop & log'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('a planned topic carries a tick box', (tester) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.study);

      expect(find.text('Page replacement'), findsWidgets);
      expect(find.text('OS CT 3'), findsOneWidget);
      await tester.tap(
        find.byType(GestureDetector).hitTestable().at(0),
        warnIfMissed: false,
      );
      await stopApp(tester);
    });

    testWidgets('signing out asks with a Sign out button, not Delete', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.profile);

      await tapVisible(tester, find.text('Sign out'));
      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(db.auth.signOuts, 1);
      await stopApp(tester);
    });

    testWidgets('forgot password sends the link, and says to check email', (
      tester,
    ) async {
      final db = FakeBackend();
      await startApp(tester, db);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(db.auth.resetEmails, isEmpty);

      await tester.enterText(find.byType(TextFormField).last, 'me@uni.edu');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(db.auth.resetEmails, ['me@uni.edu']);
      expect(find.text('Check your email'), findsOneWidget);
      await stopApp(tester);
    });

    testWidgets('a reset link holds the student on the new password screen', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      final events = StreamController<AuthState>.broadcast();
      addTearDown(events.close);
      db.auth.events = events.stream;
      final (_, router) = await startApp(tester, db);

      events.add(recoveryEvent);
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      await goTo(tester, router, AppRoutes.study);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();

      expect(db.auth.newPasswords, ['secret1']);
      expect(find.byType(ResetPasswordScreen), findsNothing);
      await stopApp(tester);
    });

    testWidgets('going offline shows a banner, and a save says why it failed', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      seed(db, 'a');
      final (container, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.home);
      expect(find.textContaining('Offline'), findsNothing);

      db.remote.offline = true;
      await container.read(rowStoreProvider).checkConnection();
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline. Showing'), findsOneWidget);

      await tester.tap(find.text('P').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not reach the server'), findsOneWidget);

      db.remote.offline = false;
      await container.read(rowStoreProvider).checkConnection();
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsNothing);
      await stopApp(tester);
    });

    testWidgets('turning a reminder on asks permission, and respects a no', (
      tester,
    ) async {
      final db = FakeBackend()..user = 'a';
      final seeded = seed(db, 'a');
      db.user = 'a';
      db.add('class_slots', {
        'course_id': seeded.seId,
        'weekday': AppDate.addDays(DateTime.now(), 1).weekday,
        'start_minute': 600,
        'end_minute': 650,
        'room': null,
        'repeat_weeks': 1,
        'anchor_date': null,
      });
      db.reminders.permission = false;
      final (_, router) = await startApp(tester, db);
      await goTo(tester, router, AppRoutes.reminders);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Notifications are off'), findsOneWidget);
      expect(db.reminders.scheduled, isEmpty);

      db.reminders.permission = true;
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(db.reminders.scheduled, isNotEmpty);
      await stopApp(tester);
    });
  });
}
