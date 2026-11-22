import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/class_slot.dart';
import 'package:unifriend/models/course.dart';
import 'package:unifriend/models/semester.dart';
import 'package:unifriend/utils/academic_calendar.dart';

// Weeks start on Saturday. The semester starts on Monday 6 July 2026, so week 1
// runs Sat 4 – Fri 10 July. Sat 18 – Fri 24 July is a whole vacation week, and
// Wed 29 – Thu 30 July a short break inside week 3.
final _semester = Semester(
  id: 's',
  name: 'Level 2 Term 1',
  startsOn: DateTime(2026, 7, 6),
  createdAt: DateTime(2026),
);

final _vacations = [
  Vacation(
    id: 'v1',
    semesterId: 's',
    title: 'Eid',
    startsOn: DateTime(2026, 7, 18),
    endsOn: DateTime(2026, 7, 24),
  ),
  Vacation(
    id: 'v2',
    semesterId: 's',
    title: '',
    startsOn: DateTime(2026, 7, 29),
    endsOn: DateTime(2026, 7, 30),
  ),
];

final _calendar = AcademicCalendar(semester: _semester, vacations: _vacations);

Course _course({DateTime? endedOn, String semesterId = 's'}) => Course(
  id: 'c',
  code: 'CSE2102',
  title: 'Lab',
  credits: 0.75,
  kind: CourseKind.sessional,
  semesterId: semesterId,
  classesEndedOn: endedOn,
  createdAt: DateTime(2026),
);

ClassSlot _slot({
  int weekday = DateTime.monday,
  int repeat = 1,
  DateTime? anchor,
  String id = 'slot',
  int start = 600,
}) => ClassSlot(
  id: id,
  courseId: 'c',
  weekday: weekday,
  startMinute: start,
  endMinute: start + 170,
  room: null,
  repeatWeeks: repeat,
  anchorDate: anchor,
);

void main() {
  group('week numbers', () {
    test('count from the week the semester starts in', () {
      expect(_calendar.weekNumber(DateTime(2026, 7, 6)), 1);
      expect(_calendar.weekNumber(DateTime(2026, 7, 10)), 1);
      expect(_calendar.weekNumber(DateTime(2026, 7, 11)), 2);
    });

    test('are null before the semester starts', () {
      expect(_calendar.weekNumber(DateTime(2026, 7, 3)), isNull);
      expect(const AcademicCalendar().weekNumber(DateTime(2026, 7, 6)), isNull);
    });

    test('freeze through a whole vacation week', () {
      expect(_calendar.isVacationWeek(DateTime(2026, 7, 18)), isTrue);
      expect(_calendar.weekNumber(DateTime(2026, 7, 20)), 2);
      expect(_calendar.weekNumber(DateTime(2026, 7, 25)), 3);
    });

    test('keep counting through a short break', () {
      expect(_calendar.isVacationWeek(DateTime(2026, 7, 25)), isFalse);
      expect(_calendar.weekNumber(DateTime(2026, 8, 1)), 4);
    });
  });

  group('weekly classes', () {
    final slot = _slot();

    test('happen on their weekday', () {
      expect(
        _calendar.hasClass(slot, _course(), DateTime(2026, 7, 13)),
        isTrue,
      );
      expect(
        _calendar.hasClass(slot, _course(), DateTime(2026, 7, 14)),
        isFalse,
      );
    });

    test('do not happen before the semester starts', () {
      expect(
        _calendar.hasClass(slot, _course(), DateTime(2026, 6, 29)),
        isFalse,
      );
    });

    test('do not happen on vacation', () {
      expect(
        _calendar.hasClass(slot, _course(), DateTime(2026, 7, 20)),
        isFalse,
      );
      final wednesday = _slot(weekday: DateTime.wednesday);
      expect(
        _calendar.hasClass(wednesday, _course(), DateTime(2026, 7, 29)),
        isFalse,
      );
    });

    test('stop once the course ends', () {
      final course = _course(endedOn: DateTime(2026, 7, 14));
      expect(_calendar.hasClass(slot, course, DateTime(2026, 7, 13)), isTrue);
      expect(_calendar.hasClass(slot, course, DateTime(2026, 7, 27)), isFalse);
    });

    test('stop once the semester ends', () {
      final calendar = AcademicCalendar(
        semester: _semester.copyWith(classesEndedOn: DateTime(2026, 7, 14)),
      );
      expect(calendar.hasClass(slot, _course(), DateTime(2026, 7, 13)), isTrue);
      expect(
        calendar.hasClass(slot, _course(), DateTime(2026, 7, 27)),
        isFalse,
      );
    });
  });

  group('classes every other week', () {
    final alternate = _slot(repeat: 2, anchor: DateTime(2026, 7, 6));

    test('happen in the anchor week and every second week after', () {
      expect(
        _calendar.hasClass(alternate, _course(), DateTime(2026, 7, 6)),
        isTrue,
      );
      expect(
        _calendar.hasClass(alternate, _course(), DateTime(2026, 7, 13)),
        isFalse,
      );
    });

    test('pause through a vacation week and keep their rhythm after it', () {
      // 20 July is vacation. The vacation week does not count, so 27 July is
      // the second teaching week after the anchor: a class week.
      expect(
        _calendar.hasClass(alternate, _course(), DateTime(2026, 7, 20)),
        isFalse,
      );
      expect(
        _calendar.hasClass(alternate, _course(), DateTime(2026, 7, 27)),
        isTrue,
      );
      expect(
        _calendar.hasClass(alternate, _course(), DateTime(2026, 8, 3)),
        isFalse,
      );
      expect(
        _calendar.hasClass(alternate, _course(), DateTime(2026, 8, 10)),
        isTrue,
      );
    });

    test('work from any class date, even a later one', () {
      final later = _slot(repeat: 2, anchor: DateTime(2026, 7, 27));
      expect(
        _calendar.hasClass(later, _course(), DateTime(2026, 7, 6)),
        isTrue,
      );
      expect(
        _calendar.hasClass(later, _course(), DateTime(2026, 7, 13)),
        isFalse,
      );
    });

    test('work without a semester, counting plain weeks', () {
      const calendar = AcademicCalendar();
      expect(
        calendar.hasClass(alternate, _course(), DateTime(2026, 7, 20)),
        isTrue,
      );
      expect(
        calendar.hasClass(alternate, _course(), DateTime(2026, 7, 27)),
        isFalse,
      );
    });
  });

  group('classesOn', () {
    test('lists the day in time order with session numbers', () {
      final early = _slot(id: 'a', start: 480);
      final late = _slot(id: 'b', start: 840);
      final day = classesOn(
        DateTime(2026, 7, 13),
        slots: [late, early],
        courses: {'c': _course()},
        calendarFor: (_) => _calendar,
      );
      expect(day.map((o) => o.slot.id), ['a', 'b']);
      expect(day.map((o) => o.session), [1, 2]);
      expect(day.first.startsAt, DateTime(2026, 7, 13, 8));
    });

    test('skips classes of unknown courses', () {
      expect(
        classesOn(
          DateTime(2026, 7, 13),
          slots: [_slot()],
          courses: const {},
          calendarFor: (_) => _calendar,
        ),
        isEmpty,
      );
    });
  });
}
