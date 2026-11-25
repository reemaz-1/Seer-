import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/models/order.dart';
import 'package:provider/models/provider_request_model.dart';
import 'request_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);
  ServiceOrder booking({String status = OrderStatus.scheduledPending,
      DateTime? appointment}) => requestFixture(now, overrides: {
    'status': status,
    'scheduledAt': Timestamp.fromDate(appointment ??
        now.add(const Duration(days: 1))),
    'expiresAt': null,
  });

  test('future booking can be accepted without instant 2-minute deadline', () {
    expect(RequestEligibility.canRespond(booking(), 'p1', now), isTrue);
  });
  test('booking cannot be accepted after scheduled arrival', () {
    expect(RequestEligibility.canRespond(booking(appointment: now), 'p1', now),
        isFalse);
  });
  test('accepted and cancelled bookings cannot be claimed a second time', () {
    for (final status in [OrderStatus.scheduledAccepted,
        OrderStatus.cancelled]) {
      expect(RequestEligibility.canRespond(booking(status: status), 'p1', now),
          isFalse);
    }
  });
}
