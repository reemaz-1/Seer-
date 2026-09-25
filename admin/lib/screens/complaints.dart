import 'package:flutter/material.dart';

class AdminComplaints extends StatelessWidget {
  const AdminComplaints({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا توجد شكاوى حالياً',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: Color(0xFF69728C),
          fontSize: 18,
        ),
      ),
    );
  }
}