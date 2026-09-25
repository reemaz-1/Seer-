import 'package:flutter/material.dart';

class ProviderCurrentOrder extends StatelessWidget {
  const ProviderCurrentOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا يوجد طلب حالي',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: 18,
          color: Color(0xFF69728C),
        ),
      ),
    );
  }
}