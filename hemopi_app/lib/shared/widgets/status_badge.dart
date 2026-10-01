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
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF0D8A58);
        defaultIcon = Icons.check_circle_rounded;
        break;
      case BadgeType.warning:
      case BadgeType.notReady:
      case BadgeType.validating:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        defaultIcon = Icons.info_rounded;
        break;
      case BadgeType.error:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        defaultIcon = Icons.error_rounded;
        break;
      case BadgeType.measuring:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        defaultIcon = Icons.sensors_rounded;
        break;
      case BadgeType.info:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
