import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;

import '../data/change_feed.dart';
import 'assignment_providers.dart';
import 'attendance_providers.dart';
import 'core_providers.dart';
import 'course_providers.dart';
import 'ct_mark_providers.dart';
import 'expense_providers.dart';
import 'notice_providers.dart';
import 'routine_providers.dart';
import 'semester_providers.dart';
import 'study_providers.dart';

/// A table's list on screen, and how to wait for it to load again.
class SyncedList {
  final ProviderBase<Object?> provider;
  final Future<Object?> Function(WidgetRef ref) load;

  const SyncedList(this.provider, this.load);
}

/// Each table's provider, so that a change on the server can reload just it.
/// A new table is added here and in `Tables.synced`.
final Map<String, SyncedList> kSyncedLists = {
  'profiles': SyncedList(
    profileProvider,
    (r) => r.read(profileProvider.future),
  ),
  'semesters': SyncedList(
    semesterListProvider,
    (r) => r.read(semesterListProvider.future),
  ),
  'vacations': SyncedList(
    vacationListProvider,
    (r) => r.read(vacationListProvider.future),
  ),
  'courses': SyncedList(
    courseListProvider,
    (r) => r.read(courseListProvider.future),
  ),
  'assignments': SyncedList(
    assignmentListProvider,
    (r) => r.read(assignmentListProvider.future),
  ),
  'notices': SyncedList(
    noticeListProvider,
    (r) => r.read(noticeListProvider.future),
  ),
  'class_slots': SyncedList(
    classSlotListProvider,
    (r) => r.read(classSlotListProvider.future),
  ),
  'attendance_records': SyncedList(
    attendanceListProvider,
    (r) => r.read(attendanceListProvider.future),
  ),
  'ct_marks': SyncedList(
    ctMarkListProvider,
    (r) => r.read(ctMarkListProvider.future),
  ),
  'study_sessions': SyncedList(
    studySessionListProvider,
    (r) => r.read(studySessionListProvider.future),
  ),
  'study_tasks': SyncedList(
    studyTaskListProvider,
    (r) => r.read(studyTaskListProvider.future),
  ),
  'exams': SyncedList(examListProvider, (r) => r.read(examListProvider.future)),
  'expenses': SyncedList(
    expenseListProvider,
    (r) => r.read(expenseListProvider.future),
  ),
};

/// True while the app is showing what was last saved on the device.
final offlineProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);

class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(currentUserIdProvider);
    final store = ref.watch(rowStoreProvider);
    void update() => state = store.isOffline;
    store.addListener(update);
    ref.onDispose(() => store.removeListener(update));
    return store.isOffline;
  }
}

final changeFeedProvider = Provider<ChangeFeed>(
  (ref) => SupabaseChangeFeed(ref.watch(supabaseClientProvider)),
);

/// Keeps the on-screen lists in step with the server: it reloads a table when
/// another device changes it, and everything once the connection returns.
final liveSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;

  final store = ref.read(rowStoreProvider);
  final dirty = <String>{};
  Timer? debounce;

  void reloadDirty() {
    for (final table in dirty) {
      final list = kSyncedLists[table];
      if (list != null) ref.invalidate(list.provider);
    }
    dirty.clear();
  }

  final stopFeed = ref.read(changeFeedProvider).listen(userId, (
    table,
    rowId, {
    required bool isDelete,
  }) {
    if (rowId != null) {
      if (store.isOwnRecentWrite(rowId)) return;
      if (isDelete && !store.hasSavedRow(table, rowId)) return;
    }
    dirty.add(table);
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), reloadDirty);
  });

  var wasOffline = store.isOffline;
  void onStoreChanged() {
    final cameBack = wasOffline && !store.isOffline;
    wasOffline = store.isOffline;
    if (cameBack) reloadEverything(ref.invalidate);
  }

  store.addListener(onStoreChanged);
  ref.onDispose(() {
    debounce?.cancel();
    stopFeed();
    store.removeListener(onStoreChanged);
  });
});

/// [invalidate] is either `Ref.invalidate` or `WidgetRef.invalidate`.
void reloadEverything(void Function(ProviderBase<Object?>) invalidate) {
  for (final list in kSyncedLists.values) {
    invalidate(list.provider);
  }
}

/// Reloads everything from the server, for pull to refresh. A section that
/// fails keeps its own error state, so one failure does not fail the gesture.
Future<void> refreshAll(WidgetRef ref) async {
  reloadEverything(ref.invalidate);
  await Future.wait<Object?>([
    for (final list in kSyncedLists.values)
      list.load(ref).then<Object?>((value) => value, onError: (_) => null),
  ]);
}
