import '../models/study_session.dart';
import 'date_utils.dart';

/// Pure study arithmetic, kept free of Flutter so it can be unit tested.
class StudyStats {
  StudyStats._();

  /// "1h 20m", "45m" or "2h". The form used everywhere study time is shown.
  static String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  static int minutesOn(Iterable<StudySession> sessions, DateTime day) {
    final target = AppDate.dayOf(day);
    return sessions
        .where((s) => AppDate.dayOf(s.studiedOn) == target)
        .fold(0, (sum, s) => sum + s.minutes);
  }

  /// Minutes in the week containing [now], which starts on [AppDate.weekStart].
  static int minutesThisWeek(Iterable<StudySession> sessions, {DateTime? now}) {
    final start = AppDate.startOfWeek(now ?? DateTime.now());
    final end = AppDate.addDays(start, 7);
    return sessions
        .where((s) => !s.studiedOn.isBefore(start) && s.studiedOn.isBefore(end))
        .fold(0, (sum, s) => sum + s.minutes);
  }
}
