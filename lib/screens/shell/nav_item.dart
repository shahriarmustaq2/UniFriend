import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_shell.dart';

/// One tab in the glass navigation bar. The label only appears on the active
/// tab, which is what keeps five of them on one row.
class NavItem extends StatelessWidget {
  final AppTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 12 : 9,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? tab.activeIcon : tab.icon,
                size: 21,
                color: isActive ? AppColors.primaryMedium : AppColors.textHint,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: isActive
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          tab.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryMedium,
                          ),
                        ),
                      )
                    : const SizedBox(width: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
