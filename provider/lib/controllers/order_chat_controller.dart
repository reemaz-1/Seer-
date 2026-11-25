import 'dart:async';

import '../models/order.dart';
import '../models/order_chat_model.dart';
import '../models/order_message.dart';

/// What the user can do with the chat of an order.
enum ChatAccess {
  /// No chat: the order has no provider yet, or it never had one.
  hidden,

  /// Messages can be read and sent.
  open,

  /// Messages can be read only, because the order is finished.
  readOnly,
}

/// CONTROLLER for the chat between the customer and the provider of an order.
class OrderChatController {
  /// Creates the controller.
  /// Parameters: [orderId] is the order of the chat, [uid] is the signed-in
  /// user's id, and [senderType] is [MessageSender.customer] 
  OrderChatController({
    required this.orderId,
    required this.uid,
    required this.senderType,
    OrderChatModel? model,
  }) : _model = model ?? OrderChatModel();

  final String orderId;
  final String uid;
  final String senderType;
  final OrderChatModel _model;

  static const maxLength = 500;

  static const _emptyError = 'اكتب رسالة قبل الإرسال.';
  static const _tooLongError = 'الرسالة طويلة جداً، الحد الأقصى 500 حرف.';
  static const _closedError = 'انتهى الطلب، لا يمكن إرسال رسائل جديدة.';
  static const _sendFailedError = 'تعذّر إرسال الرسالة. حاول مرة أخرى.';

  /// Message shown above the input when the chat is read only.
  static const closedMessage = 'انتهى الطلب، المحادثة للقراءة فقط.';

  /// Message shown when the phone has no connection.
  static const offlineMessage = 'لا يوجد اتصال بالإنترنت. سيتم إرسال رسائلك عند عودة الاتصال.';

  /// Ids of the messages we already asked to mark as read, to avoid repeats.
  final Set<String> _readRequested = {};

  /// Decides what the chat looks like for an order.
  /// Parameters: [order] is the order shown on the page.
  /// Returns: [ChatAccess.open] while the provider is working on it,
  /// [ChatAccess.readOnly] after it is completed or cancelled, and
  /// [ChatAccess.hidden] in every other case.
  static ChatAccess accessFor(ServiceOrder order) {
    // Without a provider there is nobody to talk to.
    if ((order.providerId ?? '').isEmpty) return ChatAccess.hidden;
    if (OrderStatus.active.contains(order.status)) return ChatAccess.open;
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      return ChatAccess.readOnly;
    }
    return ChatAccess.hidden;
  }

  /// Checks the text of a message.
  /// Parameters: [text] is what the user typed.
  /// Returns: null when valid, otherwise the message to show.
  String? validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return _emptyError;
    if (trimmed.length > maxLength) return _tooLongError;
    return null;
  }

  /// Listens to the messages of the order.
  /// Returns: a stream of updates. Messages from the other side are marked
  /// as read automatically while the chat is open on this phone.
  Stream<OrderChatUpdate> watchMessages() {
    return _model.watchMessages(orderId).map((update) {
      _markIncomingAsRead(update);
      return update;
    });
  }

  /// The other side of the chat: the one who receives our messages.
  String get _otherSide => senderType == MessageSender.customer
      ? MessageSender.provider
      : MessageSender.customer;

  /// Clears the unread count of this side. Call it when the chat page opens.
  void markSeen() {
    unawaited(
      _model.clearUnread(orderId, senderType).then((_) {}, onError: (_) {}),
    );
  }
  
  /// Listens to the order of the chat.
  /// Returns: a stream with the latest version of the order, so the chat
  /// opens or closes by itself when the order status changes.
  Stream<ServiceOrder?> watchOrder() => _model.watchOrder(orderId);

  /// Sends a message.
  /// Parameters: [text] is what the user typed and [order] is the latest
  /// version of the order, used to check that the chat is still open.
  /// Returns: null when the message was handed over, otherwise the error to show.
  String? send(String text, ServiceOrder order) {
    if (accessFor(order) != ChatAccess.open) return _closedError;
    final error = validate(text);
    if (error != null) return error;

    final message = OrderMessage(
      id: '',
      senderId: uid,
      senderType: senderType,
      text: text.trim(),
    );
    try {
      // Not awaited: without internet Firestore keeps the message on the
      // phone and sends it later, so waiting here would freeze the screen.
      unawaited(
        _model
            .send(orderId, message, recipientType: _otherSide)
            .then((_) {}, onError: (_) {}),
      );
    } catch (_) {
      return _sendFailedError;
    }
    return null;
  }

  /// Marks the unread messages of the other side as read.
  /// Parameters: [update] is the latest update of the stream.
  void _markIncomingAsRead(OrderChatUpdate update) {
    // Offline data cannot be written reliably, so wait for the server.
    if (update.fromCache) return;
    final ids = update.messages
        .where((m) =>
            !m.isMine(uid) &&
            m.readAt == null &&
            !m.isPending &&
            !_readRequested.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) return;
    _readRequested.addAll(ids);
    unawaited(_model.markRead(orderId, ids, readerType: senderType).then((_) {}, onError: (_) {
      // Allow a retry on the next update if the write failed.
      _readRequested.removeAll(ids);
    }));
  }

  /// Formats a time as "3:05 م".
  /// Parameters: [time] is the message time, or null before the server sets it.
  /// Returns: the formatted time, or an empty string.
  static String formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'ص' : 'م';
    return '$hour:$minute $period';
  }

  /// Formats the day of a message for the separator between days.
  /// Parameters: [time] is the message time, or null before the server sets it.
  /// Returns: "اليوم", "أمس", or a date like 21/11/2026.
  static String dayLabel(DateTime? time) {
    final local = (time ?? DateTime.now()).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'اليوم';
    if (difference == 1) return 'أمس';
    return '${local.day}/${local.month}/${local.year}';
  }

  /// Tells whether two message times fall on the same calendar day.
  /// Parameters: [a] and [b] are message times; null counts as now.
  /// Returns: true when both are on the same day.
  static bool sameDay(DateTime? a, DateTime? b) {
    final first = (a ?? DateTime.now()).toLocal();
    final second = (b ?? DateTime.now()).toLocal();
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}