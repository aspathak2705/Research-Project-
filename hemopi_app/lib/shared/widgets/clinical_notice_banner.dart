import 'package:flutter/material.dart';

/// Clinical research advisory banner communicating truthful device limits.
class ClinicalNoticeBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  const ClinicalNoticeBanner({
    super.key,
    this.title = 'Investigational Research Device',
    this.message =
        'HemoPi is an observational research prototype. Measurements are investigational and must not be used as the sole basis for diagnosis or medical treatment.',
    this.icon = Icons.shield_outlined,
    this.backgroundColor = const Color(0xFFFEF3C7),
    this.borderColor = const Color(0xFFFDE68A),
    this.iconColor = const Color(0xFFD97706),
    this.textColor = const Color(0xFF92400E),
  });

  const ClinicalNoticeBanner.info({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.backgroundColor = const Color(0xFFE0F2FE),
    this.borderColor = const Color(0xFFBAE6FD),
    this.iconColor = const Color(0xFF0284C7),
    this.textColor = const Color(0xFF0369A1),
  });

  const ClinicalNoticeBanner.gated({
    super.key,
    this.title = 'Sensor Calibration Pending',
    this.message =
        'Optical sensor physical validation is required before research acquisition. Simulated or mock values are strictly disabled.',
    this.icon = Icons.lock_clock_outlined,
    this.backgroundColor = const Color(0xFFFEF3C7),
    this.borderColor = const Color(0xFFFDE68A),
    this.iconColor = const Color(0xFFD97706),
    this.textColor = const Color(0xFF92400E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
