import 'package:cloud_firestore/cloud_firestore.dart';

/// One in-app notification (#47).
///
/// Written by the customer app when a request is matched to this provider
/// (customer/lib/models/notification_model.dart has the full document shape).
/// Built from scratch on Firestore, without Firebase Cloud Messaging.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.orderId,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String type;
  final String orderId;
  final String title;
  final String body;
  final bool read;

  /// Null for a moment while the server time is still being written.
  final DateTime? createdAt;

  /// When the order stops waiting for an answer.
  final DateTime? expiresAt;

  /// True while the provider can still answer the request.
  bool isActive(DateTime now) => expiresAt != null && expiresAt!.isAfter(now);

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: (map['type'] ?? '') as String,
      orderId: (map['orderId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      read: map['read'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// MODEL: reads and updates the signed-in provider's notifications.
class NotificationModel {
  NotificationModel({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;

  /// Resolved on first use, so creating the model never needs Firebase.
  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Live list of this provider's notifications, newest first.
  ///
  /// Only an equality filter is used and the list is sorted on the phone,
  /// so Firestore needs no composite index.
  Stream<List<AppNotification>> watch(String providerId) {
    return _notifications
        .where('recipientId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
      final list = [
        for (final doc in snapshot.docs)
          AppNotification.fromMap(doc.id, doc.data()),
      ];
      // A notification whose server time is not set yet is the newest one.
      final far = DateTime(9999);
      list.sort((a, b) =>
          (b.createdAt ?? far).compareTo(a.createdAt ?? far));
      return list;
    });
  }

  /// Marks the given notifications as read in one batch.
  Future<void> markRead(Iterable<String> ids) async {
    final unique = ids.toSet();
    if (unique.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in unique) {
      batch.update(_notifications.doc(id), {'read': true});
    }
    await batch.commit();
  }
}
