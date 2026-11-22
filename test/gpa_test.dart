import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/utils/gpa.dart';

GpaEntry _entry(
  double credits,
  double points, {
  String? semester,
  int order = 0,
  String? code,
  String? id,
}) => GpaEntry(
  semesterId: semester,
  semesterOrder: order,
  credits: credits,
  gradePoints: points,
  courseCode: code,
  courseId: id,
);

void main() {
  group('Gpa.overall', () {
    test('is null with nothing graded, not 0.00', () {
      expect(Gpa.overall(const []), isNull);
    });

    test('weights by credits', () {
      // (3 * 4.0 + 1.5 * 3.0) / 4.5 = 3.666...
      expect(Gpa.overall([_entry(3, 4.0), _entry(1.5, 3.0)]), 3.67);
    });

    test('keeps fractional lab credits exact', () {
      // (3 * 3.75 + 0.75 * 4.0) / 3.75 = 3.8
      expect(Gpa.overall([_entry(3, 3.75), _entry(0.75, 4.0)]), 3.8);
    });

    test('an F counts towards the average', () {
      expect(Gpa.overall([_entry(3, 4.0), _entry(3, 0.0)]), 2.0);
    });
  });

  group('retakes', () {
    final first = _entry(
      3,
      2.5,
      semester: 's1',
      order: 0,
      code: 'CSE101',
      id: 'a',
    );
    final retake = _entry(
      3,
      3.5,
      semester: 's2',
      order: 1,
      code: 'cse101',
      id: 'b',
    );

    test('the better grade counts once', () {
      expect(Gpa.overall([first, retake]), 3.5);
      expect(Gpa.superseded([first, retake]), {'a'});
    });

    test('a worse retake does not replace the better grade', () {
      final worse = _entry(
        3,
        2.0,
        semester: 's2',
        order: 1,
        code: 'CSE101',
        id: 'c',
      );
      expect(Gpa.superseded([first, worse]), {'c'});
    });

    test('equal grades keep the later attempt', () {
      final same = _entry(
        3,
        2.5,
        semester: 's2',
        order: 1,
        code: 'CSE101',
        id: 'd',
      );
      expect(Gpa.superseded([first, same]), {'a'});
    });

    test('the latest-attempt policy follows semester order', () {
      final worse = _entry(
        3,
        2.0,
        semester: 's2',
        order: 1,
        code: 'CSE101',
        id: 'c',
      );
      expect(
        Gpa.counted([
          first,
          worse,
        ], policy: RetakePolicy.latestAttempt).single.courseId,
        'c',
      );
    });

    test('courses with no code are never retakes', () {
      expect(Gpa.counted([_entry(3, 3), _entry(3, 4)]), hasLength(2));
    });
  });

  group('Gpa.bySemester', () {
    test('orders semesters by their position in time, not by name', () {
      final results = Gpa.bySemester([
        _entry(3, 3.0, semester: 'later', order: 2),
        _entry(3, 4.0, semester: 'earlier', order: 0),
        _entry(3, 3.5, semester: 'middle', order: 1),
      ]);
      expect(results.map((r) => r.semesterId), ['earlier', 'middle', 'later']);
    });

    test('a retaken attempt stays in its own semester GPA', () {
      final results = Gpa.bySemester([
        _entry(3, 2.0, semester: 's1', order: 0, code: 'X', id: 'a'),
        _entry(3, 4.0, semester: 's2', order: 1, code: 'X', id: 'b'),
      ]);
      expect(results.first.gpa, 2.0);
      expect(results.last.gpa, 4.0);
    });

    test('courses in no semester come last', () {
      final results = Gpa.bySemester([
        _entry(3, 3.0),
        _entry(3, 4.0, semester: 's1', order: 0),
      ]);
      expect(results.last.semesterId, isNull);
      expect(results.first.totalCredits, 3);
    });
  });
}
