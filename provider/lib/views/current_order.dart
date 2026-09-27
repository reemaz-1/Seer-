import 'package:flutter/material.dart';

class ProviderCurrentOrder extends StatelessWidget {
  const ProviderCurrentOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Color(0xFF9AA4B8),
          ),
          SizedBox(height: 16),
          Text(
            'لا يوجد طلب حالي',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF69728C),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ستظهر تفاصيل الطلب هنا عند قبول طلب جديد',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9AA4B8),
            ),
          ),
        ],
      ),
    );
  }
}