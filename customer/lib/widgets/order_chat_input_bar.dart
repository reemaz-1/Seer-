import 'package:flutter/material.dart';

import '../theme/chat_colors.dart';

/// VIEW: the text field and the send button at the bottom of the chat.
class OrderChatInputBar extends StatefulWidget {
  /// Creates the bar. [onSend] receives the typed text and returns true when
  /// it was accepted, so the field can be cleared. [maxLength] limits the text.
  const OrderChatInputBar({
    super.key,
    required this.onSend,
    required this.maxLength,
  });

  final bool Function(String text) onSend;
  final int maxLength;

  @override
  State<OrderChatInputBar> createState() => _OrderChatInputBarState();
}

class _OrderChatInputBarState extends State<OrderChatInputBar> {
  final TextEditingController _text = TextEditingController();

  static const _hint = 'اكتب رسالتك...';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Sends the typed text and clears the field if it was accepted.
  void _submit() {
    if (widget.onSend(_text.text)) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ChatColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: widget.maxLength,
                  keyboardType: TextInputType.multiline,
                  // Show the counter only when the user is close to the limit.
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    if (maxLength == null || currentLength < maxLength * 0.8) {
                      return null;
                    }
                    return Text(
                      '$currentLength/$maxLength',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ChatColors.secondaryText,
                      ),
                    );
                  },
                  style: const TextStyle(
                    fontSize: 15,
                    color: ChatColors.theirsText,
                  ),
                  decoration: InputDecoration(
                    hintText: _hint,
                    hintStyle: const TextStyle(color: ChatColors.secondaryText),
                    filled: true,
                    fillColor: ChatColors.inputFill,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Rebuilds only the button when the text changes.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty;
                  return Material(
                    color: canSend ? ChatColors.accent : ChatColors.border,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? _submit : null,
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}