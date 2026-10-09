import 'dart:typed_data';

import '../services/ai_assistant.dart';

/// Who a line in the chat belongs to.
/// - customer:  what the customer typed (and maybe a photo, piece 3)
/// - assistant: the AI reply, or an order summary card (piece 4)
/// - info:      a short note from the app, e.g. "المركبة الآن: ..."
/// - error:     an Arabic error from the assistant, shown in red

enum ChatSender { customer, assistant, info, error }

///where an oreder summary card is in its lige.
enum SummaryState { waiting, cancelled, sent }

class ChatMessage  {

  
  ChatMessage.customer(this.text, {this.imageBytes})
      : sender = ChatSender.customer;
        

  ChatMessage.assistant([this.text = ''])
      : sender = ChatSender.assistant,
        imageBytes = null;


  ChatMessage.info(this.text)
      : sender = ChatSender.info,
        imageBytes = null;


  ChatMessage.error(this.text)
      : sender = ChatSender.error,
        imageBytes = null;


  /// The order summary card 
  ChatMessage.summaryCard(OrderSummary this.summary)
      : sender = ChatSender.assistant,
        text = '',
        imageBytes = null;


  final ChatSender sender;
  String text;


  ///The photo the customer attached . null for text only 
  final Uint8List? imageBytes;



  /// Set only for summary cards. Replaced when the customer picks a location.
  OrderSummary? summary;
  SummaryState summaryState = SummaryState.waiting;



  ///The Firestore id after the order is sent from this card
  String? orderId;



  bool get isSummary => summary != null;
} 
