import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_colors.dart';

/// VIEW: one text line in the AI chat 
/// Customer message sit on the right, assistant replies in the left . Note and errors centered.
class ChatBubble extends StatelessWidget{
  const ChatBubble({super.key, required this.message});


  final ChatMessage message;


  @override
  Widget build(BuildContext context){
    switch (message.sender){
      case ChatSender.info:
        return _note(message.text, CustomerColors.secondaryText, Icons.info_outline);
      case ChatSender.error:
        return _note(message.text, AppStatusColors.error, Icons.error_outline);
      case ChatSender.customer:
      case ChatSender.assistant:
        return _bubble(context);
    }
  }


  Widget _bubble(BuildContext context){
    final fromCustomer = message.sender == ChatSender.customer;
    final image = message.imageBytes;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;

    return Align(
      // In RTL, "start" is the right side
      alignment: fromCustomer
      ? AlignmentDirectional.centerStart
      : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromCustomer ? CustomerColors.accent : CustomerColors.fieldFill,
          border: fromCustomer ? null : Border.all(color: CustomerColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if(image != null)
            Padding(
              padding: EdgeInsets.only(bottom: message.text.isEmpty ? 0 : 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(image, height: 160, fit: BoxFit.cover),
              ),
            ),
            if(message.text.isNotEmpty)
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: fromCustomer ? Colors.white : CustomerColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(String text, Color color, IconData icon){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: color),
          ),
          ),
        ],
      ),
    );
  }
}