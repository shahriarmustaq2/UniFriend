import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/profile.dart';
import '../models/study_plan.dart';
import '../models/study_session.dart';
import '../utils/date_utils.dart';
import '../utils/study_stats.dart';
import 'core_providers.dart';
import 'personal_list_notifier.dart';

final studySessionListProvider =
    AsyncNotifierProvider<StudySessionListNotifier, List<StudySession>>(
      StudySessionListNotifier.new,
    );

class StudySessionListNotifier extends PersonalListNotifier<StudySession> {
  @override
  TableSpec<StudySession> get spec => Tables.studySessions;

  /// Newest first.
  @override
  int compare(StudySession a, StudySession b) {
    final byDay = b.studiedOn.compareTo(a.studiedOn);
    return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
  }
}

final studyTaskListProvider =
    AsyncNotifierProvider<StudyTaskListNotifier, List<StudyTask>>(
      StudyTaskListNotifier.new,
    );

class StudyTaskListNotifier extends PersonalListNotifier<StudyTask> {
  @override
  TableSpec<StudyTask> get spec => Tables.studyTasks;

  /// By planned day, then in the order they were added.
  @override
  int compare(StudyTask a, StudyTask b) {
    final byDay = a.plannedFor.compareTo(b.plannedFor);
    return byDay != 0 ? byDay : a.createdAt.compareTo(b.createdAt);
  }

  Future<void> setDone(String id, bool isDone) =>
      patch(id, {'is_done': isDone});
}

final examListProvider = AsyncNotifierProvider<ExamListNotifier, List<Exam>>(
  ExamListNotifier.new,
);

class ExamListNotifier extends PersonalListNotifier<Exam> {
  @override
  TableSpec<Exam> get spec => Tables.exams;

  /// Soonest first.
  @override
  int compare(Exam a, Exam b) {
    final byDay = a.heldOn.compareTo(b.heldOn);
    return byDay != 0 ? byDay : a.createdAt.compareTo(b.createdAt);
  }

  /// Topics linked to the exam lose the link, which the database clears.
  Future<void> remove(String id) async {
    await delete(id);
    ref.invalidate(studyTaskListProvider);
  }
}

/// When the running study timer started, or null when it is stopped. Only the
/// start time is kept, on the device, so the timer keeps counting while the app
/// is closed or even killed.
final studyTimerProvider = NotifierProvider<StudyTimerNotifier, DateTime?>(
  StudyTimerNotifier.new,
);

class StudyTimerNotifier extends Notifier<DateTime?> {
  /// A timer belongs to whoever started it, so each student has their own.
  String? get _key {
    final user = ref.read(currentUserIdProvider);
    return user == null ? null : 'study_timer.$user';
  }

  @override
  DateTime? build() {
    ref.watch(currentUserIdProvider);
    final key = _key;
    if (key == null) return null;
    final saved = ref.read(sharedPreferencesProvider).getString(key);
    return saved == null ? null : DateTime.tryParse(saved);
  }

  void start() {
    final now = DateTime.now();
    state = now;
    final key = _key;
    if (key != null) {
      ref.read(sharedPreferencesProvider).setString(key, now.toIso8601String());
    }
  }

  void stop() {
    state = null;
    final key = _key;
    if (key != null) ref.read(sharedPreferencesProvider).remove(key);
  }
}

final studyMinutesThisWeekProvider = Provider<int>((ref) {
  final all =
      ref.watch(studySessionListProvider).value ?? const <StudySession>[];
  return StudyStats.minutesThisWeek(all);
});

final studyMinutesTodayProvider = Provider<int>((ref) {
  final all =
      ref.watch(studySessionListProvider).value ?? const <StudySession>[];
  return StudyStats.minutesOn(all, DateTime.now());
});

/// The student's weekly target, in minutes.
final weeklyStudyGoalProvider = Provider<int>((ref) {
  return ref.watch(profileProvider).value?.weeklyStudyGoalMinutes ??
      kDefaultWeeklyStudyGoalMinutes;
});

/// Today's plan: what is planned for today, plus anything left unfinished from
/// earlier days, which carries over. Finished items from today stay visible,
/// ticked, so the list does not jump about.
final todayPlanProvider = Provider<List<StudyTask>>((ref) {
  final all = ref.watch(studyTaskListProvider).value ?? const <StudyTask>[];
  final today = AppDate.dayOf(DateTime.now());
  return all
      .where(
        (t) =>
            t.plannedFor == today ||
            (!t.isDone && t.plannedFor.isBefore(today)),
      )
      .toList(growable: false);
});

/// Tasks planned for later days, soonest first.
final upcomingPlanProvider = Provider<List<StudyTask>>((ref) {
  final all = ref.watch(studyTaskListProvider).value ?? const <StudyTask>[];
  final today = AppDate.dayOf(DateTime.now());
  return all.where((t) => t.plannedFor.isAfter(today)).toList(growable: false);
});

/// Exams from today on, soonest first.
final upcomingExamsProvider = Provider<List<Exam>>((ref) {
  final all = ref.watch(examListProvider).value ?? const <Exam>[];
  final today = AppDate.dayOf(DateTime.now());
  return all.where((e) => !e.heldOn.isBefore(today)).toList(growable: false);
});

/// How many of an exam's topics are done, out of how many.
final examProgressProvider = Provider.family<(int, int), String>((ref, examId) {
  final all = ref.watch(studyTaskListProvider).value ?? const <StudyTask>[];
  final linked = all.where((t) => t.examId == examId);
  return (linked.where((t) => t.isDone).length, linked.length);
});
