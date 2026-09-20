import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1B33),
        foregroundColor: Colors.white,
        title: const Text('الإشعارات'),
        centerTitle: true,
      ),

      body: const Center(
        child: Text(
          'لا توجد إشعارات حالياً',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF6B7385),
          ),
        ),
      ),
    );
  }
}