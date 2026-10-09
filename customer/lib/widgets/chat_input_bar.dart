import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// VIEW: the bottom bar of the AI chat: a text and a send buttin
class ChatInputBar extends StatelessWidget{

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    this.leading,
  });

  final TextEditingController controller;

  ///false while the assistant is replying
  final bool enabled;
  final ValueChanged<String> onSend;
  final Widget? leading;


  @override
  Widget build(BuildContext context){
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8,8,8,8),
        decoration: const BoxDecoration(
        color: CustomerColors.background,
        border: Border(top: BorderSide(color: CustomerColors.cardBorder)),
        ),
        child: Row(
          children: [
            if (leading != null) leading!,
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4, 
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? onSend : null,
                decoration: InputDecoration(
                  hintText: enabled ? 'صف المشكلة...' : 'المساعد يكتب...',
                  filled: true,
                  fillColor: CustomerColors.fieldFill,
                  isDense: true,
                  contentPadding: 
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: CustomerColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: CustomerColors.cardBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'إرسال',
              style: IconButton.styleFrom(backgroundColor: CustomerColors.accent),
              icon: const Icon(Icons.send),
              onPressed: enabled ? () => onSend(controller.text) : null,
            ),
          ],
        ),
      ),
    );
  }
}