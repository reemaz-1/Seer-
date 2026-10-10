// Local visual preview only: fake orders, fake GPS, no Firebase initialization.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/controllers/provider_requests_controller.dart';
import 'package:provider/views/available_requests.dart';

import '../test/requests/request_fakes.dart';

/// Takes no inputs; launches a clearly labelled, backend-free UI preview.
void main() => runApp(const _Preview());

class _Preview extends StatefulWidget {
  /// Takes no inputs; creates the local preview host.
  const _Preview();

  /// Takes no inputs; returns state owning fixtures and timers.
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final repository = FakeRequests();
  final location = FakeLocation();
  late final ProviderRequestsController controller;
  final addresses = FakeAddresses();

  /// Takes no inputs; starts fake snapshots and seeds sample requests.
  @override
  void initState() {
    super.initState();
    controller = ProviderRequestsController(
      providerId: 'p1',
      repository: repository,
      location: location,
    )..start();
    final now = DateTime.now();
    repository.stream.add([
      requestFixture(now),
      requestFixture(
        now,
        id: 'battery-preview',
        overrides: {
          'serviceCategoryId': 'battery',
          'serviceCategoryLabel': 'خدمة البطارية',
          'serviceOptionLabel': 'تشغيل البطارية (اشتراك)',
          'estimatedPrice': 80,
        },
      ),
    ]);
  }

  /// Takes no inputs; releases preview timers and streams.
  @override
  void dispose() {
    controller.dispose();
    repository.stream.close();
    location.stream.close();
    super.dispose();
  }

  /// Takes [context]; returns an Arabic preview with explicit test-data labelling.
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C63D6)),
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('معاينة محلية — بيانات تجريبية')),
      body: AvailableRequests(
        controller: controller,
        addresses: addresses,
        onAccepted: () {},
      ),
    ),
  );
}
