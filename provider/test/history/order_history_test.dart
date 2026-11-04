import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/controllers/complaint_controller.dart';
import 'package:provider/controllers/order_history_controller.dart';
import 'package:provider/models/order.dart';
import 'package:provider/views/history.dart';
import 'package:provider/views/past_order_details_page.dart';

import '../complaints/complaint_fakes.dart';
import '../requests/request_fakes.dart';

/// Gives the history screen a controllable list instead of Firestore.
class FakeHistory extends OrderHistoryController {
  final stream = StreamController<List<ServiceOrder>>.broadcast(sync: true);

  @override
  Stream<List<ServiceOrder>> watchPastOrders() =>
      stream.stream.map(OrderHistoryController.newestFirst);
}

/// Takes a [now] time; returns an order completed one hour later and paid.
ServiceOrder completedOrder(DateTime now) => requestFixture(
  now,
  id: 'completed-1',
  overrides: {
    'status': OrderStatus.completed,
    'providerId': 'p1',
    'customerName': 'سارة',
    'finalPrice': 150,
    'paymentConfirmed': true,
    'acceptedAt': Timestamp.fromDate(now.add(const Duration(minutes: 1))),
    'completedAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
  },
);

/// Takes a [now] time; returns an order the customer cancelled two hours later.
ServiceOrder cancelledOrder(DateTime now) => requestFixture(
  now,
  id: 'cancelled-1',
  overrides: {
    'status': OrderStatus.cancelled,
    'providerId': 'p1',
    'acceptedAt': Timestamp.fromDate(now.add(const Duration(minutes: 1))),
    'cancelledAt': Timestamp.fromDate(now.add(const Duration(hours: 2))),
  },
);

void main() {
  final now = DateTime(2026, 11, 4, 10);

  group('OrderHistoryController', () {
    test('sorts by the completion or cancellation time, newest first', () {
      final sorted = OrderHistoryController.newestFirst([
        completedOrder(now),
        cancelledOrder(now),
      ]);
      expect(sorted.map((order) => order.id), ['cancelled-1', 'completed-1']);
    });

    test('a completed order shows the amount received and confirmed payment',
        () {
      final order = completedOrder(now);
      expect(OrderHistoryController.receivedAmount(order), 150);
      expect(OrderHistoryController.finishedLabel(order), 'تاريخ الإكمال');
      expect(OrderHistoryController.paymentText(order), 'تم تأكيد استلام المبلغ');
    });

    test('a cancelled order has no amount received', () {
      final order = cancelledOrder(now);
      expect(OrderHistoryController.receivedAmount(order), isNull);
      expect(OrderHistoryController.finishedLabel(order), 'تاريخ الإلغاء');
      expect(
        OrderHistoryController.paymentText(order),
        'لا يوجد مبلغ، ألغى العميل الطلب',
      );
    });

    test('reads cancelledAt from Firestore', () {
      expect(
        cancelledOrder(now).cancelledAt,
        now.add(const Duration(hours: 2)),
      );
    });
  });

  group('ProviderHistory', () {
    late FakeHistory history;

    setUp(() => history = FakeHistory());
    tearDown(() => history.stream.close());

    /// Takes a tester; shows the history tab with fake data and addresses.
    Future<void> showHistory(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: ProviderHistory(
                controller: history,
                addresses: FakeAddresses(),
                complaints: ComplaintController(
                  uid: 'p1',
                  model: FakeComplaintModel(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows a loader until the first list arrives', (tester) async {
      await showHistory(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the empty message when there are no past orders', (
      tester,
    ) async {
      await showHistory(tester);
      history.stream.add([]);
      await tester.pump();
      expect(find.text('لا توجد طلبات سابقة'), findsOneWidget);
    });

    testWidgets('shows an error message when loading fails', (tester) async {
      await showHistory(tester);
      history.stream.addError(Exception('offline'));
      await tester.pump();
      expect(find.text('تعذر تحميل الطلبات السابقة'), findsOneWidget);
    });

    testWidgets('lists completed and cancelled orders, newest first', (
      tester,
    ) async {
      await showHistory(tester);
      history.stream.add([completedOrder(now), cancelledOrder(now)]);
      await tester.pump();

      expect(find.text('مكتمل'), findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);
      expect(find.text('رقم الطلب #COMPLETE'), findsOneWidget);
      expect(find.text('رقم الطلب #CANCELLE'), findsOneWidget);
      final cancelledTop = tester.getTopLeft(find.text('ملغي')).dy;
      final completedTop = tester.getTopLeft(find.text('مكتمل')).dy;
      expect(cancelledTop, lessThan(completedTop));
    });

    testWidgets('opens the details of a completed order', (tester) async {
      await showHistory(tester);
      history.stream.add([completedOrder(now)]);
      await tester.pump();

      await tester.tap(find.text('مكتمل'));
      await tester.pumpAndSettle();

      expect(find.byType(PastOrderDetailsPage), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      expect(find.text('المركبة عند مدخل الحي'), findsOneWidget);
      expect(find.text('شارع الملك فهد، الرياض'), findsOneWidget);
      expect(find.text('تاريخ الإكمال'), findsOneWidget);
      expect(find.text('المبلغ المستلم'), findsOneWidget);
      expect(find.text('تم تأكيد استلام المبلغ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the details of a cancelled order without an amount', (
      tester,
    ) async {
      await showHistory(tester);
      history.stream.add([cancelledOrder(now)]);
      await tester.pump();

      await tester.tap(find.text('ملغي'));
      await tester.pumpAndSettle();

      expect(find.text('تاريخ الإلغاء'), findsOneWidget);
      expect(find.text('المبلغ المستلم'), findsNothing);
      expect(find.text('لا يوجد مبلغ، ألغى العميل الطلب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
