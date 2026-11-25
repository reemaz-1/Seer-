import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/order_chat_controller.dart';
import '../models/order.dart';
import '../models/order_chat_model.dart';
import '../models/order_message.dart';
import '../theme/chat_colors.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/order_chat_bubble.dart';
import '../widgets/order_chat_input_bar.dart';

/// VIEW: the chat of one order. It opens for writing while the provider is
/// working on the order, and becomes read only when the order is finished.
class OrderChatPage extends StatefulWidget {
  /// Creates the page.
  /// Parameters: [controller] runs the chat, [order] is the order as it was
  /// when the page opened, [title] is the name of the other side, and [phone]
  /// is their number for the call button (empty hides the button).
  const OrderChatPage({
    super.key,
    required this.controller,
    required this.order,
    required this.title,
    this.phone = '',
  });

  final OrderChatController controller;
  final ServiceOrder order;
  final String title;
  final String phone;

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  // Created once, so the page does not re-subscribe on every rebuild.
  late final Stream<OrderChatUpdate> _messages =
      widget.controller.watchMessages();
  late final Stream<ServiceOrder?> _orders = widget.controller.watchOrder();

  @override
  void initState() {
    super.initState();
    // Opening the chat counts as seeing the new messages.
    widget.controller.markSeen();
  }
  
  static const _openStatus = 'الطلب جارٍ';
  static const _closedStatus = 'انتهى الطلب';
  static const _unavailable = 'المحادثة غير متاحة لهذا الطلب.';
  static const _loadError =
      'تعذّر تحميل المحادثة، تحقق من اتصالك وحاول مرة أخرى.';
  static const _emptyOpen = 'ابدأ المحادثة';
  static const _emptyClosed = 'لا توجد رسائل في هذا الطلب.';
  static const _callFailed = 'تعذر فتح الاتصال على هذا الجهاز';

  /// Sends the typed text.
  /// Returns: true when it was accepted, so the input can be cleared.
  bool _send(String text, ServiceOrder order) {
    final error = widget.controller.send(text, order);
    if (error != null) {
      showAppMessage(context, error);
      return false;
    }
    return true;
  }

  /// Opens the phone dialer with the other side's number.
  Future<void> _call() async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: widget.phone));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) showAppMessage(context, _callFailed);
  }

  /// Builds a centered message, used for the empty and error states.
  Widget _centerText(String text, {IconData? icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 44, color: ChatColors.secondaryText),
              const SizedBox(height: 12),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                color: ChatColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the list of messages, newest at the bottom, with a label before
  /// the first message of each day.
  Widget _messageList(List<OrderMessage> messages, ChatAccess access) {
    if (messages.isEmpty) {
      return _centerText(
        access == ChatAccess.open ? _emptyOpen : _emptyClosed,
        icon: Icons.chat_bubble_outline_rounded,
      );
    }

    // Rows oldest first: either a day label (String) or a message.
    final rows = <Object>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final newDay = i == 0 ||
          !OrderChatController.sameDay(
            messages[i - 1].createdAt,
            message.createdAt,
          );
      if (newDay) rows.add(OrderChatController.dayLabel(message.createdAt));
      rows.add(message);
    }

    return ListView.builder(
      // reverse keeps the list at the newest message by itself.
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[rows.length - 1 - index];
        if (row is String) return OrderChatDayLabel(label: row);
        final message = row as OrderMessage;
        return OrderChatBubble(
          message: message,
          isMine: message.isMine(widget.controller.uid),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<ServiceOrder?>(
        stream: _orders,
        initialData: widget.order,
        builder: (context, orderSnapshot) {
          // Fall back to the copy we were given if live data is not available.
          final order = orderSnapshot.data ?? widget.order;
          final access = OrderChatController.accessFor(order);

          return Scaffold(
            backgroundColor: ChatColors.pageBackground,
            appBar: AppBar(
              backgroundColor: ChatColors.appBar,
              foregroundColor: ChatColors.appBarText,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    access == ChatAccess.open ? _openStatus : _closedStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: ChatColors.appBarText.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              actions: [
                if (access == ChatAccess.open && widget.phone.isNotEmpty)
                  IconButton(
                    onPressed: _call,
                    icon: const Icon(Icons.call),
                    tooltip: 'اتصال',
                  ),
              ],
            ),
            body: StreamBuilder<OrderChatUpdate>(
              stream: _messages,
              builder: (context, snapshot) {
                if (access == ChatAccess.hidden) {
                  return _centerText(_unavailable);
                }
                if (snapshot.hasError) return _centerText(_loadError);
                final update = snapshot.data;
                if (update == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ChatColors.accent,
                    ),
                  );
                }

                // Keys keep the typed text when the banner appears or goes.
                return Column(
                  children: [
                    if (update.fromCache)
                      const _OfflineBanner(key: ValueKey('chat-offline')),
                    Expanded(
                      key: const ValueKey('chat-list'),
                      child: _messageList(update.messages, access),
                    ),
                    if (access == ChatAccess.open)
                      OrderChatInputBar(
                        key: const ValueKey('chat-input'),
                        maxLength: OrderChatController.maxLength,
                        onSend: (text) => _send(text, order),
                      )
                    else
                      const _ClosedNotice(key: ValueKey('chat-closed')),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Banner shown when the phone has no connection. It waits 1.5 seconds before
/// appearing, so it does not flash while the first server data is loading.
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner({super.key});

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: ChatColors.warning.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: ChatColors.theirsText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              OrderChatController.offlineMessage,
              style: TextStyle(fontSize: 12.5, color: ChatColors.theirsText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notice shown instead of the input when the order is finished.
class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ChatColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: ChatColors.secondaryText,
              ),
              SizedBox(width: 8),
              Text(
                OrderChatController.closedMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: ChatColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}