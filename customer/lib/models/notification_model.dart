import 'package:cloud_firestore/cloud_firestore.dart';

import 'order.dart';

/// Notification types. New ones (for example telling the customer their
/// order was accepted) can be added here later.
class NotificationType {
  NotificationType._();

  /// A new service request was matched to this provider (#47).
  static const newRequest = 'newRequest';

  /// The customer cancelled an order this provider had accepted (#20).
  static const orderCancelled = 'orderCancelled';
}

/// MODEL: writes in-app notifications (#47).
///
/// Built from scratch on Firestore, without Firebase Cloud Messaging:
/// each notification is one document in the `notifications` collection,
/// addressed to one user by `recipientId`:
///
///   notifications (collection)
///     orderId_type_providerId (document)
///       recipientId: provider uid
///       type:        'newRequest'
///       orderId:     the order it is about
///       title:       'طلب خدمة جديد'
///       body:        'تغيير البطارية · نيسان باترول 2026'
///       read:        false
///       createdAt:   server time
///       expiresAt:   when the order stops waiting for an answer
///
/// The provider app listens to its own documents live and shows a banner,
/// a badge on the bell and a list (see provider/lib/models/app_notification.dart).
///
/// Stable ids prevent duplicate events. The proposed authorization rules live
/// in firestore/firestore.rules and require team review before deployment.
class NotificationSender {
  NotificationSender({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Sends one "new request" notification to each matched provider.
  /// All of them are written in one batch, so either every provider is
  /// notified or none is.
  Future<void> notifyNewRequest({
    required String orderId,
    required List<String> providerIds,
    required String serviceLabel,
    required String vehicleTitle,
  }) async {
    if (providerIds.isEmpty) return;

    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(OrderModel.responseWindow),
    );
    final body = [
      serviceLabel,
      vehicleTitle,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    final batch = _firestore.batch();
    for (final providerId in providerIds.toSet()) {
      batch.set(_notifications.doc('${orderId}_newRequest_$providerId'), {
        'recipientId': providerId,
        'type': NotificationType.newRequest,
        'orderId': orderId,
        'title': 'طلب خدمة جديد',
        'body': body,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
      });
    }
    await batch.commit();
  }

  /// Takes the cancelled [order]; returns the notification telling its
  /// provider that the customer cancelled it (#20). It is written in the
  /// same transaction as the cancellation, so one never happens without the
  /// other.
  static Map<String, dynamic> orderCancelledData(ServiceOrder order) {
    final service = order.serviceOptionLabel.trim().isNotEmpty
        ? order.serviceOptionLabel
        : order.serviceCategoryLabel;
    return {
      'recipientId': order.providerId,
      'type': NotificationType.orderCancelled,
      'orderId': order.id,
      'title': 'ألغى العميل الطلب',
      'body': [
        service,
        order.vehicleTitle,
      ].where((part) => part.trim().isNotEmpty).join(' · '),
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
