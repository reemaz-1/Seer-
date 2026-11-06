import 'dart:async';

import 'package:customer/models/order.dart';
import 'package:customer/models/rating_model.dart';
import 'package:customer/widgets/order_rating_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Ratings extends RatingModel {
  OrderRating? saved;
  bool fail = false;
  int calls = 0;
  final events = StreamController<OrderRating?>.broadcast();
  @override
  Stream<OrderRating?> watch(String orderId) async* {
    yield saved;
    yield* events.stream;
  }

  @override
  Future<void> submit({
    required String orderId,
    required String customerId,
    required int stars,
  }) async {
    calls++;
    if (fail) throw StateError('offline');
    saved = OrderRating(stars);
    events.add(saved);
  }
}

ServiceOrder order(String status) => ServiceOrder.fromMap('o1', {
  'customerId': 'c1',
  'providerId': 'p1',
  'status': status,
});
void main() {
  testWidgets(
    'completed service accepts five stars once and restores the result',
    (tester) async {
      final model = Ratings();
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderRatingSection(
                order: order('completed'),
                uid: 'c1',
                model: model,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('5 من 5'));
      await tester.pump();
      await tester.tap(find.text('إرسال التقييم'));
      await tester.pumpAndSettle();
      expect(find.text('تقييمك: 5 من 5'), findsOneWidget);
      expect(find.text('إرسال التقييم'), findsNothing);
      expect(model.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await mount();
      expect(find.text('تقييمك: 5 من 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await model.events.close();
    },
  );
  testWidgets('failed send keeps the selected stars available for retry', (
    tester,
  ) async {
    final model = Ratings()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderRatingSection(
            order: order('completed'),
            uid: 'c1',
            model: model,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('3 من 5'));
    await tester.pump();
    await tester.tap(find.text('إرسال التقييم'));
    await tester.pumpAndSettle();
    expect(find.text('offline'), findsOneWidget);
    model.fail = false;
    await tester.tap(find.text('إرسال التقييم'));
    await tester.pumpAndSettle();
    expect(find.text('تقييمك: 3 من 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await model.events.close();
  });
  testWidgets('rating controls stay hidden before completion', (tester) async {
    final model = Ratings();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderRatingSection(
            order: order('inProgress'),
            uid: 'c1',
            model: model,
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await model.events.close();
  });
}
