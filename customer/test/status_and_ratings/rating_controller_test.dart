import 'dart:async';

import 'package:customer/controllers/rating_controller.dart';
import 'package:customer/models/order.dart';
import 'package:customer/models/rating_model.dart';
import 'package:flutter_test/flutter_test.dart';

class Ratings extends RatingModel {
  int calls = 0;
  Object? error;
  Completer<void>? pending;
  @override
  Future<void> submit({
    required String orderId,
    required String customerId,
    required int stars,
  }) async {
    calls++;
    if (error != null) throw error!;
    await pending?.future;
  }
}

void main() {
  late Ratings model;
  late RatingController controller;
  final order = ServiceOrder.fromMap('o1', {
    'customerId': 'c1',
    'providerId': 'p1',
    'status': OrderStatus.completed,
  });
  setUp(() {
    model = Ratings();
    controller = RatingController(uid: 'c1', model: model);
  });
  tearDown(() => controller.dispose());
  test('invalid input and wrong owner do not reach persistence', () async {
    expect(await controller.submit(order, 0), RatingController.invalidStars);
    expect(
      await controller.submit(
        ServiceOrder.fromMap('o2', {
          'customerId': 'c2',
          'providerId': 'p1',
          'status': OrderStatus.completed,
        }),
        5,
      ),
      RatingController.notEligible,
    );
    expect(model.calls, 0);
  });
  test('double tap and repeat submission cannot double-count', () async {
    model.pending = Completer<void>();
    final sent = controller.submit(order, 5);
    expect(await controller.submit(order, 5), RatingController.busy);
    model.pending!.complete();
    expect(await sent, isNull);
    expect(await controller.submit(order, 5), RatingController.alreadyRated);
    expect(model.calls, 1);
  });
  for (final reason in RatingFailure.values) {
    test('translates $reason and releases sending state', () async {
      model.error = RatingException(reason);
      final message = await controller.submit(order, 5);
      expect(
        message,
        {
          RatingFailure.invalidStars: RatingController.invalidStars,
          RatingFailure.notEligible: RatingController.notEligible,
          RatingFailure.alreadyRated: RatingController.alreadyRated,
          RatingFailure.providerMissing: RatingController.providerMissing,
        }[reason],
      );
      expect(controller.isSending, false);
      model.error = null;
      expect(await controller.submit(order, 5), isNull);
    });
  }
}
