// Unit tests for the order rules the AI must follow. No internet needed.
//
// Run with:  flutter test test/services/
//
// The package is named `customer` (the name: line in pubspec.yaml).

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/models/pricing_model.dart';
import 'package:customer/models/vehicle.dart';
import 'package:customer/services/ai_assistant.dart';
import 'package:customer/services/ai_order_actions.dart';
import 'package:customer/services/ai_tool_handler.dart';

const camry = Vehicle(
  id: 'v-camry',
  brand: 'تويوتا',
  model: 'كامري',
  year: 2022,
  color: 'أبيض',
  plateNumberArabic: '1234 ابد',
  plateNumberLatin: '1234 ABD',
);

const yukon = Vehicle(
  id: 'v-yukon',
  brand: 'جي إم سي',
  model: 'يوكن',
  year: 2019,
  color: 'أسود',
  plateNumberArabic: '9821 كرس',
  plateNumberLatin: '9821 KRS',
);

/// Records what the AI tried to do instead of writing to Firestore.
class FakeOrderActions implements AiOrderActions {
  final placed = <OrderSummary>[];
  AiOrderException? failWith;

  /// What GPS returns; set to null to simulate GPS failing.
  GeoPoint? gps = const GeoPoint(24.7136, 46.6753);
  int gpsReads = 0;

  @override
  Future<GeoPoint?> currentLocation() async {
    gpsReads++;
    return gps;
  }

  @override
  Future<List<Vehicle>> loadVehicles() async => const [camry, yukon];

  @override
  Future<ServicePrices> loadPrices() async => ServicePrices.fallback();

  @override
  Future<String> placeOrder(OrderSummary summary) async {
    if (failWith != null) throw failWith!;
    placed.add(summary);
    return 'order-${placed.length}';
  }
}

void main() {
  late FakeOrderActions actions;
  late AiToolHandler handler;

  setUp(() {
    actions = FakeOrderActions();
    handler = AiToolHandler(
      actions: actions,
      vehicles: const [camry, yukon],
      activeVehicleId: camry.id,
    );
  });

  Future<AiToolOutcome> showBatterySummary({
    int turn = 1,
    String vehicleId = 'v-camry',
  }) {
    return handler.handle(AiToolHandler.showSummaryName, {
      'vehicleId': vehicleId,
      'categoryId': 'battery',
      'optionId': 'activation',
      'note': 'السيارة لا تشتغل',
    }, turn: turn);
  }

  group('starting vehicle', () {
    test('uses the preferred vehicle', () {
      expect(handler.activeVehicle, camry);
    });

    test('falls back to the first vehicle when the id is unknown', () {
      final h = AiToolHandler(
        actions: actions,
        vehicles: const [yukon, camry],
        activeVehicleId: 'deleted-car',
      );
      expect(h.activeVehicle, yukon);
    });

    test('no vehicles means no functions are offered to the model', () {
      expect(AiToolHandler.declarations(const []), isEmpty);
      expect(AiToolHandler.declarations(const [camry]), hasLength(3));
    });
  });

  group('show_order_summary', () {
    test('builds the summary with the app price, not a model price', () async {
      final outcome = await showBatterySummary();

      expect(outcome.ok, isTrue);
      final summary = handler.pendingSummary!;
      expect(summary.vehicle, camry);
      expect(summary.optionId, 'activation');
      expect(summary.estimatedPrice,
          ServicePrices.fallback().basePriceFor('activation'));
      expect(summary.needsDropoff, isFalse);
      expect(outcome.events.last, isA<AiOrderSummaryShown>());
    });

    test('towing is marked as needing a drop-off', () async {
      await handler.handle(AiToolHandler.showSummaryName, {
        'vehicleId': 'v-camry',
        'categoryId': 'towing',
        'optionId': 'regular',
      }, turn: 1);

      expect(handler.pendingSummary!.needsDropoff, isTrue);
      expect(handler.pendingSummary!.priceDependsOnDistance, isTrue);
    });

    test('refuses an option from another category', () async {
      final outcome = await handler.handle(AiToolHandler.showSummaryName, {
        'vehicleId': 'v-camry',
        'categoryId': 'fuel',
        'optionId': 'patch',
      }, turn: 1);

      expect(outcome.ok, isFalse);
      expect(handler.pendingSummary, isNull);
    });

    test('refuses a vehicle that is not the customer\'s', () async {
      final outcome = await showBatterySummary(vehicleId: 'someone-else');

      expect(outcome.ok, isFalse);
      expect(handler.pendingSummary, isNull);
    });

    test('a summary for another car switches the active vehicle', () async {
      final outcome = await showBatterySummary(vehicleId: 'v-yukon');

      expect(handler.activeVehicle, yukon);
      expect(outcome.events.first, isA<AiVehicleChanged>());
    });

    test('a new summary cancels the previous card', () async {
      await showBatterySummary(turn: 1);
      final second = await showBatterySummary(turn: 2);

      expect(handler.pendingSummary!.id, 'S2');
      final cancelled = second.events.whereType<AiOrderSummaryCancelled>();
      expect(cancelled.single.summaryId, 'S1');
    });

    test('ids carry the chat prefix, so they never repeat after a restart',
        () async {
      final h = AiToolHandler(
        actions: actions,
        vehicles: const [camry],
        summaryIdPrefix: 'C2-',
      );
      await h.handle(AiToolHandler.showSummaryName, {
        'vehicleId': 'v-camry',
        'categoryId': 'battery',
        'optionId': 'activation',
      }, turn: 1);

      expect(h.pendingSummary!.id, 'C2-S1');
    });

    test('a long note is cut to 200 characters', () async {
      await handler.handle(AiToolHandler.showSummaryName, {
        'vehicleId': 'v-camry',
        'categoryId': 'battery',
        'optionId': 'activation',
        'note': 'ا' * 500,
      }, turn: 1);

      expect(handler.pendingSummary!.note.length, AiToolHandler.maxNoteLength);
    });
  });

  group('place_order', () {
    test('places the order after the customer replies', () async {
      await showBatterySummary(turn: 1);
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 2,
      );

      expect(outcome.ok, isTrue);
      expect(actions.placed, hasLength(1));
      expect(outcome.events.single, isA<AiOrderPlaced>());
      expect(handler.pendingSummary, isNull);
    });

    test('refuses in the same message that showed the card', () async {
      await showBatterySummary(turn: 1);
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 1,
      );

      expect(outcome.ok, isFalse);
      expect(actions.placed, isEmpty);
    });

    test('refuses when no card was shown', () async {
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 5,
      );

      expect(outcome.ok, isFalse);
      expect(actions.placed, isEmpty);
    });

    test('refuses an old card id', () async {
      await showBatterySummary(turn: 1);
      await showBatterySummary(turn: 2); // S2 replaces S1
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 3,
      );

      expect(outcome.ok, isFalse);
      expect(actions.placed, isEmpty);
    });

    test('the same card cannot be placed twice', () async {
      await showBatterySummary(turn: 1);
      await handler.handle(AiToolHandler.placeOrderName, {'summaryId': 'S1'},
          turn: 2);
      final again = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 3,
      );

      expect(again.ok, isFalse);
      expect(actions.placed, hasLength(1));
    });

    test('a failed write is reported and the card stays', () async {
      actions.failWith = const AiOrderException('لم يتم إرسال الطلب.');
      await showBatterySummary(turn: 1);
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 2,
      );

      expect(outcome.ok, isFalse);
      expect(outcome.result['error'], contains('لم يتم إرسال الطلب.'));
      expect(handler.pendingSummary, isNotNull); // can retry
    });
  });

  group('locations', () {
    const mapPoint = GeoPoint(24.80, 46.60);
    const destination = GeoPoint(24.77, 46.74);

    Future<AiToolOutcome> place(int turn) => handler.handle(
          AiToolHandler.placeOrderName,
          {'summaryId': handler.pendingSummary?.id ?? 'S1'},
          turn: turn,
        );

    test('the pickup comes from GPS automatically', () async {
      final outcome = await showBatterySummary();

      expect(handler.pendingSummary!.pickupLocation, actions.gps);
      expect(outcome.result['pickupLocationSet'], isTrue);
      // Coordinates are never sent to Gemini.
      expect(outcome.result.values, isNot(contains(actions.gps)));
    });

    test('GPS is read once per chat, not for every summary', () async {
      await showBatterySummary(turn: 1);
      await showBatterySummary(turn: 2);

      expect(actions.gpsReads, 1);
    });

    test('without GPS the card is shown but cannot be sent', () async {
      actions.gps = null;
      final shown = await showBatterySummary(turn: 1);
      expect(shown.ok, isTrue);
      expect(handler.pendingSummary!.missingLocationMessage, 'حدد موقع المركبة');

      final refused = await place(2);
      expect(refused.ok, isFalse);
      expect(actions.placed, isEmpty);
    });

    test('a point picked on the map fixes it', () async {
      actions.gps = null;
      await showBatterySummary(turn: 1);

      final updated = handler.updateLocation('S1', pickup: mapPoint);
      expect(updated!.pickupLocation, mapPoint);

      final sent = await place(2);
      expect(sent.ok, isTrue);
      expect(actions.placed.single.pickupLocation, mapPoint);
    });

    test('towing waits for the drop-off point', () async {
      await handler.handle(AiToolHandler.showSummaryName, {
        'vehicleId': 'v-camry',
        'categoryId': 'towing',
        'optionId': 'regular',
      }, turn: 1);
      expect(handler.pendingSummary!.missingLocationMessage, 'حدد موقع التوصيل');
      expect((await place(2)).ok, isFalse);

      handler.updateLocation('S1', dropoff: destination);
      final sent = await place(3);

      expect(sent.ok, isTrue);
      expect(actions.placed.single.dropoffLocation, destination);
    });

    test('a non-towing order never carries a drop-off point', () async {
      await showBatterySummary();
      final updated = handler.updateLocation('S1', dropoff: destination);

      expect(updated!.dropoffLocation, isNull);
    });

    test('updating a card that is not waiting does nothing', () async {
      await showBatterySummary(turn: 1);
      await showBatterySummary(turn: 2); // S2 replaces S1

      expect(handler.updateLocation('S1', pickup: mapPoint), isNull);
      expect(handler.pendingSummary!.pickupLocation, actions.gps);
    });
  });

  group('set_active_vehicle', () {
    test('switches the car and cancels a card for the old car', () async {
      await showBatterySummary(turn: 1);
      final outcome = await handler.handle(
        AiToolHandler.setVehicleName,
        {'vehicleId': 'v-yukon'},
        turn: 2,
      );

      expect(outcome.ok, isTrue);
      expect(handler.activeVehicle, yukon);
      expect(handler.pendingSummary, isNull);
      expect(outcome.events[0], isA<AiVehicleChanged>());
      expect(outcome.events[1], isA<AiOrderSummaryCancelled>());
    });

    test('choosing the same car changes nothing', () async {
      final outcome = await handler.handle(
        AiToolHandler.setVehicleName,
        {'vehicleId': 'v-camry'},
        turn: 1,
      );

      expect(outcome.ok, isTrue);
      expect(outcome.events, isEmpty);
    });

    test('refuses an unknown car', () async {
      final outcome = await handler.handle(
        AiToolHandler.setVehicleName,
        {'vehicleId': 'v-tesla'},
        turn: 1,
      );

      expect(outcome.ok, isFalse);
      expect(handler.activeVehicle, camry);
    });
  });

  group('what the app says after a function (firebase_ai 2.x workaround)', () {
    test('a complete card asks for confirmation', () async {
      final outcome = await showBatterySummary();
      expect(outcome.reply, 'هل تؤكد الطلب؟');
    });

    test('a card without a location asks for it instead', () async {
      actions.gps = null;
      final outcome = await showBatterySummary();
      expect(outcome.reply, contains('حدد موقع المركبة'));
    });

    test('only the app announces a sent order', () async {
      await showBatterySummary(turn: 1);
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 2,
      );
      expect(outcome.reply, contains('تم إرسال طلبك'));
    });

    test('a failed write is explained in Arabic', () async {
      actions.failWith = const AiOrderException('هذه المركبة لم تعد موجودة في حسابك.');
      await showBatterySummary(turn: 1);
      final outcome = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 2,
      );
      expect(outcome.reply, contains('لم يُرسل الطلب'));
      expect(outcome.reply, contains('لم تعد موجودة'));
    });

    test('confirming twice says it was already sent', () async {
      await showBatterySummary(turn: 1);
      await handler.handle(AiToolHandler.placeOrderName, {'summaryId': 'S1'},
          turn: 2);
      final again = await handler.handle(
        AiToolHandler.placeOrderName,
        {'summaryId': 'S1'},
        turn: 3,
      );
      expect(again.reply, contains('مسبقًا'));
    });
  });

  group('describeState (what Gemini is told before each message)', () {
    test('names the active car and that nothing is waiting', () {
      final state = handler.describeState();
      expect(state, contains('vehicleId: v-camry'));
      expect(state, contains('لا يوجد ملخص'));
    });

    test('names the waiting card by id', () async {
      await showBatterySummary();
      final state = handler.describeState();
      expect(state, contains('summaryId: S1'));
      expect(state, contains('مكتملة'));
    });

    test('says what location is missing', () async {
      actions.gps = null;
      await showBatterySummary();
      expect(handler.describeState(), contains('حدد موقع المركبة'));
    });

    test('remembers a sent order so it is not sent again', () async {
      await showBatterySummary(turn: 1);
      await handler.handle(AiToolHandler.placeOrderName, {'summaryId': 'S1'},
          turn: 2);
      final state = handler.describeState();
      expect(state, contains('لا يوجد ملخص'));
      expect(state, contains('لا ترسله مرة أخرى'));
    });

    test('never contains coordinates', () async {
      await showBatterySummary();
      expect(handler.describeState(), isNot(contains('24.7136')));
    });
  });

  test('an unknown function is refused', () async {
    final outcome = await handler.handle('call_911', {}, turn: 1);
    expect(outcome.ok, isFalse);
  });
}
