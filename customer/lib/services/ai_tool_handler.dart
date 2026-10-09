import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:firebase_ai/firebase_ai.dart';

import '../models/pricing_model.dart';
import '../models/service_catalog.dart';
import '../models/vehicle.dart';
import 'ai_assistant.dart';
import 'ai_order_actions.dart';

/// The result of one function call: what the chat screen should show, and
/// what the app says next.
class AiToolOutcome {
  const AiToolOutcome(this.result, {this.events = const [], this.reply});

  AiToolOutcome.error(String message, {this.reply})
      : result = {'ok': false, 'error': message},
        events = const [];

  /// Details of what happened (kept for debugging and tests).
  final Map<String, Object?> result;
  final List<AiEvent> events;

  /// The Arabic sentence the APP writes to the customer after this function
  /// ran («هل تؤكد الطلب؟», «تم إرسال طلبك»...). null = nothing to add.
  ///
  /// The app writes it instead of Gemini because firebase_ai 2.x drops the
  /// "thought signature" Gemini 3 needs to continue after a function call.
  /// It also guarantees that only the app can say an order was sent.
  final String? reply;

  bool get ok => result['ok'] == true;
}

/// Runs the three functions Gemini can call, and enforces the rules in CODE,
/// so a model mistake can never create a wrong order:
///
/// - ids must exist (the customer's vehicles, the catalog's services);
/// - the price comes from the app, never from the model;
/// - `place_order` only works for the summary the customer is looking at,
///   and only in a LATER message than the one that showed it, so the
///   customer always sees the card before anything is sent;
/// - one summary can be placed only once;
/// - it cannot be placed until it has a pickup location (and a drop-off for
///   towing), the same rule as the request page.
///
/// It has no Firebase calls of its own, so it is fully unit-tested.
class AiToolHandler {
  AiToolHandler({
    required this.actions,
    required List<Vehicle> vehicles,
    String? activeVehicleId,
    this.summaryIdPrefix = '',
  }) : vehicles = List.unmodifiable(vehicles) {
    activeVehicle =
        _findVehicle(activeVehicleId) ?? (vehicles.isEmpty ? null : vehicles.first);
  }

  static const setVehicleName = 'set_active_vehicle';
  static const showSummaryName = 'show_order_summary';
  static const placeOrderName = 'place_order';

  /// Same limit as the note field on the request page (#23).
  static const maxNoteLength = 200;

  final AiOrderActions actions;
  final List<Vehicle> vehicles;

  /// Put before every summary id, so ids from an earlier chat on the same
  /// screen never repeat ('C2-S1' after 'C1-S1').
  final String summaryIdPrefix;
  Vehicle? activeVehicle;

  /// The card waiting for the customer's answer.
  OrderSummary? pendingSummary;
  int _pendingTurn = -1;
  int _summaryCount = 0;
  bool _placing = false;

  /// The last order sent from this chat, so Gemini knows not to send it again.
  OrderSummary? lastPlaced;

  /// Locations already known in this chat, reused by the next summary so GPS
  /// isn't read again and a point picked on the map isn't lost.
  GeoPoint? _knownPickup;
  GeoPoint? _knownDropoff;

  // ---------------------------------------------------------------------------
  // Declarations sent to Gemini
  // ---------------------------------------------------------------------------

  /// Built per conversation, so the vehicle ids are this customer's real ones
  /// and the model can only pick from them. Empty when there are no vehicles:
  /// without a vehicle there is nothing to order.
  static List<FunctionDeclaration> declarations(List<Vehicle> vehicles) {
    if (vehicles.isEmpty) return const [];
    final vehicleIds = [for (final v in vehicles) v.id];

    return [
      FunctionDeclaration(
        setVehicleName,
        'Switches the conversation to another of the customer\'s vehicles, '
            'when they say the problem is with a different car.',
        parameters: {
          'vehicleId': Schema.enumString(
            enumValues: vehicleIds,
            description: 'An id from the customer\'s vehicle list.',
          ),
        },
      ),
      FunctionDeclaration(
        showSummaryName,
        'Shows the customer an order summary card (vehicle, service, '
            'estimated price) inside the chat. Call it when you know the '
            'problem, the service that fixes it and which vehicle it is for. '
            'The app fills in the price; then ask the customer to confirm.',
        parameters: {
          'vehicleId': Schema.enumString(
            enumValues: vehicleIds,
            description: 'The vehicle that needs the service.',
          ),
          'categoryId': Schema.enumString(
            enumValues: [for (final c in ServiceCatalog.categories) c.id],
            description: 'The service category.',
          ),
          'optionId': Schema.enumString(
            enumValues: [
              for (final c in ServiceCatalog.categories)
                for (final o in c.options) o.id,
            ],
            description: 'The option inside that category; it must belong '
                'to categoryId.',
          ),
          'note': Schema.string(
            description: 'A short Arabic description of the problem for the '
                'provider (max $maxNoteLength characters). No personal data.',
          ),
        },
        optionalParameters: ['note'],
      ),
      FunctionDeclaration(
        placeOrderName,
        'Sends the order shown in the summary card. Call it ONLY after the '
            'customer clearly confirmed in a new message after seeing the '
            'card.',
        parameters: {
          'summaryId': Schema.string(
            description: 'The summaryId returned by show_order_summary.',
          ),
        },
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Handling calls
  // ---------------------------------------------------------------------------

  /// [turn] is the number of the customer's message being answered; it is
  /// how the handler knows whether the customer has replied to a card yet.
  Future<AiToolOutcome> handle(
    String name,
    Map<String, Object?> args, {
    required int turn,
  }) {
    switch (name) {
      case setVehicleName:
        return Future.value(_setVehicle(args));
      case showSummaryName:
        return _showSummary(args, turn);
      case placeOrderName:
        return _placeOrder(args, turn);
      default:
        return Future.value(AiToolOutcome.error('Unknown function "$name".'));
    }
  }

  AiToolOutcome _setVehicle(Map<String, Object?> args) {
    final vehicle = _findVehicle(args['vehicleId']);
    if (vehicle == null) {
      return AiToolOutcome.error(
        'Unknown vehicleId. Use an id from the customer\'s vehicle list.',
        reply: 'هذه المركبة ليست في حسابك. أضفها أولًا من صفحة «مركباتي».',
      );
    }
    if (vehicle.id == activeVehicle?.id) {
      return AiToolOutcome({
        'ok': true,
        'activeVehicle': vehicle.title,
        'changed': false,
      });
    }

    activeVehicle = vehicle;
    final events = <AiEvent>[AiVehicleChanged(vehicle)];
    final cancelled = _cancelPending();
    if (cancelled != null) events.add(AiOrderSummaryCancelled(cancelled.id));

    return AiToolOutcome({
      'ok': true,
      'activeVehicle': vehicle.title,
      'changed': true,
      'previousSummaryCancelled': cancelled != null,
      if (cancelled != null)
        'next': 'The old summary was for another car. If the customer still '
            'wants the service, call show_order_summary again for this car.',
    },
        events: events,
        reply: cancelled == null
            ? 'تمام، صارت المحادثة عن ${vehicle.title}.'
            : 'تمام، صارت المحادثة عن ${vehicle.title}، وألغيت الملخص '
                'السابق لأنه كان لسيارة أخرى.');
  }

  Future<AiToolOutcome> _showSummary(Map<String, Object?> args, int turn) async {
    final vehicle = _findVehicle(args['vehicleId']);
    if (vehicle == null) {
      return AiToolOutcome.error(
        'Unknown vehicleId. Use an id from the customer\'s vehicle list.',
        reply: 'هذه المركبة ليست في حسابك. أضفها أولًا من صفحة «مركباتي».',
      );
    }
    final categoryId = args['categoryId'];
    final optionId = args['optionId'];
    if (categoryId is! String || optionId is! String) {
      return AiToolOutcome.error('categoryId and optionId are required.');
    }
    final category = ServiceCatalog.categoryById(categoryId);
    final option = ServiceCatalog.optionById(categoryId, optionId);
    if (category == null || option == null) {
      return AiToolOutcome.error(
        'optionId "$optionId" is not part of categoryId "$categoryId". '
        'Pick a valid pair from the catalog.',
      );
    }

    final events = <AiEvent>[];
    if (vehicle.id != activeVehicle?.id) {
      activeVehicle = vehicle;
      events.add(AiVehicleChanged(vehicle));
    }

    ServicePrices prices;
    try {
      prices = await actions.loadPrices();
    } catch (e) {
      prices = ServicePrices.fallback();
    }

    final rawNote = args['note'];
    var note = rawNote is String ? rawNote.trim() : '';
    if (note.length > maxNoteLength) note = note.substring(0, maxNoteLength);

    var pickup = _knownPickup;
    if (pickup == null) {
      try {
        pickup = await actions.currentLocation();
      } catch (e) {
        pickup = null;
      }
      _knownPickup = pickup;
    }

    final summary = OrderSummary(
      id: '${summaryIdPrefix}S${++_summaryCount}',
      vehicle: vehicle,
      categoryId: categoryId,
      categoryLabel: category.label,
      optionId: optionId,
      optionLabel: option.label,
      note: note,
      estimatedPrice: prices.basePriceFor(optionId),
      needsDropoff: categoryId == ServiceCatalog.towingId,
      pickupLocation: pickup,
      dropoffLocation:
          categoryId == ServiceCatalog.towingId ? _knownDropoff : null,
    );

    final replaced = _cancelPending();
    if (replaced != null) events.add(AiOrderSummaryCancelled(replaced.id));
    pendingSummary = summary;
    _pendingTurn = turn;
    events.add(AiOrderSummaryShown(summary));

    return AiToolOutcome({
      'ok': true,
      'summaryId': summary.id,
      'vehicle': vehicle.title,
      'service': '${category.label}: ${option.label}',
      'estimatedPriceSar': summary.estimatedPrice,
      'priceIsApproximate': summary.priceDependsOnDistance,
      // Coordinates are never sent to Gemini, only whether they are set.
      'pickupLocationSet': summary.pickupLocation != null,
      if (summary.needsDropoff)
        'dropoffLocationSet': summary.dropoffLocation != null,
      'next': summary.missingLocationMessage == null
          ? 'The card is now on screen with all details. Ask the customer in '
              'ONE short sentence whether they confirm. Do NOT call '
              'place_order now; wait for their reply.'
          : 'The card is on screen but a location is missing '
              '(${summary.missingLocationMessage}). Ask the customer in ONE '
              'short sentence to choose it with the map button on the card, '
              'then confirm. Do NOT call place_order now.',
    },
        events: events,
        reply: summary.missingLocationMessage == null
            ? 'هل تؤكد الطلب؟'
            : '${summary.missingLocationMessage} من زر الخريطة في الكرت، '
                'ثم أكّد الطلب.');
  }

  Future<AiToolOutcome> _placeOrder(Map<String, Object?> args, int turn) async {
    if (_placing) {
      return AiToolOutcome.error(
        'An order is already being sent.',
        reply: 'جارٍ إرسال الطلب، لحظة من فضلك.',
      );
    }
    final summary = pendingSummary;
    if (summary == null) {
      return AiToolOutcome.error(
        'There is no summary waiting for confirmation (it may already have '
        'been sent). Call show_order_summary first if the customer wants a '
        'new order.',
        reply: lastPlaced != null
            ? 'تم إرسال هذا الطلب مسبقًا، ولا يوجد طلب آخر بانتظار التأكيد.'
            : 'لا يوجد طلب بانتظار التأكيد. أخبرني بما تحتاجه وأجهّز لك ملخصًا.',
      );
    }
    if (args['summaryId'] != summary.id) {
      return AiToolOutcome.error(
        'summaryId does not match the card on screen (${summary.id}).',
        reply: 'هذا الكرت لم يعد صالحًا. راجع آخر ملخص ثم أكّد.',
      );
    }
    if (turn <= _pendingTurn) {
      return AiToolOutcome.error(
        'The customer has not answered the summary yet. Ask them to confirm '
        'and wait for their reply.',
      );
    }
    final missing = summary.missingLocationMessage;
    if (missing != null) {
      return AiToolOutcome.error(
        'The order was NOT sent: a location is missing. Tell the customer: '
        '"$missing" using the map button on the card, then confirm again.',
        reply: 'لم يُرسل الطلب بعد: $missing من زر الخريطة في الكرت، ثم أكّد.',
      );
    }

    _placing = true;
    try {
      final orderId = await actions.placeOrder(summary);
      pendingSummary = null;
      lastPlaced = summary;
      return AiToolOutcome(
        {'ok': true, 'orderId': orderId},
        events: [AiOrderPlaced(orderId: orderId, summary: summary)],
        reply: 'تم إرسال طلبك ✅ وسيصلك إشعار عندما يقبله مقدم الخدمة.',
      );
    } on AiOrderException catch (e) {
      return AiToolOutcome.error(
        'The order was NOT sent: ${e.message}',
        reply: 'لم يُرسل الطلب: ${e.message}',
      );
    } catch (e) {
      return AiToolOutcome.error(
        'The order was NOT sent because of a connection problem.',
        reply: 'لم يُرسل الطلب بسبب مشكلة في الاتصال. أكّد مرة أخرى بعد قليل.',
      );
    } finally {
      _placing = false;
    }
  }

  /// Called from the card after the customer picks a point on the map.
  /// Returns the updated summary, or null if [summaryId] is not the card
  /// waiting for confirmation.
  OrderSummary? updateLocation(
    String summaryId, {
    GeoPoint? pickup,
    GeoPoint? dropoff,
  }) {
    final summary = pendingSummary;
    if (summary == null || summary.id != summaryId) return null;
    if (pickup != null) _knownPickup = pickup;
    if (dropoff != null && summary.needsDropoff) _knownDropoff = dropoff;
    final updated = summary.copyWithLocations(
      pickup: pickup,
      dropoff: summary.needsDropoff ? dropoff : null,
    );
    pendingSummary = updated;
    return updated;
  }

  /// The current state in Arabic, written into Gemini's instructions before
  /// every message. This is how Gemini learns what the functions did.
  String describeState() {
    final lines = <String>[];
    final vehicle = activeVehicle;
    lines.add(vehicle == null
        ? '- لا توجد مركبة.'
        : '- المركبة الحالية: ${vehicle.title} (vehicleId: ${vehicle.id}).');

    final s = pendingSummary;
    if (s == null) {
      lines.add('- لا يوجد ملخص طلب ينتظر التأكيد.');
    } else {
      lines.add('- ملخص ينتظر تأكيد العميل (summaryId: ${s.id}): '
          '${s.categoryLabel} ← ${s.optionLabel}، لمركبة ${s.vehicle.title}.');
      final missing = s.missingLocationMessage;
      lines.add(missing == null
          ? '- مواقع هذا الطلب مكتملة، ويُرسل إذا أكّد العميل.'
          : '- ينقص هذا الطلب: $missing. العميل يحدده من زر الخريطة في الكرت.');
    }

    final placed = lastPlaced;
    if (placed != null) {
      lines.add('- أُرسل في هذه المحادثة طلب: ${placed.optionLabel} لمركبة '
          '${placed.vehicle.title}. لا ترسله مرة أخرى.');
    }
    return lines.join('\n');
  }

  OrderSummary? _cancelPending() {
    final old = pendingSummary;
    pendingSummary = null;
    _pendingTurn = -1;
    return old;
  }

  Vehicle? _findVehicle(Object? id) {
    if (id is! String) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }
}
