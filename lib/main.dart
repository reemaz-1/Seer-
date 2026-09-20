import 'package:flutter/material.dart';

import 'screens/ServiceProvider/service_provider_main.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ServiceProviderMain(),
    );
  }
}