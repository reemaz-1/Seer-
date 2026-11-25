import 'package:flutter/material.dart';

import '../controllers/order_chat_controller.dart';
import '../models/order_message.dart';
import '../theme/chat_colors.dart';

/// VIEW: one message bubble. Messages of the signed-in user are blue and sit
/// on the start side; messages of the other side are white on the end side.
class OrderChatBubble extends StatelessWidget {
  /// Creates a bubble for [message]; [isMine] tells whose message it is.
  const OrderChatBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final OrderMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final textColor = isMine ? ChatColors.mineText : ChatColors.theirsText;
    final metaColor = isMine ? ChatColors.mineMeta : ChatColors.secondaryText;

    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isMine ? ChatColors.mineBubble : ChatColors.theirsBubble,
          border: isMine ? null : Border.all(color: ChatColors.border),
          // The small corner points at the side the message comes from.
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(isMine ? 4 : 16),
            bottomEnd: Radius.circular(isMine ? 16 : 4),
          ),
        ),
        // IntrinsicWidth makes the bubble as wide as its content, up to the
        // maximum, instead of always filling the maximum width.
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(fontSize: 15, height: 1.45, color: textColor),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      OrderChatController.formatTime(message.createdAt),
                      style: TextStyle(fontSize: 11, color: metaColor),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(message: message),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clock while sending, one tick when sent, two green ticks when read.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.message});

  final OrderMessage message;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    if (message.isPending) {
      icon = Icons.schedule;
      color = ChatColors.mineMeta;
    } else if (message.readAt != null) {
      icon = Icons.done_all;
      color = ChatColors.readTick;
    } else {
      icon = Icons.done;
      color = ChatColors.mineMeta;
    }
    return Icon(icon, size: 14, color: color);
  }
}

/// VIEW: the small pill between messages of different days.
class OrderChatDayLabel extends StatelessWidget {
  /// Creates a separator that shows [label], for example "اليوم".
  const OrderChatDayLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: ChatColors.dayPill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ChatColors.secondaryText,
          ),
        ),
      ),
    );
  }
}