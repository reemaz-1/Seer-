import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;

import '../controllers/location_controller.dart';
import '../controllers/order_draft_controller.dart';
import '../models/pricing_model.dart';
import '../models/vehicle.dart';
import 'ai_assistant.dart';

/// What the AI is allowed to do in the real app. The AI never touches
/// Firestore itself: it goes through these three methods, so the rules for
/// creating an order stay in ONE place (OrderDraftController), whether the
/// order comes from the request page or from the chat.
abstract class AiOrderActions {
  /// The signed-in customer's vehicles.
  Future<List<Vehicle>> loadVehicles();

  /// The current service prices (Firestore, or the built-in fallback).
  Future<ServicePrices> loadPrices();

  /// The phone's GPS position, or null when it can't be read (permission
  /// refused, GPS off...). Used as the pickup location (#15).
  Future<GeoPoint?> currentLocation();

  /// Creates the order and returns its Firestore id.
  /// Throws [AiOrderException] with an Arabic message when it fails.
  Future<String> placeOrder(OrderSummary summary);
}

/// [message] is Arabic; the assistant repeats it to the customer.
class AiOrderException implements Exception {
  const AiOrderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The real implementation, used by the chat screen:
/// ```dart
/// final assistant = GeminiAiAssistant(
///   actions: FirestoreAiOrderActions(
///     uid: FirebaseAuth.instance.currentUser!.uid,
///   ),
///   preferredVehicleId: vehicleShownOnHome?.id,
/// );
/// ```
class FirestoreAiOrderActions implements AiOrderActions {
  FirestoreAiOrderActions({
    required this.uid,
    VehicleModel? vehicleModel,
    PricingModel? pricingModel,
  })  : _vehicleModel = vehicleModel ?? VehicleModel(),
        _pricingModel = pricingModel ?? PricingModel();

  final String uid;
  final VehicleModel _vehicleModel;
  final PricingModel _pricingModel;

  @override
  Future<List<Vehicle>> loadVehicles() => _vehicleModel.getVehicles(uid);

  @override
  Future<ServicePrices> loadPrices() async {
    try {
      return await _pricingModel.getPrices();
    } catch (e) {
      return ServicePrices.fallback();
    }
  }

  /// Same LocationController as the «استخدام موقعي الحالي» button on the
  /// request page, so permissions and errors behave the same way.
  @override
  Future<GeoPoint?> currentLocation() async {
    final location = LocationController();
    try {
      final ok = await location.getCurrentLocation();
      return ok ? location.pickupLocation : null;
    } finally {
      location.dispose();
    }
  }

  /// Uses the same controller as the request page, so a chat order has the
  /// same fields (customer name and phone, plate, price, status) as any other.
  @override
  Future<String> placeOrder(OrderSummary summary) async {
    final draft = OrderDraftController(
      uid: uid,
      categoryId: summary.categoryId,
      preferredVehicleId: summary.vehicle.id,
    );
    try {
      await draft.loadPrices();
      await draft.loadVehicles();
      if (draft.vehiclesError != null) {
        throw AiOrderException(draft.vehiclesError!);
      }
      // loadVehicles falls back to the first vehicle when the id is missing;
      // never send an order for a different car than the one in the card.
      if (draft.selectedVehicle?.id != summary.vehicle.id) {
        throw const AiOrderException('هذه المركبة لم تعد موجودة في حسابك.');
      }
      draft.selectOption(summary.optionId);
      draft.setNote(summary.note);
      final pickup = summary.pickupLocation;
      if (pickup != null) draft.setPickupLocation(pickup);
      final dropoff = summary.dropoffLocation;
      if (summary.needsDropoff && dropoff != null) {
        draft.setDropoffLocation(dropoff);
      }

      final error = await draft.submit();
      if (error != null) throw AiOrderException(error);
      return draft.createdOrderId ?? '';
    } finally {
      draft.dispose();
    }
  }
}
