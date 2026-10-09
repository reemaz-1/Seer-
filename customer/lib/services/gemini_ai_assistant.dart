import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../models/vehicle.dart';
import 'ai_assistant.dart';
import 'ai_instructions.dart';
import 'ai_order_actions.dart';
import 'ai_tool_handler.dart';

/// The real AI assistant (piece 1): Gemini through Firebase AI Logic.
///
/// It streams its replies word by word, knows all the customer's vehicles,
/// shows an order summary card inside the chat and sends the order after the
/// customer confirms. Every rule about orders is enforced in [AiToolHandler],
/// not left to the model.
///
/// HOW ONE MESSAGE WORKS
/// 1. Gemini gets: its instructions + the current state (active car, card
///    waiting for confirmation...) + the conversation so far + the message.
/// 2. Its words are streamed to the screen. If it calls a function, the app
///    runs it (shows the card, switches the car, sends the order).
/// 3. The APP writes the sentence after the function («هل تؤكد الطلب؟»,
///    «تم إرسال طلبك ✅»). Gemini is not asked a second time.
/// 4. The exchange is saved as plain text for the next message.
///
/// Why step 3: the team uses firebase_ai 2.x, which drops the "thought
/// signature" Gemini 3 attaches to function calls, so sending a function
/// result back fails ("Function call is missing a thought_signature"). Not
/// sending it back avoids the problem with any SDK version, and it means only
/// the app can ever tell the customer an order was sent.
///
/// No API key lives in the app: Firebase AI Logic uses the project's Firebase
/// config and App Check, which keeps the public repo safe.
class GeminiAiAssistant implements AiAssistant {
  GeminiAiAssistant({
    required this.actions,
    this.preferredVehicleId,
  });

  /// Stable model with no shutdown before May 2027. Change only here.
  static const modelName = 'gemini-3.5-flash';

  /// Piece 3 shrinks photos before sending; this is only a safety net.
  static const maxImageBytes = 7 * 1024 * 1024;

  static const supportedImageTypes = {'image/jpeg', 'image/png', 'image/webp'};

  /// Messages kept in the history (customer + assistant). Older ones are
  /// dropped so requests stay small; the current state is always sent anyway.
  static const _maxHistory = 30;

  static const _networkError =
      'تعذّر الوصول للمساعد. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';
  static const _busyError = 'المساعد مشغول الآن. حاول مرة أخرى بعد دقيقة.';
  static const _emptyReply =
      'عذرًا، لم أستطع الرد على هذه الرسالة. جرّب أن تصف المشكلة بطريقة أخرى.';
  static const _toolFailedReply =
      'عذرًا، لم أتمكن من تجهيز الطلب. جرّب أن تصف المشكلة مرة أخرى.';

  /// What the assistant may do in the app (vehicles, prices, GPS, orders).
  final AiOrderActions actions;

  /// The vehicle selected on the home page; the chat starts with it.
  final String? preferredVehicleId;

  AiToolHandler? _tools;

  /// The conversation as plain text (no function calls, so no signatures).
  final _history = <Content>[];

  /// Counts the customer's messages. AiToolHandler uses it to make sure the
  /// customer answered a summary before the order is sent.
  int _turn = 0;

  /// Counts chats, and is NOT cleared by [reset], so summary ids stay unique
  /// for the whole screen ('C1-S1', 'C2-S1'...).
  int _chatNumber = 0;

  @override
  List<Vehicle> get vehicles => _tools?.vehicles ?? const [];

  @override
  Vehicle? get activeVehicle => _tools?.activeVehicle;

  @override
  OrderSummary? updateSummaryLocation(
    String summaryId, {
    GeoPoint? pickup,
    GeoPoint? dropoff,
  }) {
    return _tools?.updateLocation(summaryId, pickup: pickup, dropoff: dropoff);
  }

  @override
  void reset() {
    _tools = null;
    _history.clear();
    _turn = 0;
  }

  /// Loads the vehicles. Runs on the first message and again after [reset],
  /// so a vehicle added in the meantime is included.
  Future<void> _start() async {
    final vehicles = await actions.loadVehicles();
    _tools = AiToolHandler(
      actions: actions,
      vehicles: vehicles,
      activeVehicleId: preferredVehicleId,
      summaryIdPrefix: 'C${++_chatNumber}-',
    );
    _history.clear();
    _turn = 0;
  }

  /// Built for every message, because the instructions carry the current
  /// state. Creating a model object is cheap; it makes no network call.
  GenerativeModel _modelFor(AiToolHandler tools) {
    final declarations = AiToolHandler.declarations(tools.vehicles);
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(
        AiInstructions.build(
          vehicles: tools.vehicles,
          activeVehicleId: tools.activeVehicle?.id,
          state: tools.describeState(),
        ),
      ),
      tools: declarations.isEmpty
          ? null
          : [Tool.functionDeclarations(declarations)],
    );
  }

  @override
  Stream<AiEvent> send(
    String text, {
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async* {
    final parts = _buildParts(text, imageBytes, imageMimeType);

    if (_tools == null) {
      try {
        await _start();
      } catch (e) {
        debugPrint('GeminiAiAssistant: could not start: $e');
        throw const AiAssistantException(_networkError);
      }
    }
    final tools = _tools!;
    final turn = ++_turn;

    final reply = StringBuffer();
    final calls = <FunctionCall>[];

    // 1–2. Stream Gemini's words; collect any function calls.
    try {
      final request = [..._history, Content('user', parts)];
      await for (final chunk in _modelFor(tools).generateContentStream(request)) {
        final delta = chunk.text;
        if (delta != null && delta.isNotEmpty) {
          reply.write(delta);
          yield AiTextDelta(delta);
        }
        calls.addAll(chunk.functionCalls);
      }
    } on FirebaseAIException catch (e) {
      // Blocked answers, App Check, quota, wrong model name... the real reason
      // goes to the Debug Console; the customer gets a short Arabic message.
      debugPrint('GeminiAiAssistant: FirebaseAIException: ${e.message}');
      _turn--; // this message never happened
      throw AiAssistantException(
        _isQuota(e.message) ? _busyError : _networkError,
      );
    } catch (e) {
      debugPrint('GeminiAiAssistant: $e');
      _turn--;
      throw AiAssistantException(
        _isQuota('$e') ? _busyError : _networkError,
      );
    }

    // 2–3. Run the functions in order; the app writes what comes next.
    final appSentences = <String>[];
    for (final call in calls) {
      final outcome = await tools.handle(call.name, call.args, turn: turn);
      debugPrint('GeminiAiAssistant: ${call.name} → ${outcome.result}');
      for (final event in outcome.events) {
        yield event;
      }
      final sentence = outcome.reply;
      if (sentence != null && !appSentences.contains(sentence)) {
        appSentences.add(sentence);
      }
    }
    if (calls.isNotEmpty && appSentences.isEmpty && reply.isEmpty) {
      appSentences.add(_toolFailedReply);
    }
    if (appSentences.isNotEmpty) {
      final appText =
          '${reply.isEmpty ? '' : '\n'}${appSentences.join('\n')}';
      reply.write(appText);
      yield AiTextDelta(appText);
    }
    if (reply.isEmpty) {
      reply.write(_emptyReply);
      yield const AiTextDelta(_emptyReply);
    }

    // 4. Remember the exchange as text only.
    _history
      ..add(Content('user', [TextPart(_historyText(text, imageBytes))]))
      ..add(Content('model', [TextPart(reply.toString())]));
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }
  }

  /// Photos are not kept in the history (they are large); Gemini's own
  /// description of the photo, in its reply, keeps the context.
  static String _historyText(String text, Uint8List? imageBytes) {
    final trimmed = text.trim();
    if (imageBytes == null) return trimmed;
    return trimmed.isEmpty ? '[أرفق العميل صورة]' : '$trimmed\n[أرفق العميل صورة]';
  }

  static bool _isQuota(String message) {
    final m = message.toLowerCase();
    return m.contains('quota') ||
        m.contains('resource_exhausted') ||
        m.contains('rate limit');
  }

  List<Part> _buildParts(String text, Uint8List? imageBytes, String mime) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageBytes == null) {
      throw const AiAssistantException('اكتب وصف المشكلة أو أرفق صورة.');
    }
    if (imageBytes != null) {
      if (!supportedImageTypes.contains(mime)) {
        throw const AiAssistantException(
          'نوع الصورة غير مدعوم. استخدم صورة JPG أو PNG.',
        );
      }
      if (imageBytes.length > maxImageBytes) {
        throw const AiAssistantException('الصورة كبيرة جدًا. جرّب صورة أصغر.');
      }
    }
    return [
      if (trimmed.isNotEmpty) TextPart(trimmed),
      if (imageBytes != null) InlineDataPart(mime, imageBytes),
    ];
  }
}
