import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/utils/date_utils.dart';

void main() {
  group('AppDate.daysUntil', () {
    test('is 0 for later today', () {
      final now = DateTime(2026, 3, 10, 9);

      expect(AppDate.daysUntil(DateTime(2026, 3, 10, 23, 59), now: now), 0);
    });

    test('is 1 for tomorrow', () {
      final now = DateTime(2026, 3, 10, 23, 59);

      expect(AppDate.daysUntil(DateTime(2026, 3, 11, 0, 1), now: now), 1);
    });

    test('is negative for a past day', () {
      final now = DateTime(2026, 3, 10, 12);

      expect(AppDate.daysUntil(DateTime(2026, 3, 8, 9), now: now), -2);
    });
  });

  group('AppDate.describe', () {
    final now = DateTime(2026, 3, 10, 12);

    test('reports a completed item as done regardless of the date', () {
      final info = AppDate.describe(
        DateTime(2026, 3, 1),
        isCompleted: true,
        now: now,
      );

      expect(info.status, DueStatus.done);
      expect(info.label, 'Done');
    });

    test('labels an overdue deadline with the day count', () {
      final info = AppDate.describe(
        DateTime(2026, 3, 8, 23, 59),
        isCompleted: false,
        now: now,
      );

      expect(info.status, DueStatus.overdue);
      expect(info.label, 'Overdue 2d');
      expect(info.longLabel, 'Overdue by 2 days');
    });

    test('singularises a single overdue day', () {
      final info = AppDate.describe(
        DateTime(2026, 3, 9, 23, 59),
        isCompleted: false,
        now: now,
      );

      expect(info.longLabel, 'Overdue by 1 day');
    });

    test('labels today with the clock time', () {
      final info = AppDate.describe(
        DateTime(2026, 3, 10, 17, 30),
        isCompleted: false,
        now: now,
      );

      expect(info.status, DueStatus.today);
      expect(info.label, 'Today 5:30 PM');
    });

    test('labels tomorrow without a clock time', () {
      final info = AppDate.describe(
        DateTime(2026, 3, 11, 23, 59),
        isCompleted: false,
        now: now,
      );

      expect(info.status, DueStatus.soon);
      expect(info.label, 'Tomorrow');
    });

    test('labels the rest of the coming week with a day count', () {
      final info = AppDate.describe(
        DateTime(2026, 3, 15, 23, 59),
        isCompleted: false,
        now: now,
      );

      expect(info.status, DueStatus.soon);
      expect(info.label, '5 days');
    });

    test('falls back to a date beyond a week', () {
      final info = AppDate.describe(
        DateTime(2026, 4, 20, 23, 59),
        isCompleted: false,
        now: now,
      );

      expect(info.status, DueStatus.later);
      expect(info.longLabel, 'Due on 20 Apr 2026');
    });
  });

  group('AppDate.plural', () {
    test('uses the singular for one', () {
      expect(AppDate.plural(1, 'course'), '1 course');
    });

    test('appends an s otherwise', () {
      expect(AppDate.plural(3, 'course'), '3 courses');
      expect(AppDate.plural(0, 'course'), '0 courses');
    });

    test('accepts an irregular plural', () {
      expect(AppDate.plural(2, 'course', 'courses taken'), '2 courses taken');
    });
  });
}
