import 'package:flutter/material.dart';

class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا توجد خدمة نشطة للتتبع حالياً',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: 18,
          color: Color(0xFF6B7385),
        ),
      ),
    );
  }
}