import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;

import '../models/vehicle.dart';

/// The contract between the AI "brain" (piece 1) and the rest of the app.
///
/// The chat screen (piece 2) and the cards (piece 4) only know this file.
/// They never import Gemini, so they can be built and tested with
/// `FakeAiAssistant` before the real assistant is ready.
///
/// HOW THE CHAT SCREEN USES IT
/// ```dart
/// await for (final event in assistant.send(text, imageBytes: photo)) {
///   switch (event) {
///     case AiTextDelta(:final text):
///       bubble.append(text);               // add the words to the bubble
///     case AiVehicleChanged(:final vehicle):
///       header.show(vehicle);              // "المركبة: ..."
///     case AiOrderSummaryShown(:final summary):
///       cards.add(summary);                // the summary card
///     case AiOrderSummaryCancelled(:final summaryId):
///       cards.markCancelled(summaryId);    // grey out that card
///     case AiOrderPlaced(:final summary):
///       cards.markSent(summary.id);        // "تم إرسال الطلب"
///   }
/// }
/// ```
/// Errors arrive as a stream error of type [AiAssistantException], whose
/// message is Arabic and can be shown as it is. Disable the send button while
/// a stream is running: messages must be sent one at a time.
abstract class AiAssistant {
  /// Sends one customer message (text, an image, or both). The reply arrives
  /// as a stream of [AiEvent]s and the stream closes when the reply is done.
  ///
  /// The conversation is remembered between calls until [reset] is called.
  Stream<AiEvent> send(
    String text, {
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  });

  /// Forgets the conversation, any summary waiting for confirmation, and goes
  /// back to the default vehicle.
  void reset();

  /// The customer's vehicles, loaded on the first [send]. Empty before that.
  List<Vehicle> get vehicles;

  /// The vehicle the conversation is about. Starts as the vehicle selected on
  /// the home page (or the first one) and changes when the customer says the
  /// problem is with another of their cars.
  Vehicle? get activeVehicle;

  /// Called by the summary card after the customer picks a point on the map
  /// (LocationPickerPage): the pickup point if GPS failed or they want a
  /// different one, or the drop-off point for towing.
  ///
  /// Returns the updated summary to redraw the card, or null when that card
  /// is no longer waiting (already sent, replaced or cancelled).
  OrderSummary? updateSummaryLocation(
    String summaryId, {
    GeoPoint? pickup,
    GeoPoint? dropoff,
  });
}

// -----------------------------------------------------------------------------
// Events
// -----------------------------------------------------------------------------

/// Everything that can happen while the assistant replies. `sealed` means the
/// chat screen's `switch` must handle every kind, or it won't compile.
sealed class AiEvent {
  const AiEvent();
}

/// A few new words of the assistant's reply. Append them to the bubble.
final class AiTextDelta extends AiEvent {
  const AiTextDelta(this.text);
  final String text;
}

/// The customer said the problem is with another of their cars.
final class AiVehicleChanged extends AiEvent {
  const AiVehicleChanged(this.vehicle);
  final Vehicle vehicle;
}

/// Show the order summary card in the chat. The assistant then asks the
/// customer to confirm.
final class AiOrderSummaryShown extends AiEvent {
  const AiOrderSummaryShown(this.summary);
  final OrderSummary summary;
}

/// An earlier summary card is no longer valid (the customer changed the car or
/// the service, so a new card replaces it). Grey it out.
final class AiOrderSummaryCancelled extends AiEvent {
  const AiOrderSummaryCancelled(this.summaryId);
  final String summaryId;
}

/// The order was written to Firestore after the customer confirmed.
final class AiOrderPlaced extends AiEvent {
  const AiOrderPlaced({required this.orderId, required this.summary});
  final String orderId;
  final OrderSummary summary;
}

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

/// What the summary card shows. Built by the APP, not by Gemini: the model
/// only chooses ids, and the price and labels come from the catalog and
/// `lookup_data/service_prices`, exactly like the review page (#17).
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.vehicle,
    required this.categoryId,
    required this.categoryLabel,
    required this.optionId,
    required this.optionLabel,
    required this.note,
    required this.estimatedPrice,
    required this.needsDropoff,
    this.pickupLocation,
    this.dropoffLocation,
  });

  /// Local id inside this chat ('S1', 'S2'...), not a Firestore id.
  final String id;

  final Vehicle vehicle;
  final String categoryId;
  final String categoryLabel;
  final String optionId;
  final String optionLabel;

  /// A short description of the problem for the provider, written by the
  /// assistant from the conversation. Can be empty.
  final String note;

  /// null when this service has no price yet.
  final num? estimatedPrice;

  /// Towing: needs a drop-off location, and the price shown is not final
  /// because it depends on the distance.
  final bool needsDropoff;

  bool get priceDependsOnDistance => needsDropoff;

  /// Where the vehicle is (#15). Filled from GPS automatically; null when GPS
  /// failed, and then the card asks the customer to choose it on the map.
  final GeoPoint? pickupLocation;

  /// Towing destination (#16). The chat cannot choose it; the card asks the
  /// customer to pick it on the map.
  final GeoPoint? dropoffLocation;

  /// null when the order can be sent; otherwise what the card should ask for.
  /// Same messages as OrderDraftController.validate().
  String? get missingLocationMessage {
    if (pickupLocation == null) return 'حدد موقع المركبة';
    if (needsDropoff && dropoffLocation == null) return 'حدد موقع التوصيل';
    return null;
  }

  OrderSummary copyWithLocations({GeoPoint? pickup, GeoPoint? dropoff}) {
    return OrderSummary(
      id: id,
      vehicle: vehicle,
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      optionId: optionId,
      optionLabel: optionLabel,
      note: note,
      estimatedPrice: estimatedPrice,
      needsDropoff: needsDropoff,
      pickupLocation: pickup ?? pickupLocation,
      dropoffLocation: dropoff ?? dropoffLocation,
    );
  }
}

/// Thrown into the stream by [AiAssistant.send]. [message] is Arabic and safe
/// to show to the customer.
class AiAssistantException implements Exception {
  const AiAssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}
