import 'package:flutter/material.dart';
import '../../app/design_tokens.dart';

enum BadgeType {
  success,
  ready,
  connected,
  warning,
  notReady,
  error,
  measuring,
  validating,
  info,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (type) {
      case BadgeType.success:
      case BadgeType.connected:
      case BadgeType.ready:
        bg = AppColors.statusSuccessBg;
        fg = AppColors.statusSuccess;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case BadgeType.warning:
      case BadgeType.notReady:
      case BadgeType.validating:
        bg = AppColors.statusWarningBg;
        fg = AppColors.statusWarning;
        defaultIcon = Icons.info_rounded;
        break;
      case BadgeType.error:
        bg = AppColors.statusErrorBg;
        fg = AppColors.statusError;
        defaultIcon = Icons.cancel_rounded;
        break;
      case BadgeType.measuring:
        bg = AppColors.primaryLight;
        fg = AppColors.primaryDark;
        defaultIcon = Icons.sensors_rounded;
        break;
      case BadgeType.info:
        bg = AppColors.statusInfoBg;
        fg = AppColors.statusInfo;
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? defaultIcon,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
