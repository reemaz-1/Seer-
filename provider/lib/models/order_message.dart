import 'package:cloud_firestore/cloud_firestore.dart';

/// Who sent a chat message.
class MessageSender {
  /// Prevents instantiation; takes no inputs and creates no public object.
  MessageSender._();

  static const customer = 'customer';
  static const provider = 'provider';
}

/// MODEL: one chat message of an order.
/// Stored at `orders/{orderId}/messages/{messageId}`.
class OrderMessage {
  /// Creates a message from its fields.
  const OrderMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.text,
    this.createdAt,
    this.readAt,
    this.isPending = false,
  });

  final String id;
  final String senderId;

  final String senderType;
  final String text;

  /// Null while the server time is not set yet (the message was just sent).
  final DateTime? createdAt;

  /// Set when the other side opened the chat; null means not read yet.
  final DateTime? readAt;

  /// True while the message is only on this phone and has not reached the server.
  final bool isPending;

  /// Takes the signed-in user id; returns whether this message is theirs.
  bool isMine(String uid) => senderId == uid;

  /// Takes a Firestore document; returns the message it holds.
  factory OrderMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data();
    return OrderMessage(
      id: doc.id,
      senderId: (map['senderId'] ?? '') as String,
      senderType: (map['senderType'] ?? '') as String,
      text: (map['text'] ?? '') as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      // Firestore marks a message as pending until the server confirms it.
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  /// Takes no inputs; returns the fields saved when a message is sent.
  /// createdAt uses the server clock, so it never depends on the phone time.
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderType': senderType,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}