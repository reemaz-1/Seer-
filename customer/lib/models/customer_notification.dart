import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.orderId,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });
  final String id, orderId, title, body;
  final bool read;
  final DateTime? createdAt;
  factory CustomerNotification.fromMap(String id, Map<String, dynamic> data) =>
      CustomerNotification(
        id: id,
        orderId: data['orderId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        read: data['read'] == true,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}

class CustomerNotificationModel {
  CustomerNotificationModel({FirebaseFirestore? firestore})
    : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _store => _injected ?? FirebaseFirestore.instance;

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

  Future<void> markRead(String id) =>
      _store.collection('notifications').doc(id).update({'read': true});
}
