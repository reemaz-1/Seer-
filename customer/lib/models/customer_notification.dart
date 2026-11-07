import 'package:cloud_firestore/cloud_firestore.dart';

/// MODEL: a customer inbox event copied from Firestore.
class CustomerNotification {
  /// Takes event fields; creates immutable inbox data.
  const CustomerNotification({
    required this.id,
    required this.orderId,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.status,
    this.type,
  });
  final String id, orderId, title, body;
  final bool read;
  final String? status, type;
  final DateTime? createdAt;

  /// Takes a document id and fields; returns the typed inbox event.
  factory CustomerNotification.fromMap(String id, Map<String, dynamic> data) =>
      CustomerNotification(
        id: id,
        orderId: data['orderId'] as String? ?? '',
        status: data['status'] as String?,
        type: data['type'] as String?,
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        read: data['read'] == true,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}

/// MODEL: reads the customer inbox and persists read acknowledgements.
class CustomerNotificationModel {
  /// Takes an optional Firestore client; creates the inbox gateway.
  CustomerNotificationModel({FirebaseFirestore? firestore})
    : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _store => _injected ?? FirebaseFirestore.instance;

  /// Takes [uid]; returns its inbox sorted newest first.
  Stream<List<CustomerNotification>> watch(String uid) => _store
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final notices = snapshot.docs
            .map((doc) => CustomerNotification.fromMap(doc.id, doc.data()))
            .toList();
        notices.sort((a, b) {
          final date = (b.createdAt ?? DateTime(9999)).compareTo(
            a.createdAt ?? DateTime(9999),
          );
          return date != 0 ? date : a.id.compareTo(b.id);
        });
        return notices;
      });

  /// Takes an event id; marks that document read without changing its content.
  Future<void> markRead(String id) =>
      _store.collection('notifications').doc(id).update({'read': true});
}
