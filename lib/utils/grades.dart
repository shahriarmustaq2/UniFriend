/// Grade presets offered in the grade picker, as [letter, gradePoints]. This is
/// the UGC Bangladesh uniform scale. Edit this list if your university differs;
/// the picker and the letter shown beside each result both read from it.
const List<(String, double)> kGradePresets = [
  ('A+', 4.0),
  ('A', 3.75),
  ('A-', 3.5),
  ('B+', 3.25),
  ('B', 3.0),
  ('B-', 2.75),
  ('C+', 2.5),
  ('C', 2.25),
  ('D', 2.0),
  ('F', 0.0),
];

/// Highest grade points in the scale, used to size the CGPA progress bar.
const double kMaxGradePoints = 4.0;

/// Letter grade for a numeric score, or `--` when there is no result yet.
String gradeLetter(double? gradePoints) {
  if (gradePoints == null) return '--';
  for (final (letter, points) in kGradePresets) {
    if ((gradePoints - points).abs() < 0.001) return letter;
  }
  return gradePoints.toStringAsFixed(2);
}

/// One-word description of a CGPA value, shown beside it on the results screen.
String cgpaRemark(double? cgpa) {
  if (cgpa == null) return 'No results yet';
  if (cgpa >= 3.75) return 'Outstanding';
  if (cgpa >= 3.5) return 'Excellent';
  if (cgpa >= 3.0) return 'Good';
  if (cgpa >= 2.5) return 'Average';
  return 'Needs work';
}

/// Lowest marks out of 100 for each grade, on the UGC Bangladesh uniform scale,
/// paired with the grade points it earns. Checked from the top down.
const List<(double, double)> kMarkCutoffs = [
  (80, 4.0),
  (75, 3.75),
  (70, 3.5),
  (65, 3.25),
  (60, 3.0),
  (55, 2.75),
  (50, 2.5),
  (45, 2.25),
  (40, 2.0),
];

/// Grade points earned by [marks] out of 100. Below 40 is an F.
double gradePointsForMarks(double marks) {
  for (final (cutoff, points) in kMarkCutoffs) {
    // A hair of tolerance, so 79.999 from rounding still reads as 80.
    if (marks >= cutoff - 0.005) return points;
  }
  return 0.0;
}

/// Marks still needed to reach the next grade up, or null at the top.
double? marksToNextGrade(double marks) {
  for (final (cutoff, _) in kMarkCutoffs.reversed) {
    if (marks < cutoff - 0.005) return cutoff - marks;
  }
  return null;
}
