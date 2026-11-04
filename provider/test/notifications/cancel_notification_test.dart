import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/controllers/notification_controller.dart';
import 'package:provider/models/app_notification.dart';
import 'package:provider/views/notifications.dart';

/// Gives the controller a controllable list instead of Firestore.
class FakeNotifications extends NotificationModel {
  final stream = StreamController<List<AppNotification>>.broadcast(sync: true);

  @override
  Stream<List<AppNotification>> watch(String providerId) => stream.stream;

  @override
  Future<void> markRead(Iterable<String> ids) async {}
}

/// Takes an [id]; returns a cancellation notice as saved by the customer app.
AppNotification cancelledNotice(String id) =>
    AppNotification.fromMap(id, {
      'recipientId': 'p1',
      'type': AppNotification.typeOrderCancelled,
      'orderId': 'order-1',
      'title': 'ألغى العميل الطلب',
      'body': 'تشغيل البطارية · كيا بيجاس 2025',
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

void main() {
  test('a cancellation notice is never an answerable request', () {
    final notice = cancelledNotice('n1');
    expect(notice.isCancellation, isTrue);
    expect(notice.isActive(DateTime.now()), isFalse);
  });

  test('a cancellation that arrives while the app is open shows a banner',
      () async {
    final model = FakeNotifications();
    final controller = NotificationController(providerId: 'p1', model: model);
    final arrived = <AppNotification>[];
    controller
      ..onNew = arrived.add
      ..start();

    model.stream.add([]);
    model.stream.add([cancelledNotice('n1')]);

    expect(arrived.single.isCancellation, isTrue);
    expect(controller.unreadCount, 1);
    controller.dispose();
    await model.stream.close();
  });

  testWidgets('the notifications page explains a cancelled order', (
    tester,
  ) async {
    final model = FakeNotifications();
    final controller = NotificationController(providerId: 'p1', model: model)
      ..start();
    model.stream.add([cancelledNotice('n1')]);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ProviderNotifications(controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ألغى العميل الطلب'), findsOneWidget);
    expect(find.textContaining('تم الإلغاء'), findsOneWidget);

    await tester.tap(find.text('ألغى العميل الطلب'));
    await tester.pump();
    expect(
      find.text('ألغى العميل هذا الطلب، فلا حاجة للتوجه إليه.'),
      findsOneWidget,
    );

    // Let the message close before the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    controller.dispose();
    await model.stream.close();
  });
}
