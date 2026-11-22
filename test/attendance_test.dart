import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/models/attendance_record.dart';
import 'package:unifriend/utils/attendance.dart';

void main() {
  group('AttendanceSummary', () {
    test('has no percentage before any class is recorded', () {
      const summary = AttendanceSummary();
      expect(summary.percent, isNull);
      expect(summary.meetsTarget(), isTrue);
      expect(summary.classesNeeded(), 0);
      expect(summary.canMiss(), 0);
    });

    test('counts each status and treats late as attended', () {
      final summary = AttendanceSummary.of(const [
        AttendanceStatus.present,
        AttendanceStatus.late,
        AttendanceStatus.absent,
        AttendanceStatus.absent,
      ]);
      expect(summary.present, 1);
      expect(summary.late, 1);
      expect(summary.absent, 2);
      expect(summary.attended, 2);
      expect(summary.percent, 50);
    });

    test('classesNeeded lands exactly on the target', () {
      // 6 of 10 is 60%. Six more classes make 12 of 16, which is exactly 75%.
      const summary = AttendanceSummary(present: 6, absent: 4);
      expect(summary.classesNeeded(), 6);
      expect(
        const AttendanceSummary(present: 12, absent: 4).meetsTarget(),
        isTrue,
      );
    });

    test('classesNeeded rounds up a partial class', () {
      // 1 of 3: 2 more gives 3/5 (60%), 5 more gives 6/8 (75%).
      expect(const AttendanceSummary(present: 1, absent: 2).classesNeeded(), 5);
    });

    test('canMiss stops at the last absence that keeps the target', () {
      // 9 of 10: missing 2 gives 9/12 (75%), missing 3 gives 9/13 (69%).
      const summary = AttendanceSummary(present: 9, absent: 1);
      expect(summary.canMiss(), 2);
    });

    test('canMiss is zero at or below the target', () {
      expect(const AttendanceSummary(present: 3, absent: 1).canMiss(), 0);
      expect(const AttendanceSummary(present: 1, absent: 1).canMiss(), 0);
    });

    test('exactly the target meets it', () {
      const summary = AttendanceSummary(present: 3, absent: 1);
      expect(summary.meetsTarget(), isTrue);
      expect(summary.classesNeeded(), 0);
    });
  });

  test(
    'an unknown status reads as absent, which cannot inflate the figure',
    () {
      expect(AttendanceStatus.fromName('excused'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromName('late'), AttendanceStatus.late);
    },
  );

  test('a cancelled class counts neither for nor against attendance', () {
    final summary = AttendanceSummary.of(const [
      AttendanceStatus.present,
      AttendanceStatus.cancelled,
      AttendanceStatus.absent,
      AttendanceStatus.cancelled,
    ]);
    expect(summary.total, 2);
    expect(summary.percent, 50);
    expect(AttendanceStatus.fromName('cancelled'), AttendanceStatus.cancelled);
  });

  test('under 50% the course has to be registered again', () {
    expect(const AttendanceSummary(present: 4, absent: 6).mustRegister, isTrue);
    expect(
      const AttendanceSummary(present: 5, absent: 5).mustRegister,
      isFalse,
    );
    expect(const AttendanceSummary().mustRegister, isFalse);
    // 4 of 10: 2 more in a row reach 6 of 12, which is 50%.
    expect(
      const AttendanceSummary(
        present: 4,
        absent: 6,
      ).classesNeeded(kAttendanceRegisterBelowPercent),
      2,
    );
  });
}
