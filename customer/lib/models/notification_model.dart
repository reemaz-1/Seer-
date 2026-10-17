import 'package:cloud_firestore/cloud_firestore.dart';

import 'order.dart';

/// Notification types. Only one exists today; new ones (for example telling
/// the customer their order was accepted) can be added here later.
class NotificationType {
  NotificationType._();

  /// A new service request was matched to this provider (#47).
  static const newRequest = 'newRequest';
}

/// MODEL: writes in-app notifications (#47).
///
/// Built from scratch on Firestore, without Firebase Cloud Messaging:
/// each notification is one document in the `notifications` collection,
/// addressed to one user by `recipientId`:
///
///   notifications (collection)
///     <auto id> (document)
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
/// Security Rules (to add with the real rules before submission):
///   match /notifications/{id} {
///     allow create: if request.auth != null;
///     allow read: if request.auth.uid == resource.data.recipientId;
///     allow update: if request.auth.uid == resource.data.recipientId
///       && request.resource.data.diff(resource.data).affectedKeys()
///            .hasOnly(['read']);
///   }
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

    final expiresAt =
        Timestamp.fromDate(DateTime.now().add(OrderModel.responseWindow));
    final body = [serviceLabel, vehicleTitle]
        .where((part) => part.trim().isNotEmpty)
        .join(' · ');

    final batch = _firestore.batch();
    for (final providerId in providerIds.toSet()) {
      batch.set(_notifications.doc(), {
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
}
