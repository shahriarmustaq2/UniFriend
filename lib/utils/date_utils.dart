import 'package:intl/intl.dart';

/// How urgent an assignment is, used to pick the colour of its due-date chip.
enum DueStatus { overdue, today, soon, later, done }

class DueInfo {
  final DueStatus status;

  /// Short label such as "Overdue 2d" or "Due Fri, 12 Mar".
  final String label;
  final String longLabel;

  const DueInfo(this.status, this.label, this.longLabel);
}

class AppDate {
  AppDate._();

  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _dayMonthYear = DateFormat('d MMM yyyy');
  static final DateFormat _weekdayDayMonth = DateFormat('EEE, d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _dbDate = DateFormat('yyyy-MM-dd');

  static String dayMonth(DateTime value) => _dayMonth.format(value);

  static String dayMonthYear(DateTime value) => _dayMonthYear.format(value);

  static String weekdayDayMonth(DateTime value) =>
      _weekdayDayMonth.format(value);

  static String time(DateTime value) => _time.format(value);

  static String dateTime(DateTime value) =>
      '${weekdayDayMonth(value)} at ${_time.format(value)}';

  /// Strips the time component so "today" comparisons are about the day.
  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Whole days between the start of today and the start of [value].
  /// Negative when [value] is in the past. Compared in UTC so a day that a
  /// daylight-saving change makes 23 hours long still counts as a whole day.
  static int daysUntil(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    return DateTime.utc(value.year, value.month, value.day)
        .difference(
          DateTime.utc(reference.year, reference.month, reference.day),
        )
        .inDays;
  }

  /// The first day of the university week, Saturday here. Every weekly view
  /// (the routine, the study goal) follows this.
  static const int weekStart = DateTime.saturday;

  /// Weekdays in display order, beginning with [weekStart].
  static List<int> get weekdaysInOrder => [
    for (var i = 0; i < 7; i++) (weekStart - 1 + i) % 7 + 1,
  ];

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String weekdayName(int weekday) => _weekdayNames[weekday - 1];

  static String weekdayShort(int weekday) =>
      weekdayName(weekday).substring(0, 3);

  /// Calendar arithmetic that stays on midnight across daylight-saving changes,
  /// which adding a `Duration` does not.
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static DateTime startOfWeek(DateTime value) {
    final day = dayOf(value);
    return addDays(day, -((day.weekday - weekStart) % 7));
  }

  /// The latest date on or before [now] that falls on [weekday], which is the
  /// class an attendance mark on the routine refers to.
  static DateTime mostRecent(int weekday, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    return addDays(today, -((today.weekday - weekday) % 7));
  }

  static int daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// Renders minutes after midnight, such as a class start time, as "8:30 AM".
  static String minuteOfDay(int minutes) =>
      _time.format(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

  static String monthYear(DateTime value) => _monthYear.format(value);

  /// `date` columns carry no time zone, so they are read and written as plain
  /// calendar days. Going through UTC here would move them across midnight.
  static DateTime fromDbDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String toDbDate(DateTime value) => _dbDate.format(value);

  /// Builds the chip label and urgency for a deadline.
  static DueInfo describe(
    DateTime dueDate, {
    required bool isCompleted,
    DateTime? now,
  }) {
    if (isCompleted) {
      return const DueInfo(DueStatus.done, 'Done', 'Completed');
    }

    final reference = now ?? DateTime.now();
    final days = daysUntil(dueDate, now: reference);
    final clock = time(dueDate);

    if (days == 0 && dueDate.isBefore(reference)) {
      return DueInfo(DueStatus.overdue, 'Overdue', 'Was due today at $clock');
    }
    if (days < 0) {
      final overdue = -days;
      return DueInfo(
        DueStatus.overdue,
        'Overdue ${overdue}d',
        'Overdue by $overdue ${_plural(overdue, 'day')}',
      );
    }
    if (days == 0) {
      return DueInfo(DueStatus.today, 'Today $clock', 'Due today at $clock');
    }
    if (days == 1) {
      return DueInfo(DueStatus.soon, 'Tomorrow', 'Due tomorrow at $clock');
    }
    if (days <= 7) {
      return DueInfo(DueStatus.soon, '$days days', 'Due in $days days');
    }
    return DueInfo(
      DueStatus.later,
      _dayMonth.format(dueDate),
      'Due on ${_dayMonthYear.format(dueDate)}',
    );
  }

  /// "3 assignments" / "1 assignment" without a stringly-typed count elsewhere.
  static String plural(int count, String singular, [String? pluralForm]) =>
      '$count ${_plural(count, singular, pluralForm)}';

  static String _plural(int count, String singular, [String? pluralForm]) =>
      count == 1 ? singular : (pluralForm ?? '${singular}s');
}
