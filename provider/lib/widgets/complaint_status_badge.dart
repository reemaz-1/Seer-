import 'package:flutter/material.dart';

import '../controllers/my_complaints_controller.dart';
import '../theme/app_colors.dart';

/// A small coloured label that shows the status of a complaint:
/// amber "under review" or green "resolved", each with an icon.
class ComplaintStatusBadge extends StatelessWidget {
  const ComplaintStatusBadge({super.key, required this.resolved});

  /// True when the complaint was resolved by the admin.
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.success : const Color(0xFF8A5B00);
    final background =
        resolved ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4DB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolved ? Icons.check_circle_outline : Icons.hourglass_top_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            resolved
                ? MyComplaintsController.resolvedLabel
                : MyComplaintsController.pendingLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}