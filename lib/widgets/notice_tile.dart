import 'package:flutter/material.dart';

import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'glass_container.dart';

/// One notice card. Used on the dashboard (collapsed) and on the notices tab
/// (expandable).
class NoticeTile extends StatelessWidget {
  final Notice notice;

  /// Null while the body is collapsed; set on the notices tab.
  final VoidCallback? onToggleExpanded;
  final bool expanded;
  final VoidCallback? onPinToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const NoticeTile({
    super.key,
    required this.notice,
    this.onToggleExpanded,
    this.expanded = false,
    this.onPinToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasBody = notice.body != null;

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PinnedMark(isPinned: notice.isPinned),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: (onToggleExpanded != null && hasBody)
                      ? onToggleExpanded
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        maxLines: expanded ? null : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      if (hasBody) ...[
                        const SizedBox(height: 4),
                        Text(
                          notice.body!,
                          maxLines: expanded ? null : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onPinToggle != null)
                _TileAction(
                  icon: notice.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  tooltip: notice.isPinned ? 'Unpin' : 'Pin',
                  active: notice.isPinned,
                  onTap: onPinToggle!,
                ),
              if (onEdit != null || onDelete != null) _buildMenu(context),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              AppDate.dayMonthYear(notice.createdAt),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      useRootNavigator: true,
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: Colors.white.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit', style: TextStyle(color: Colors.white)),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
      ],
    );
  }
}

class _PinnedMark extends StatelessWidget {
  final bool isPinned;

  const _PinnedMark({required this.isPinned});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPinned
            ? AppColors.warning.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.07),
      ),
      child: Icon(
        isPinned ? Icons.push_pin_rounded : Icons.campaign_outlined,
        size: 11,
        color: isPinned
            ? AppColors.warning
            : Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _TileAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: active
                ? AppColors.warning
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
