import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tables.dart';
import '../models/notice.dart';
import 'personal_list_notifier.dart';

final noticeListProvider =
    AsyncNotifierProvider<NoticeListNotifier, List<Notice>>(
      NoticeListNotifier.new,
    );

class NoticeListNotifier extends PersonalListNotifier<Notice> {
  @override
  TableSpec<Notice> get spec => Tables.notices;

  /// Pinned notices first, then the newest of the rest.
  @override
  int compare(Notice a, Notice b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  Future<void> togglePinned(String id, bool isPinned) =>
      patch(id, {'is_pinned': isPinned});
}

final pinnedNoticesProvider = Provider<List<Notice>>((ref) {
  final all = ref.watch(noticeListProvider).value ?? const <Notice>[];
  return all.where((n) => n.isPinned).toList(growable: false);
});
