import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/semester.dart';
import '../utils/academic_calendar.dart';
import '../utils/date_utils.dart';
import 'core_providers.dart';
import 'course_providers.dart';
import 'personal_list_notifier.dart';

final semesterListProvider =
    AsyncNotifierProvider<SemesterListNotifier, List<Semester>>(
      SemesterListNotifier.new,
    );

class SemesterListNotifier extends PersonalListNotifier<Semester> {
  @override
  TableSpec<Semester> get spec => Tables.semesters;

  /// Earliest first.
  @override
  int compare(Semester a, Semester b) {
    final byStart = a.startsOn.compareTo(b.startsOn);
    return byStart != 0 ? byStart : a.createdAt.compareTo(b.createdAt);
  }

  /// Adds a semester. The first one a student adds becomes their current one,
  /// as does any they ask to switch to.
  Future<Semester> add({
    required String name,
    required DateTime startsOn,
    bool makeCurrent = false,
  }) async {
    final created = await insert(
      Semester(
        id: '',
        name: name,
        startsOn: AppDate.dayOf(startsOn),
        createdAt: DateTime.now(),
      ),
    );
    final profile = ref.read(profileProvider).value;
    if (makeCurrent || profile?.currentSemesterId == null) {
      await ref.read(profileProvider.notifier).setCurrentSemester(created.id);
    }
    return created;
  }

  /// Marks the semester's classes as over from [on], or reopens them with null.
  Future<void> setClassesEnded(String id, DateTime? on) async {
    await patch(id, {
      'classes_ended_on': on == null ? null : AppDate.toDbDate(on),
    });
  }

  /// The database deletes the semester's courses and vacations with it, and
  /// everything that belongs to those courses.
  Future<void> remove(String id) async {
    await delete(id);
    ref
      ..invalidate(vacationListProvider)
      ..invalidate(profileProvider);
    invalidateCourseData(ref);
  }
}

final vacationListProvider =
    AsyncNotifierProvider<VacationListNotifier, List<Vacation>>(
      VacationListNotifier.new,
    );

class VacationListNotifier extends PersonalListNotifier<Vacation> {
  @override
  TableSpec<Vacation> get spec => Tables.vacations;

  @override
  int compare(Vacation a, Vacation b) => a.startsOn.compareTo(b.startsOn);
}

final semesterByIdProvider = Provider<Map<String, Semester>>((ref) {
  final semesters = ref.watch(semesterListProvider).value ?? const <Semester>[];
  return {for (final semester in semesters) semester.id: semester};
});

/// The semester the student is in: the one chosen in Profile, or failing that
/// the latest one that has started.
final currentSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semesterListProvider).value ?? const <Semester>[];
  if (semesters.isEmpty) return null;
  final chosen = ref.watch(profileProvider).value?.currentSemesterId;
  final byId = ref.watch(semesterByIdProvider);
  if (chosen != null && byId[chosen] != null) return byId[chosen];
  final today = AppDate.dayOf(DateTime.now());
  final started = semesters.where((s) => !s.startsOn.isAfter(today));
  return started.isEmpty ? semesters.first : started.last;
});

/// Which semester the Semester tab is showing. Null means the current one.
final viewedSemesterIdProvider =
    NotifierProvider<ViewedSemesterNotifier, String?>(
      ViewedSemesterNotifier.new,
    );

class ViewedSemesterNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(currentUserIdProvider);
    return null;
  }

  void show(String? semesterId) => state = semesterId;
}

final viewedSemesterProvider = Provider<Semester?>((ref) {
  final id = ref.watch(viewedSemesterIdProvider);
  return (id == null ? null : ref.watch(semesterByIdProvider)[id]) ??
      ref.watch(currentSemesterProvider);
});

final vacationsForSemesterProvider = Provider.family<List<Vacation>, String>((
  ref,
  semesterId,
) {
  final all = ref.watch(vacationListProvider).value ?? const <Vacation>[];
  return all.where((v) => v.semesterId == semesterId).toList(growable: false);
});

/// A calendar for any semester id, null included, built once per change.
final calendarLookupProvider = Provider<AcademicCalendar Function(String?)>((
  ref,
) {
  final semesters = ref.watch(semesterByIdProvider);
  final vacations = ref.watch(vacationListProvider).value ?? const <Vacation>[];
  final calendars = <String, AcademicCalendar>{
    for (final semester in semesters.values)
      semester.id: AcademicCalendar(
        semester: semester,
        vacations: vacations
            .where((v) => v.semesterId == semester.id)
            .toList(growable: false),
      ),
  };
  const none = AcademicCalendar();
  return (id) => id == null ? none : (calendars[id] ?? none);
});

/// Where the current semester stands today.
class SemesterToday {
  final Semester semester;

  /// Null before the semester starts.
  final int? week;
  final Vacation? vacation;

  const SemesterToday({required this.semester, this.week, this.vacation});

  String get label {
    if (semester.hasEnded &&
        AppDate.dayOf(DateTime.now()).isAfter(semester.classesEndedOn!)) {
      return '${semester.name}  ·  Classes over';
    }
    if (week == null) {
      return '${semester.name}  ·  Starts ${AppDate.dayMonth(semester.startsOn)}';
    }
    return vacation == null
        ? '${semester.name}  ·  Week $week'
        : '${semester.name}  ·  ${vacation!.title.isEmpty ? 'Vacation' : vacation!.title}';
  }
}

final semesterTodayProvider = Provider<SemesterToday?>((ref) {
  final semester = ref.watch(currentSemesterProvider);
  if (semester == null) return null;
  final calendar = ref.watch(calendarLookupProvider)(semester.id);
  final today = DateTime.now();
  return SemesterToday(
    semester: semester,
    week: calendar.weekNumber(today),
    vacation: calendar.vacationOn(today),
  );
});
