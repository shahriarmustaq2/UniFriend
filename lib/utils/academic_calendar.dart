import '../models/class_slot.dart';
import '../models/course.dart';
import '../models/semester.dart';
import 'date_utils.dart';

/// Which days of a semester are teaching days, and which week each falls in.
///
/// Weeks start on [AppDate.weekStart]. A week that lies wholly inside vacations
/// does not count: the week number freezes through it and carries on after.
/// A vacation that covers only part of a week cancels the classes on those days,
/// but the week still counts.
class AcademicCalendar {
  final Semester? semester;
  final List<Vacation> vacations;

  const AcademicCalendar({this.semester, this.vacations = const []});

  Vacation? vacationOn(DateTime day) =>
      vacations.where((v) => v.covers(day)).firstOrNull;

  bool isVacationDay(DateTime day) => vacationOn(day) != null;

  /// True when every day of the week starting [weekStart] is a vacation day.
  bool isVacationWeek(DateTime weekStart) {
    for (var i = 0; i < 7; i++) {
      if (!isVacationDay(AppDate.addDays(weekStart, i))) return false;
    }
    return true;
  }

  /// Counting weeks that are not vacation weeks, from the week of [from] to the
  /// week of [to]: 0 for the same week, 1 for the next teaching week, and so
  /// on. Negative when [to] is earlier.
  int teachingWeeksBetween(DateTime from, DateTime to) {
    var a = AppDate.startOfWeek(from);
    var b = AppDate.startOfWeek(to);
    var sign = 1;
    if (b.isBefore(a)) {
      (a, b) = (b, a);
      sign = -1;
    }
    var count = 0;
    for (
      var week = AppDate.addDays(a, 7);
      !week.isAfter(b);
      week = AppDate.addDays(week, 7)
    ) {
      if (!isVacationWeek(week)) count++;
    }
    return count * sign;
  }

  /// The semester's week number on [day], starting at 1. During a vacation week
  /// it stays at the number of the last teaching week. Null before the semester
  /// starts or when there is no semester.
  int? weekNumber(DateTime day) {
    final start = semester?.startsOn;
    if (start == null || AppDate.dayOf(day).isBefore(start)) return null;
    // The first week counts even if it opens on vacation, so numbering starts
    // at 1 rather than 0.
    return teachingWeeksBetween(start, day) + 1;
  }

  /// Whether the class [slot] of [course] takes place on [day].
  bool hasClass(ClassSlot slot, Course course, DateTime day) {
    final d = AppDate.dayOf(day);
    if (slot.weekday != d.weekday) return false;
    if (!course.runsOn(d)) return false;
    final term = semester;
    if (term != null && !term.runsOn(d)) return false;
    if (isVacationDay(d)) return false;

    if (slot.isAlternate) {
      final anchor = slot.anchorDate;
      if (anchor == null) return true;
      if (isVacationWeek(AppDate.startOfWeek(d))) return false;
      return teachingWeeksBetween(anchor, d) % 2 == 0;
    }
    return true;
  }
}

/// One class on one date.
class ClassOccurrence {
  final ClassSlot slot;
  final Course course;
  final DateTime date;

  /// Separates two classes of one course on the same day. It is the class's
  /// position among that course's classes on that weekday.
  final int session;

  const ClassOccurrence({
    required this.slot,
    required this.course,
    required this.date,
    required this.session,
  });

  DateTime get startsAt => DateTime(
    date.year,
    date.month,
    date.day,
    slot.startMinute ~/ 60,
    slot.startMinute % 60,
  );
}

/// Which class of the day [slot] is for its course: 1 for the first, 2 for a
/// second class of the same course later that weekday. This is the `session` a
/// mark from the routine is stored under.
int sessionNumberFor(ClassSlot slot, Iterable<ClassSlot> all) {
  final sameDay =
      all
          .where(
            (s) => s.courseId == slot.courseId && s.weekday == slot.weekday,
          )
          .toList()
        ..sort((a, b) {
          final byStart = a.startMinute.compareTo(b.startMinute);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        });
  final index = sameDay.indexWhere((s) => s.id == slot.id);
  return index < 0 ? 1 : index + 1;
}

/// Every class on [day], earliest first.
///
/// [calendarFor] gives the calendar of a course's semester. Courses missing
/// from [courses] are skipped, as are those whose classes have ended.
List<ClassOccurrence> classesOn(
  DateTime day, {
  required Iterable<ClassSlot> slots,
  required Map<String, Course> courses,
  required AcademicCalendar Function(String? semesterId) calendarFor,
}) {
  final d = AppDate.dayOf(day);
  final all = slots.toList();
  final result = <ClassOccurrence>[];
  for (final slot in all) {
    final course = courses[slot.courseId];
    if (course == null) continue;
    if (!calendarFor(course.semesterId).hasClass(slot, course, d)) continue;
    result.add(
      ClassOccurrence(
        slot: slot,
        course: course,
        date: d,
        session: sessionNumberFor(slot, all),
      ),
    );
  }
  result.sort((a, b) {
    final byStart = a.slot.startMinute.compareTo(b.slot.startMinute);
    return byStart != 0 ? byStart : a.slot.id.compareTo(b.slot.id);
  });
  return result;
}
