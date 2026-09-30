import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

void showAppMessage(BuildContext context, String message,
    {bool isError = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? AppColors.error : AppColors.success,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}