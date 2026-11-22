import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/class_slot.dart';
import '../utils/academic_calendar.dart';
import '../utils/date_utils.dart';
import 'course_providers.dart';
import 'personal_list_notifier.dart';
import 'semester_providers.dart';

final classSlotListProvider =
    AsyncNotifierProvider<ClassSlotListNotifier, List<ClassSlot>>(
      ClassSlotListNotifier.new,
    );

class ClassSlotListNotifier extends PersonalListNotifier<ClassSlot> {
  @override
  TableSpec<ClassSlot> get spec => Tables.classSlots;

  @override
  int compare(ClassSlot a, ClassSlot b) => a.startMinute != b.startMinute
      ? a.startMinute.compareTo(b.startMinute)
      : a.id.compareTo(b.id);
}

/// Every weekly slot on one weekday, earliest first, whether or not it runs on
/// a particular date. Used for clash warnings.
final slotsOnWeekdayProvider = Provider.family<List<ClassSlot>, int>((
  ref,
  weekday,
) {
  final all = ref.watch(classSlotListProvider).value ?? const <ClassSlot>[];
  return all.where((s) => s.weekday == weekday).toList(growable: false);
});

/// The classes that take place on one date: alternate weeks, vacations and
/// ended courses already accounted for. Cancelled classes are still listed,
/// with their cancellation shown on the card.
final classesOnDayProvider = Provider.family<List<ClassOccurrence>, DateTime>((
  ref,
  day,
) {
  final slots = ref.watch(classSlotListProvider).value ?? const <ClassSlot>[];
  return classesOn(
    AppDate.dayOf(day),
    slots: slots,
    courses: ref.watch(courseByIdProvider),
    calendarFor: ref.watch(calendarLookupProvider),
  );
});

/// The slots of one course, for its page.
final slotsForCourseProvider = Provider.family<List<ClassSlot>, String>((
  ref,
  courseId,
) {
  final all = ref.watch(classSlotListProvider).value ?? const <ClassSlot>[];
  return all.where((s) => s.courseId == courseId).toList(growable: false);
});
