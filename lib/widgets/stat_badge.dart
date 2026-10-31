import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';

enum StatBadgeType { success, warning, error, info, neutral }

class StatBadge extends StatelessWidget {
  final String label;
  final StatBadgeType type;
  final IconData? icon;
  final bool showDot;

  const StatBadge({
    super.key,
    required this.label,
    this.type = StatBadgeType.info,
    this.icon,
    this.showDot = false,
  });

  factory StatBadge.fromStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'surplus' || s == 'completed' || s == 'paid' || s == 'active') {
      return StatBadge(
        label: status.toUpperCase(),
        type: StatBadgeType.success,
        showDot: true,
      );
    } else if (s == 'deficit' || s == 'overdue' || s == 'cancelled' || s == 'unpaid') {
      return StatBadge(
        label: status.toUpperCase(),
        type: StatBadgeType.error,
        showDot: true,
      );
    } else if (s == 'pending' || s == 'paused' || s == 'due_soon') {
      return StatBadge(
        label: status.toUpperCase(),
        type: StatBadgeType.warning,
        showDot: true,
      );
    }
    return StatBadge(
      label: status.toUpperCase(),
      type: StatBadgeType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case StatBadgeType.success:
        bg = AppColors.successBg;
        fg = AppColors.success;
        break;
      case StatBadgeType.warning:
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        break;
      case StatBadgeType.error:
        bg = AppColors.errorBg;
        fg = AppColors.error;
        break;
      case StatBadgeType.info:
        bg = AppColors.primarySurface;
        fg = AppColors.primary;
        break;
      case StatBadgeType.neutral:
        bg = const Color(0xFFF2F4F7);
        fg = const Color(0xFF475467);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
