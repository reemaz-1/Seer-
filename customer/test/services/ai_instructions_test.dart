// Checks the instructions Gemini receives. No internet needed.
//
// The package is named `customer` (the name: line in pubspec.yaml).

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/models/service_catalog.dart';
import 'package:customer/services/ai_assistant.dart';
import 'package:customer/services/ai_instructions.dart';
import 'package:customer/services/fake_ai_assistant.dart';

void main() {
  const cars = FakeAiAssistant.sampleVehicles;

  group('AiInstructions.build', () {
    final text = AiInstructions.build(
      vehicles: cars,
      activeVehicleId: cars.first.id,
    );

    test('lists every service option id', () {
      for (final c in ServiceCatalog.categories) {
        for (final o in c.options) {
          expect(text, contains('optionId: ${o.id}'));
        }
      }
    });

    test('has a hint for every option', () {
      for (final c in ServiceCatalog.categories) {
        for (final o in c.options) {
          expect(AiInstructions.optionHints.keys, contains(o.id));
        }
      }
    });

    test('lists every vehicle and marks the active one', () {
      for (final v in cars) {
        expect(text, contains('vehicleId: ${v.id}'));
      }
      expect(text, contains('(vehicleId: ${cars.first.id}) ← المركبة الحالية'));
      expect(text, isNot(contains('(vehicleId: ${cars[1].id}) ←')));
    });

    test('does not send plate numbers to Gemini', () {
      for (final v in cars) {
        expect(text, isNot(contains(v.plateNumberLatin)));
        expect(text, isNot(contains(v.plateNumberArabic)));
      }
    });

    test('911 is advice only, with no calling', () {
      expect(text, contains('911'));
      expect(text, contains('ليس لديك أي أداة للاتصال'));
    });

    test('the model must not invent prices', () {
      expect(text, contains('لا تذكر سعرًا من عندك'));
    });

    test('includes the state the app writes', () {
      final withState = AiInstructions.build(
        vehicles: cars,
        activeVehicleId: cars.first.id,
        state: '- ملخص ينتظر تأكيد العميل (summaryId: C1-S1)',
      );
      expect(withState, contains('summaryId: C1-S1'));
    });

    test('tells Gemini that only the app announces a sent order', () {
      expect(text, contains('التطبيق وحده هو من يخبر العميل'));
    });

    test('without vehicles it explains how to add one', () {
      final empty = AiInstructions.build(vehicles: const [], activeVehicleId: null);
      expect(empty, contains('لا توجد مركبات'));
      expect(empty, contains('مركباتي'));
    });
  });

  group('FakeAiAssistant', () {
    test('plays the full order flow', () async {
      final fake = FakeAiAssistant(wordDelay: Duration.zero);

      final first = await fake.send('السيارة ما تشتغل').toList();
      final summary = first.whereType<AiOrderSummaryShown>().single.summary;
      expect(summary.categoryId, 'battery');

      final second = await fake.send('نعم').toList();
      expect(second.whereType<AiOrderPlaced>().single.summary, summary);
    });

    test('switching car cancels the waiting card', () async {
      final fake = FakeAiAssistant(wordDelay: Duration.zero);
      await fake.send('السيارة ما تشتغل').toList();

      final events = await fake.send('هذي للجمس').toList();
      expect(events.whereType<AiVehicleChanged>().single.vehicle,
          FakeAiAssistant.sampleVehicles[1]);
      expect(events.whereType<AiOrderSummaryCancelled>(), hasLength(1));
    });

    test('the map button can add a location to the waiting card', () async {
      final fake = FakeAiAssistant(wordDelay: Duration.zero);
      final events = await fake.send('السيارة ما تشتغل').toList();
      final id = events.whereType<AiOrderSummaryShown>().single.summary.id;

      expect(fake.updateSummaryLocation(id, pickup: FakeAiAssistant.samplePickup),
          isNotNull);
      expect(fake.updateSummaryLocation('old-card'), isNull);
    });

    test('sends an Arabic error when shouldFail is true', () {
      final fake = FakeAiAssistant(shouldFail: true);
      expect(fake.send('مرحبا').toList(), throwsA(isA<AiAssistantException>()));
    });
  });
}
