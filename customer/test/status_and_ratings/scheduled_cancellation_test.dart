import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/customer_orders_model.dart';
import 'package:customer/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);
  ServiceOrder order(String status) => ServiceOrder.fromMap('scheduled-1', {
    'customerId': 'customer-1',
    'status': status,
    'scheduledAt': Timestamp.fromDate(now.add(const Duration(days: 1))),
    'acceptedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
  });

  test('scheduled booking remains cancellable even hours after acceptance', () {
    expect(CustomerOrdersModel.canCancel(
        order(OrderStatus.scheduledAccepted), now), isTrue);
  });
  test('scheduled booking can be cancelled before provider accepts', () {
    expect(CustomerOrdersModel.canCancel(
        order(OrderStatus.scheduledPending), now), isTrue);
  });
  test('once provider travels, customer cancellation is blocked', () {
    expect(CustomerOrdersModel.canCancel(order(OrderStatus.onTheWay), now),
        isFalse);
  });
  test('unaccepted future booking expires only at requested appointment', () {
    final pending = order(OrderStatus.scheduledPending);
    expect(CustomerOrdersModel.isExpired(pending, now), isFalse);
    expect(CustomerOrdersModel.isExpired(pending,
        now.add(const Duration(days: 1))), isTrue);
  });
}
