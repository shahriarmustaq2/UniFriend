import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notice.dart';
import '../../providers/notice_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_fab.dart';
import '../../widgets/notice_tile.dart';
import 'notice_editor_sheet.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  /// Notices the student has opened on this screen. Ids, not objects, so the
  /// expanded set survives a refetch after an edit.
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(noticeListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'New notice',
        onPressed: () => showNoticeEditor(context),
      ),
      body: AsyncView<List<Notice>>(
        value: notices,
        onRetry: () => ref.invalidate(noticeListProvider),
        builder: (context, items) {
          if (items.isEmpty) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                const SizedBox(height: 40),
                EmptyState(
                  icon: Icons.campaign_outlined,
                  accent: AppColors.cyan,
                  title: 'No notices yet',
                  message: 'Keep exam dates, renewals and reminders here\nso they stop living in your head.',
                  actionLabel: 'Add your first notice',
                  onAction: () => showNoticeEditor(context),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notice = items[index];
              return NoticeTile(
                notice: notice,
                expanded: _expanded.contains(notice.id),
                onToggleExpanded: () => setState(() {
                  if (!_expanded.remove(notice.id)) _expanded.add(notice.id);
                }),
                onPinToggle: () => _togglePin(notice),
                onEdit: () => showNoticeEditor(context, notice: notice),
                onDelete: () => _delete(notice),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _togglePin(Notice notice) {
    return runAction(
      context,
      () => ref
          .read(noticeListProvider.notifier)
          .togglePinned(notice.id, !notice.isPinned),
    );
  }

  Future<void> _delete(Notice notice) async {
    final confirmed = await confirm(
      context,
      title: 'Delete notice?',
      message: '"${notice.title}" will be removed for good.',
    );
    if (!confirmed || !mounted) return;
    await runAction(
      context,
      () => ref.read(noticeListProvider.notifier).delete(notice.id),
      successMessage: 'Notice deleted',
    );
  }
}
