import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/class_slot.dart';
import 'package:unifriend/models/ct_mark.dart';
import 'package:unifriend/models/expense.dart';
import 'package:unifriend/models/study_session.dart';
import 'package:unifriend/utils/ct_summary.dart';
import 'package:unifriend/utils/date_utils.dart';
import 'package:unifriend/utils/money.dart';
import 'package:unifriend/utils/study_stats.dart';

CtMark _mark(double obtained, double total) => CtMark(
  id: 'm',
  courseId: 'c',
  title: 'CT',
  obtained: obtained,
  total: total,
  heldOn: null,
  createdAt: DateTime(2026),
);

StudySession _study(DateTime day, int minutes) => StudySession(
  id: 's',
  courseId: null,
  topic: 'Topic',
  minutes: minutes,
  studiedOn: day,
  notes: null,
  createdAt: day,
);

Expense _expense(
  DateTime day,
  double amount, [
  ExpenseCategory category = ExpenseCategory.food,
]) => Expense(
  id: 'e',
  title: 'Item',
  amount: amount,
  category: category,
  spentOn: day,
  note: null,
  createdAt: day,
);

void main() {
  group('CtSummary', () {
    test('is empty with no marks', () {
      final summary = CtSummary.of(const []);
      expect(summary.count, 0);
      expect(summary.averagePercent, isNull);
      expect(summary.bestAveragePercent, isNull);
    });

    test('weighs tests with different totals by percentage', () {
      final summary = CtSummary.of([_mark(10, 20), _mark(15, 15)]);
      expect(summary.averagePercent, 75);
      expect(summary.highestPercent, 100);
    });

    test('the best average keeps only the top tests', () {
      final summary = CtSummary.of([
        _mark(20, 20),
        _mark(18, 20),
        _mark(16, 20),
        _mark(2, 20),
      ]);
      expect(summary.count, 4);
      expect(summary.averagePercent, closeTo(70, 0.001));
      expect(summary.bestAveragePercent, closeTo(90, 0.001));
    });

    test('the best average uses every test when there are few', () {
      final summary = CtSummary.of([_mark(10, 20)]);
      expect(summary.bestAveragePercent, 50);
    });
  });

  group('StudyStats', () {
    // 2026-11-04 is a Wednesday, so its week began on Saturday 31 October.
    final now = DateTime(2026, 11, 4, 15);

    test('formats minutes', () {
      expect(StudyStats.formatMinutes(45), '45m');
      expect(StudyStats.formatMinutes(120), '2h');
      expect(StudyStats.formatMinutes(80), '1h 20m');
    });

    test('this week starts on Saturday', () {
      final sessions = [
        _study(DateTime(2026, 10, 30), 999), // Friday: last week
        _study(DateTime(2026, 10, 31), 30), // Saturday: first day of the week
        _study(DateTime(2026, 11, 4), 45),
        _study(DateTime(2026, 11, 7), 999), // next Saturday: next week
      ];
      expect(StudyStats.minutesThisWeek(sessions, now: now), 75);
    });
  });

  group('Money', () {
    test('formats with the currency symbol and separators', () {
      expect(Money.format(1250), 'Tk 1,250');
      expect(Money.format(99.5), 'Tk 99.5');
    });

    test('filters to one calendar month', () {
      final expenses = [
        _expense(DateTime(2026, 11, 1), 10),
        _expense(DateTime(2026, 11, 30), 20),
        _expense(DateTime(2026, 10, 31), 40),
        _expense(DateTime(2025, 11, 15), 80),
      ];
      expect(Money.total(Money.inMonth(expenses, DateTime(2026, 11))), 30);
    });

    test('totals categories, largest first, skipping empty ones', () {
      final totals = Money.byCategory([
        _expense(DateTime(2026, 11, 1), 10, ExpenseCategory.food),
        _expense(DateTime(2026, 11, 1), 50, ExpenseCategory.transport),
        _expense(DateTime(2026, 11, 2), 15, ExpenseCategory.food),
      ]);
      expect(totals, [
        (ExpenseCategory.transport, 50.0),
        (ExpenseCategory.food, 25.0),
      ]);
    });

    test('groups by day, newest first', () {
      final days = Money.byDay([
        _expense(DateTime(2026, 11, 1), 10),
        _expense(DateTime(2026, 11, 3), 20),
        _expense(DateTime(2026, 11, 1), 5),
      ]);
      expect(days.map((d) => d.$1), [
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 1),
      ]);
      expect(days.last.$2, hasLength(2));
    });

    test('days left counts today, and is zero for a past month', () {
      final now = DateTime(2026, 11, 28);
      expect(Money.daysLeft(DateTime(2026, 11), now: now), 3);
      expect(Money.daysLeft(DateTime(2026, 10), now: now), 0);
      expect(Money.daysLeft(DateTime(2026, 12), now: now), 31);
    });

    test('safe to spend splits what is left over the days left', () {
      expect(
        Money.safePerDay(
          budget: 3000,
          spent: 2100,
          month: DateTime(2026, 11),
          now: DateTime(2026, 11, 28),
        ),
        300,
      );
    });

    test('safe to spend is zero once over budget, and null without one', () {
      final month = DateTime(2026, 11);
      final now = DateTime(2026, 11, 10);
      expect(
        Money.safePerDay(budget: 1000, spent: 1200, month: month, now: now),
        0,
      );
      expect(
        Money.safePerDay(budget: null, spent: 10, month: month, now: now),
        isNull,
      );
      expect(
        Money.safePerDay(
          budget: 1000,
          spent: 10,
          month: DateTime(2026, 10),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('ClassSlot.overlaps', () {
    ClassSlot slot(int weekday, int start, int end) => ClassSlot(
      id: 's',
      courseId: 'c',
      weekday: weekday,
      startMinute: start,
      endMinute: end,
      room: null,
    );

    test('detects a clash on the same day', () {
      expect(slot(1, 480, 540).overlaps(slot(1, 500, 600)), isTrue);
    });

    test('back-to-back classes do not clash', () {
      expect(slot(1, 480, 540).overlaps(slot(1, 540, 600)), isFalse);
    });

    test('the same time on another day does not clash', () {
      expect(slot(1, 480, 540).overlaps(slot(2, 480, 540)), isFalse);
    });
  });

  group('AppDate calendar helpers', () {
    test('weekdays are listed from Saturday', () {
      expect(AppDate.weekdaysInOrder, [6, 7, 1, 2, 3, 4, 5]);
    });

    test('startOfWeek finds the Saturday on or before a date', () {
      expect(
        AppDate.startOfWeek(DateTime(2026, 11, 4)),
        DateTime(2026, 10, 31),
      );
      expect(
        AppDate.startOfWeek(DateTime(2026, 10, 31)),
        DateTime(2026, 10, 31),
      );
      expect(
        AppDate.startOfWeek(DateTime(2026, 10, 30)),
        DateTime(2026, 10, 24),
      );
    });

    test('mostRecent never returns a future date', () {
      final now = DateTime(2026, 11, 4); // Wednesday
      expect(
        AppDate.mostRecent(DateTime.wednesday, now: now),
        DateTime(2026, 11, 4),
      );
      expect(
        AppDate.mostRecent(DateTime.thursday, now: now),
        DateTime(2026, 10, 29),
      );
    });

    test('database dates round trip as the same calendar day', () {
      final day = AppDate.fromDbDate('2026-03-09');
      expect(day, DateTime(2026, 3, 9));
      expect(AppDate.toDbDate(day), '2026-03-09');
    });

    test('renders a minute of the day as a clock time', () {
      expect(AppDate.minuteOfDay(510), '8:30 AM');
      expect(AppDate.minuteOfDay(780), '1:00 PM');
    });

    test('a deadline earlier today already counts as overdue', () {
      final now = DateTime(2026, 11, 4, 17);
      final info = AppDate.describe(
        DateTime(2026, 11, 4, 9),
        isCompleted: false,
        now: now,
      );
      expect(info.status, DueStatus.overdue);
      expect(info.longLabel, 'Was due today at 9:00 AM');
    });
  });
}
