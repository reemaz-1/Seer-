import 'package:cloud_firestore/cloud_firestore.dart';

/// Persisted together with each order transition, even if the customer is offline.
class OrderStatusNotification {
  static const messages = <String, String>{
    'accepted': 'تم قبول طلبك',
    'onTheWay': 'مقدم الخدمة في الطريق إليك',
    'arrived': 'وصل مقدم الخدمة إلى موقعك',
    'inProgress': 'بدأ تنفيذ الخدمة',
    'completed': 'اكتملت الخدمة، يمكنك الآن تقييم مقدم الخدمة',
    'rejected': 'لم يقبل أي مقدم خدمة طلبك',
    'autoCancelled': 'انتهت مهلة الطلب دون استجابة',
    'cancelled': 'تم إلغاء طلبك',
  };

  static void write(
    Transaction transaction,
    FirebaseFirestore firestore,
    String orderId,
    Map<String, dynamic> order,
    String status,
  ) {
    final customerId = order['customerId'];
    if (customerId is! String ||
        customerId.isEmpty ||
        !messages.containsKey(status)) {
      throw StateError('Invalid customer notification');
    }
    transaction.set(
      firestore.collection('notifications').doc('${orderId}_$status'),
      {
        'recipientId': customerId,
        'type': 'orderStatusChanged',
        'orderId': orderId,
        'status': status,
        'title': messages[status],
        'body': [order['serviceOptionLabel'], order['vehicleTitle']]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .join(' · '),
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
