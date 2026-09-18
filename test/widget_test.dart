import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seer/screens/provider_profile_screen.dart';

void main() {
  testWidgets('Provider profile screen builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProviderProfileScreen(),
    ));

    expect(find.byType(ProviderProfileScreen), findsOneWidget);
  });
}