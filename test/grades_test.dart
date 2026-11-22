import 'package:flutter_test/flutter_test.dart';
import 'package:unifriend/utils/grades.dart';

void main() {
  group('gradeLetter', () {
    test('is -- when there is no result', () {
      expect(gradeLetter(null), '--');
    });

    test('maps each preset to its letter', () {
      for (final (letter, points) in kGradePresets) {
        expect(gradeLetter(points), letter);
      }
    });

    test('falls back to the raw number for a non-preset score', () {
      expect(gradeLetter(3.6), '3.60');
    });
  });

  group('cgpaRemark', () {
    test('describes an empty result set', () {
      expect(cgpaRemark(null), 'No results yet');
    });

    test('bands a score into a remark', () {
      expect(cgpaRemark(3.9), 'Outstanding');
      expect(cgpaRemark(3.75), 'Outstanding');
      expect(cgpaRemark(3.6), 'Excellent');
      expect(cgpaRemark(3.2), 'Good');
      expect(cgpaRemark(2.7), 'Average');
      expect(cgpaRemark(1.0), 'Needs work');
    });
  });

  test('the scale tops out at 4.00', () {
    expect(kMaxGradePoints, 4.0);
    expect(
      kGradePresets.map((preset) => preset.$2).reduce((a, b) => a > b ? a : b),
      4.0,
    );
  });
}
