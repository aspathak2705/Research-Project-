import 'package:flutter/material.dart';
import '../../app/design_tokens.dart';

/// Reusable high-contrast clinical key-value row with overflow protection.
class ClinicalDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final bool isMuted;

  const ClinicalDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            flex: 6,
            child: trailing ??
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMuted ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
          ),
        ],
      ),
    );
  }
}
