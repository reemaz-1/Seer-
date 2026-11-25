import 'package:cloud_firestore/cloud_firestore.dart';

import 'order.dart';
import 'order_message.dart';

/// One update of the chat stream: the messages and where they came from.
class OrderChatUpdate {
  /// Creates an update from the loaded [messages].
  const OrderChatUpdate({required this.messages, required this.fromCache});

  /// The messages of the order, oldest first.
  final List<OrderMessage> messages;

  /// True when the data comes from the phone cache, which usually means
  /// there is no connection to the server right now.
  final bool fromCache;
}

/// MODEL: reads and writes the chat messages of an order in Firestore.
class OrderChatModel {
  /// Creates the model; [firestore] can be injected in tests.
  OrderChatModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// The `messages` sub-collection of [orderId].
  CollectionReference<Map<String, dynamic>> _messages(String orderId) =>
      _firestore.collection('orders').doc(orderId).collection('messages');

  /// The order document of [orderId].
  DocumentReference<Map<String, dynamic>> _order(String orderId) =>
      _firestore.collection('orders').doc(orderId);

  /// The order field that counts the unread messages of [side].
  /// Takes [MessageSender.customer] or [MessageSender.provider].
  static String _unreadField(String side) => side == MessageSender.customer
      ? 'chatUnreadCustomer'
      : 'chatUnreadProvider';

  /// Listens to the messages of [orderId].
  /// Returns: a stream that emits the messages oldest first. It updates by
  /// itself when a message arrives, is confirmed by the server, or is read.
  Stream<OrderChatUpdate> watchMessages(String orderId) {
    return _messages(orderId)
        .orderBy('createdAt')
        // Metadata changes let the screen see "sending" turn into "sent".
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      return OrderChatUpdate(
        messages: snapshot.docs.map(OrderMessage.fromDoc).toList(),
        fromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  /// Listens to the order itself, so the chat knows when the order finishes.
  /// Returns: a stream that emits the order, or null if it does not exist.
  Stream<ServiceOrder?> watchOrder(String orderId) {
    return _order(orderId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return ServiceOrder.fromMap(doc.id, data);
    });
  }

  /// Saves a new [message] in the chat of [orderId] and counts it as unread
  /// for [recipientType]. Both writes happen together or not at all.
  /// The future completes only when the server confirms the write, so the
  /// caller should not wait for it before clearing the input field.
  Future<void> send(
    String orderId,
    OrderMessage message, {
    required String recipientType,
  }) {
    final batch = _firestore.batch();
    batch.set(_messages(orderId).doc(), message.toMap());
    batch.update(_order(orderId), {
      _unreadField(recipientType): FieldValue.increment(1),
    });
    return batch.commit();
  }

  /// Marks the messages with [messageIds] as read now, and clears the unread
  /// count of [readerType]. Does nothing when the list is empty.
  Future<void> markRead(
    String orderId,
    List<String> messageIds, {
    required String readerType,
  }) async {
    if (messageIds.isEmpty) return;
    // One batch, so all the changes are saved together.
    final batch = _firestore.batch();
    for (final id in messageIds) {
      batch.update(_messages(orderId).doc(id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_order(orderId), {_unreadField(readerType): 0});
    await batch.commit();
  }

  /// Sets the unread count of [readerType] to zero, used when the chat opens.
  Future<void> clearUnread(String orderId, String readerType) {
    return _order(orderId).update({_unreadField(readerType): 0});
  }
}