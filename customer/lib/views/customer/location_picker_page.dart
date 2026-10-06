import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Screen where the customer will select a location from a map.
///
/// The actual map widget will be added after the map provider is confirmed.
class LocationPickerPage extends StatelessWidget {
  const LocationPickerPage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: CustomerColors.fieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CustomerColors.cardBorder,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: CustomerColors.secondaryText,
                ),
                SizedBox(height: 12),
                Text(
                  'سيتم عرض الخريطة هنا',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CustomerColors.primaryText,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'سيتم تفعيل اختيار الموقع بعد ربط خدمة الخرائط',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}