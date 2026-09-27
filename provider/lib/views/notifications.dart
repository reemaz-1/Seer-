import 'package:flutter/material.dart';

class ProviderNotifications extends StatelessWidget {
  const ProviderNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF1F4FA),
        foregroundColor: const Color(0xFF0E1B33),
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 55,
              color: Color(0xFF69728C),
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد إشعارات حالياً',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFF0E1B33),
              ),
            ),
          ],
        ),
      ),
    );
  }
}