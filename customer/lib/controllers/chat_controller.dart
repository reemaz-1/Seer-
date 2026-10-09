import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/vehicle.dart';
import '../services/ai_assistant.dart';
import '../services/ai_order_actions.dart';
import '../services/gemini_ai_assistant.dart';

///CONTROLLER: the AI chat  
///
///the page never talks to Gemini. It calls, and this controller turns the assistant's events into messages and tells the page to redraw.
///it only knows that Aiassistant contract, so it works the same with the real assistant Gemini and with FakeAiassistant (offline testing)


class ChatController extends ChangeNotifier {

  ChatController({required AiAssistant assistant}) : _assistant  = assistant;

  ///The real chat for a signed-in customer 
  factory ChatController.forCustomer({
    required String uid,
    String? preferredVehicleId,
  }){
    return ChatController(
      assistant: GeminiAiAssistant(
        actions: FirestoreAiOrderActions(uid: uid),
        preferredVehicleId: preferredVehicleId,
      ),
    );
  }

  final AiAssistant _assistant;

  ///everything show in the chat, oldest first.
  final List<ChatMessage> messages = [];

  ///true while the assistant is replying. the page disables sending, because the assistant accepts one message at a time.
  bool isBusy = false;

  bool _disposed = false;

  ///the car the conversation is about (shown under the page title)
  Vehicle? get activeVehicle => _assistant.activeVehicle;


  ///sends the customer's message and shows the reply as it arrives
  Future<void> send(
    String text, {
      Uint8List? imageBytes,
      String imageMimeType = 'image/jpeg',
    }) async {
      final message = text.trim();
      if(isBusy || (message.isEmpty && imageBytes == null)) {
        return;
      }

      isBusy = true;
      messages.add(ChatMessage.customer(message, imageBytes: imageBytes));
      _notify();

      ///the assistant bubble that is growing now. a card or a note in the middle of the reply colses it, so that the next words start a new bubble uder th card, in the right order
      ChatMessage? bubble;
      try{
        final events = _assistant.send(
          message,
          imageBytes: imageBytes,
          imageMimeType: imageMimeType,
        );
        await for (final event in events) {
          switch (event) {
            case AiTextDelta(text: final words):
              final current = bubble ??= _add(ChatMessage.assistant());
              current.text += words;
            case AiVehicleChanged(:final vehicle):
              _add(ChatMessage.info('المركبة الآن: ${vehicle.title}'));
              bubble = null;
            case AiOrderSummaryShown(:final summary):
              _add(ChatMessage.summaryCard(summary));
              bubble = null;
            case AiOrderSummaryCancelled(:final summaryId):
              _summaryCard(summaryId)?.summaryState = SummaryState.cancelled;
              bubble = null;
            case AiOrderPlaced(:final orderId, :final summary):
              final card = _summaryCard(summary.id);
              if(card != null){
                card.summaryState = SummaryState.sent;
                card.orderId = orderId;
              }
              bubble = null;
          }
          _notify();
        }
      }on AiAssistantException catch (e){
        _add(ChatMessage.error(e.message));
      }catch (e){
        debugPrint('ChatController.send failed: $e');
        _add(ChatMessage.error('حدث خطأ غير متوقع. حاول مرة أخرى.'));
      }

      isBusy = false;
      _notify();
    }

    ///the summary card's button calls this after the customer picks a point. 
    ///returns false when that card is no longer waiting.
    bool updateSummaryLocation(
      String summaryId,{
      GeoPoint? pickup,
      GeoPoint? dropoff,
    }){
      final updated = _assistant.updateSummaryLocation(
        summaryId,
        pickup: pickup,
        dropoff: dropoff,
      );
      final card = _summaryCard(summaryId);
      if(updated == null || card == null) return false;
      card.summary = updated;
      _notify();
      return true;
    }

    ///Starts a new conversation
    void reset(){
      if(isBusy) return;
      _assistant.reset();
      messages.clear();
      _notify();
    }


    ChatMessage  _add(ChatMessage message){
      messages.add(message);
      return message;
    }

    ChatMessage? _summaryCard(String summaryId){
      return messages.where((m) => m.summary?.id == summaryId).lastOrNull;
    }

    ///the reply can still be arriving after the page is closed; never redraw a controller that was already disposed
    void _notify(){
      if (!_disposed) notifyListeners();
    }

    @override
    void dispose(){
      _disposed = true;
      super.dispose();
    }

}