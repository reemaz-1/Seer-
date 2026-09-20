import 'package:flutter/material.dart';

class ProviderHistory extends StatelessWidget {
  const ProviderHistory({super.key});


  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا يوجد سجل للطلبات حتى الآن',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: 18,
          color: Color(0xFF69728C),
        ),
      ),
    );
  }
}