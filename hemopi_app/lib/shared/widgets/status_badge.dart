import 'package:flutter/material.dart';

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
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        defaultIcon = Icons.check_circle_outline;
        break;
      case BadgeType.warning:
      case BadgeType.notReady:
      case BadgeType.validating:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case BadgeType.error:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        defaultIcon = Icons.error_outline;
        break;
      case BadgeType.measuring:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        defaultIcon = Icons.sensors;
        break;
      case BadgeType.info:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        defaultIcon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
