import 'package:cloud_firestore/cloud_firestore.dart';

/// MODEL: writes an inbox event atomically with an order transition.
/// Kept identical in both apps; tool/check_order_notification_contract.py checks parity.
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

  /// Takes a transaction, order and status; writes one stable event when valid.
  /// Missing legacy customer ids skip the notice without blocking the order.
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
      return;
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
