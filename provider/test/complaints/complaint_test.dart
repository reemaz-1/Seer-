import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/controllers/complaint_controller.dart';
import 'package:provider/models/complaint.dart';
import 'package:provider/models/complaint_model.dart';
import 'package:provider/models/order.dart';
import 'package:provider/views/past_order_details_page.dart';

import '../requests/request_fakes.dart';
import 'complaint_fakes.dart';

/// Takes a [status] and the [providerId]; returns a finished order.
ServiceOrder finishedOrder({
  String status = OrderStatus.completed,
  String providerId = 'p1',
}) {
  final now = DateTime(2026, 11, 4, 10);
  return requestFixture(
    now,
    id: 'order-1',
    overrides: {
      'status': status,
      'providerId': providerId,
      'customerName': 'سارة',
      'customerPhone': '0500000000',
      'finalPrice': 150,
      'paymentConfirmed': status == OrderStatus.completed,
      'acceptedAt': Timestamp.fromDate(now.add(const Duration(minutes: 1))),
      'completedAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
    },
  );
}

const validText = 'العميل لم يكن موجوداً في الموقع عند الوصول';

void main() {
  group('ComplaintController', () {
    late FakeComplaintModel model;
    late ComplaintController controller;

    setUp(() {
      model = FakeComplaintModel();
      controller = ComplaintController(uid: 'p1', model: model);
    });
    tearDown(() => controller.dispose());

    test('validates the complaint text', () {
      expect(controller.validate('   '), ComplaintController.emptyError);
      expect(controller.validate('قصير'), ComplaintController.tooShortError);
      expect(
        controller.validate('أ' * 501),
        ComplaintController.tooLongError,
      );
      expect(controller.validate(validText), isNull);
    });

    test('allows complaints only on this provider\'s finished orders', () {
      expect(controller.canComplain(finishedOrder()), isTrue);
      expect(
        controller.canComplain(finishedOrder(status: OrderStatus.cancelled)),
        isTrue,
      );
      expect(
        controller.canComplain(finishedOrder(status: OrderStatus.inProgress)),
        isFalse,
      );
      expect(
        controller.canComplain(finishedOrder(providerId: 'someone-else')),
        isFalse,
      );
    });

    test('sends the complaint about the customer with an order snapshot',
        () async {
      final error = await controller.submit(finishedOrder(), '  $validText  ');

      expect(error, isNull);
      final sent = model.submitted.single;
      expect(sent.id, 'order-1_provider');
      expect(sent.complainantId, 'p1');
      expect(sent.complainantType, ComplainantType.provider);
      expect(sent.againstId, 'customer-1');
      expect(sent.description, validText);
      expect(sent.status, ComplaintStatus.pending);
      expect(sent.customerName, 'سارة');
      expect(sent.providerName, 'مزود الخدمة');
      expect(sent.serviceLabel, 'خدمة السطحة - سطحة عادية');
      expect(sent.orderPrice, 150);
      expect(sent.orderStatus, OrderStatus.completed);
      expect(controller.isSending, isFalse);
    });

    test('does not send an invalid complaint', () async {
      expect(
        await controller.submit(finishedOrder(), 'قصير'),
        ComplaintController.tooShortError,
      );
      expect(model.submitted, isEmpty);
    });

    test('says when a complaint was already sent', () async {
      await controller.submit(finishedOrder(), validText);
      expect(
        await controller.submit(finishedOrder(), validText),
        ComplaintController.alreadyExistsError,
      );
      expect(model.submitted, hasLength(1));
    });

    test('says when sending fails', () async {
      model.failure = Exception('offline');
      expect(
        await controller.submit(finishedOrder(), validText),
        ComplaintController.sendFailedError,
      );
      expect(controller.isSending, isFalse);
    });

    test('uses the provider complaint id for an order', () {
      expect(ComplaintModel.idFor('order-1'), 'order-1_provider');
    });
  });

  group('Complaint section in order details', () {
    /// Takes a tester, an [order] and a [model]; shows the details page.
    Future<void> showDetails(
      WidgetTester tester,
      ServiceOrder order,
      FakeComplaintModel model,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PastOrderDetailsPage(
            order: order,
            addresses: FakeAddresses(),
            complaints: ComplaintController(uid: 'p1', model: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final button = find.byKey(const ValueKey('complain-about-customer'));

    testWidgets('sends a complaint from the details page', (tester) async {
      final model = FakeComplaintModel();
      await showDetails(tester, finishedOrder(), model);

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('شكوى على العميل'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'قصير');
      await tester.tap(find.text('إرسال الشكوى'));
      await tester.pumpAndSettle();
      expect(find.text(ComplaintController.tooShortError), findsOneWidget);
      expect(model.submitted, isEmpty);

      await tester.enterText(find.byType(TextField), validText);
      await tester.tap(find.text('إرسال الشكوى'));
      await tester.pumpAndSettle();

      expect(model.submitted, hasLength(1));
      expect(find.text('تم إرسال الشكوى بنجاح'), findsOneWidget);
      expect(find.text('شكوى على هذا الطلب'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(button, findsNothing);

      // Let the success message close before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('shows the status instead of the button when already sent', (
      tester,
    ) async {
      final model = FakeComplaintModel(
        existing: const Complaint(
          id: 'order-1_provider',
          complainantId: 'p1',
          complainantType: ComplainantType.provider,
          againstId: 'customer-1',
          orderId: 'order-1',
          description: validText,
          status: ComplaintStatus.resolved,
        ),
      );
      await showDetails(tester, finishedOrder(), model);

      expect(button, findsNothing);
      expect(find.text('تمت المعالجة'), findsOneWidget);
      expect(find.text(validText), findsOneWidget);
    });

    testWidgets('hides the complaint for an order of another provider', (
      tester,
    ) async {
      await showDetails(
        tester,
        finishedOrder(providerId: 'someone-else'),
        FakeComplaintModel(),
      );
      expect(button, findsNothing);
      expect(find.text('شكوى على هذا الطلب'), findsNothing);
    });
  });
}
