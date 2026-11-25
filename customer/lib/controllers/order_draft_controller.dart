import 'package:flutter/foundation.dart';
 
import '../models/customer.dart';
import '../models/order.dart';
import '../models/pricing_model.dart';
import '../models/service_catalog.dart';
import '../models/vehicle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'matching_controller.dart';
import '../models/notification_model.dart';
 
/// CONTROLLER: holds the service request while the customer is building it,
/// and creates it at the end.
///
/// Covers choosing the service option (#13), the vehicle (#14) and the note
/// (#23). The review page (#17) reads the same object before it is sent.
class OrderDraftController extends ChangeNotifier {
  OrderDraftController({
    required this.uid,
    required this.categoryId,
    this.preferredVehicleId,
    this.useFreeWash = false,
    VehicleModel? vehicleModel,
    OrderModel? orderModel,
    PricingModel? pricingModel,
    CustomerModel? customerModel,
  })  : _vehicleModel = vehicleModel ?? VehicleModel(),
        _orderModel = orderModel ?? OrderModel(),
        _pricingModel = pricingModel ?? PricingModel(),
        _customerModel = customerModel ?? CustomerModel();
 
  final String uid;
 
  /// The service picked on the home page: 'battery', 'fuel', 'tires', 'towing', 'carwash'.
  final String categoryId;
 
  /// The vehicle shown on the home page, so the same one is pre-selected here.
  final String? preferredVehicleId;

  /// True when the customer opened this request from the loyalty card to
  /// use a free car cleaning (#67).
  final bool useFreeWash;

  /// Takes no inputs; returns true when this order is a free car cleaning.
  /// Only the car wash service can be free.
  bool get isFreeWash => useFreeWash && categoryId == 'carwash';
 
  final VehicleModel _vehicleModel;
  final OrderModel _orderModel;
  final PricingModel _pricingModel;
  final CustomerModel _customerModel;
  final MatchingController _matching = MatchingController();
  final NotificationSender _notifications = NotificationSender();
 
  List<Vehicle> vehicles = [];
  bool isLoadingVehicles = true;
  bool isSubmitting = false;
  /// the id of the order once it is saved, so the next page can follow it
  /// True when the last submit found no nearby provider (#19),
  /// so the view can explain it instead of showing a short message.
  bool noNearbyProviders = false;
  String? vehiclesError;
 
  ServicePrices prices = ServicePrices.fallback();
 
  /// Read so the order can carry the customer's name and phone, which is what
  /// the provider app shows and calls (Shams #37, Dana #43).
  Customer? customer;
 
  String? selectedOptionId;

  /// 'standard' or 'large'. Only used by services priced by size (car wash),
  /// and only when the chosen vehicle has no body type saved yet.
  String? vehicleSizeId;

  /// Car wash: which parts the customer ticked. Both ticked = full wash.
  bool washExterior = false;
  bool washInterior = false;
  Vehicle? selectedVehicle;
  String note = '';

  /// Null keeps the existing immediate-order flow untouched.
  DateTime? scheduledAt;
  void setScheduledAt(DateTime? value) {
    scheduledAt = value;
    notifyListeners();
  }

  /// The id of the order once it is created, so its details page can be
  /// opened right after sending it (#20).
  String? createdOrderId;
  // Locations selected while building this specific order.
// Each new order draft gets its own pickup/drop-off locations.
GeoPoint? pickupLocation;
GeoPoint? dropoffLocation;

/// Saves the vehicle's current location for all service requests (#15).
void setPickupLocation(GeoPoint location) {
  pickupLocation = location;
  notifyListeners();
}

/// Saves the destination for towing requests only (#16).
void setDropoffLocation(GeoPoint location) {
  dropoffLocation = location;
  notifyListeners();
}

/// Removes an old towing destination if this draft no longer needs one.
void clearDropoffLocation() {
  dropoffLocation = null;
  notifyListeners();
}

  /// Fills this draft from an earlier order, used by reorder (#21).
  ///
  /// Copies the service option, the note and both locations. The vehicle is
  /// chosen through [preferredVehicleId] when the vehicles load.
  ///
  /// Parameters: [order] is the rejected or auto-cancelled order to copy.
  /// Returns: nothing.
  void prefillFromOrder(ServiceOrder order) {
    selectedOptionId = order.serviceOptionId;
    _syncWashParts();
    note = order.note;
    pickupLocation = order.pickupLocation;
    dropoffLocation = order.dropoffLocation;
  }

  /// Fills this draft from the AI assistant's suggestion, so the customer
  /// can check and change everything on the request page.
  ///
  /// Parameters: [optionId] is the suggested service option; [note] is the
  /// problem description; [pickup] and [dropoff] are the locations the
  /// assistant already knows, when there are any.
  /// Returns: nothing.
  void prefillFromSuggestion({
    required String optionId,
    String note = '',
    GeoPoint? pickup,
    GeoPoint? dropoff,
    String? vehicleSizeId,
  }) {
    selectedOptionId = optionId;
    _syncWashParts();
    this.vehicleSizeId = vehicleSizeId;
    this.note = note;
    if (pickup != null) pickupLocation = pickup;
    if (dropoff != null) dropoffLocation = dropoff;
  }

  ServiceCategory? get category => ServiceCatalog.categoryById(categoryId);
 
  ServiceOption? get selectedOption => selectedOptionId == null
      ? null
      : ServiceCatalog.optionById(categoryId, selectedOptionId!);
 
  /// Towing is the only service that also needs a drop-off location (#16).
  bool get needsDropoff => categoryId == ServiceCatalog.towingId;

  /// Car wash: the price depends on the size of the car.
  bool get needsVehicleSize => category?.priceBySize ?? false;

  /// The size comes from the chosen vehicle's body type. A vehicle saved before
  /// that field existed has none, so the size picked on this page is used.
  VehicleSize? get vehicleSize => needsVehicleSize
      ? VehicleSize.byId(selectedVehicle?.bodyType ?? vehicleSizeId)
      : null;

  /// True when the customer still has to say what type the vehicle is.
  bool get needsBodyTypeChoice =>
      needsVehicleSize &&
      selectedVehicle != null &&
      selectedVehicle!.bodyType == null;

  /// The option name as it is saved in the order and shown on the review
  /// page. The size is part of it ("غسيل خارجي - دفع رباعي"), so the provider
  /// sees it and can compare it with the car, without a new database field.
  String get selectedOptionLabel {
    final option = selectedOption;
    if (option == null) return '';
    final size = vehicleSize;
    return size == null ? option.label : '${option.label} - ${size.shortLabel}';
  }
 
  /// Loads the prices shown next to each option (#17). Never throws: the
  /// built-in list is used when Firestore cannot be read.
  Future<void> loadPrices() async {
    try {
      prices = await _pricingModel.getPrices();
    } catch (e) {
      prices = ServicePrices.fallback();
    }
    notifyListeners();
  }
 
  /// The price of one option, used in the list of options.
  num? priceOf(String optionId) =>
      prices.priceFor(optionId, sizeId: vehicleSize?.id);
 
  /// The fixed price of the chosen option, before any distance fee.
  /// null when this service has no price yet.
  num? get basePrice => selectedOptionId == null
      ? null
      : prices.priceFor(selectedOptionId!, sizeId: vehicleSize?.id);

  /// Straight-line distance in km between the pickup and the drop-off.
  /// Towing only, and null until both locations are chosen.
  double? get towingDistanceKm {
    final pickup = pickupLocation;
    final dropoff = dropoffLocation;
    if (!needsDropoff || pickup == null || dropoff == null) return null;
    return MatchingController.distanceKm(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );
  }

  /// The towing distance fee in riyals (distance x price per km). null when
  /// this is not a towing request or a location is still missing.
  num? get distanceFee {
    final km = towingDistanceKm;
    return km == null ? null : (km * prices.towingPerKm).round();
  }

  /// What the customer is charged: the base price (per car size for the car
  /// wash) plus the distance fee when it applies. null when this service has no price yet.
  num? get estimatedPrice {
    // #67: a free car cleaning costs nothing, whatever the size.
    if (isFreeWash) return 0;
    final base = basePrice;
    if (base == null) return null;
    return base + (distanceFee ?? 0);
  }
 
  /// Towing also costs per kilometre, which needs the distance from #15/#76,
  /// so the customer is told the shown price is not the whole amount yet.
  bool get priceDependsOnDistance => needsDropoff;
 
  /// Loads the customer's vehicles and pre-selects one, so a customer with a
  /// single vehicle never has to choose.
  Future<void> loadVehicles() async {
    isLoadingVehicles = true;
    vehiclesError = null;
    notifyListeners();
    try {
      vehicles = await _vehicleModel.getVehicles(uid);
      // Not fatal: the order is still created if this read fails.
      try {
        customer = await _customerModel.getCustomer(uid);
      } catch (e) {
        customer = null;
      }
      if (vehicles.isNotEmpty) {
        selectedVehicle = vehicles.firstWhere(
          (v) => v.id == preferredVehicleId,
          orElse: () => vehicles.first,
        );
      }
    } catch (e) {
      vehiclesError = 'تعذّر تحميل مركباتك. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';
    } finally {
      isLoadingVehicles = false;
      notifyListeners();
    }
  }
 
  void selectOption(String optionId) {
    selectedOptionId = optionId;
    _syncWashParts();
    notifyListeners();
  }

  /// Car wash: ticks or unticks exterior / interior. The option id follows:
  /// one part gives that wash, both give the full wash.
  void toggleWashPart({required bool exterior}) {
    if (exterior) {
      washExterior = !washExterior;
    } else {
      washInterior = !washInterior;
    }
    selectedOptionId = CarWash.optionFor(
      exterior: washExterior,
      interior: washInterior,
    );
    notifyListeners();
  }

  void _syncWashParts() {
    final id = selectedOptionId;
    washExterior = id == CarWash.exteriorId || id == CarWash.fullId;
    washInterior = id == CarWash.interiorId || id == CarWash.fullId;
  }
 
  void selectVehicleSize(String sizeId) {
    vehicleSizeId = sizeId;
    notifyListeners();
  }

  void selectVehicle(Vehicle vehicle) {
    selectedVehicle = vehicle;
    // A size picked for the previous vehicle does not carry over.
    vehicleSizeId = null;
    notifyListeners();
  }

  /// The chosen vehicle has no body type yet (saved before the field existed):
  /// the customer picks it here, and it is saved on the vehicle so they are
  /// not asked again. A failed save never blocks the order.
  Future<void> chooseBodyType(String sizeId) async {
    final vehicle = selectedVehicle;
    if (vehicle == null) return;
    vehicleSizeId = sizeId;
    final updated = vehicle.copyWith(bodyType: sizeId);
    selectedVehicle = updated;
    vehicles = [for (final v in vehicles) v.id == updated.id ? updated : v];
    notifyListeners();
    try {
      await _vehicleModel.updateVehicle(uid, updated);
    } catch (e) {
      debugPrint('saving the vehicle type failed: $e');
    }
  }
 
  void setNote(String value) {
    note = value.trim();
  }
 
/// Returns null when the draft is ready, or the message to show.
String? validate() {
  if (scheduledAt != null) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 2);
    if (!scheduledAt!.isAfter(now) ||
        !scheduledAt!.isBefore(tomorrow)) {
      return 'حدد موعدًا مستقبليًا اليوم أو غدًا';
    }
  }
  if (selectedOptionId == null) {
    return needsVehicleSize ? 'اختر غسيل خارجي أو داخلي' : 'اختر نوع الخدمة';
  }
  if (needsVehicleSize && vehicleSize == null) {
    return 'حدد نوع المركبة: سيدان أو دفع رباعي';
  }
  if (selectedVehicle == null) return 'اختر المركبة';

  // Every service request needs the vehicle's current location (#15).
  if (pickupLocation == null) return 'حدد موقع المركبة';

  // Only towing requests require a destination (#16).
  if (needsDropoff && dropoffLocation == null) {
    return 'حدد موقع التوصيل';
  }

  return null;
}
  /// Creates the order. Returns null on success, or a message to show.
  ///
  /// NOTE for whoever takes #18 and #22: this writes the order with status
  /// 'pending' and no provider. Matching it to the nearest provider, and the
  /// 2-minute response window, happen after this point.
  Future<String?> submit() async {
    /** Prevents repeated taps from submitting the same draft concurrently. */
    if (isSubmitting) return 'الطلب قيد الإرسال، يرجى الانتظار.';
    final problem = validate();
    if (problem != null) return problem;
 
    isSubmitting = true;
    noNearbyProviders = false;
    notifyListeners();
    try {
      final vehicle = selectedVehicle!;
      final option = selectedOption!;
      // #18: every nearby provider who offers this service receives it
      final candidates = await _matching.findAvailableProviders(
        categoryId: categoryId,
        optionId: option.id,
        lat: pickupLocation!.latitude,
        lng: pickupLocation!.longitude,
        scheduled: scheduledAt != null,
      );

      // #19: nobody nearby, so nothing is saved
      if( candidates.isEmpty){
        noNearbyProviders = true;
        return scheduledAt != null
            ? 'لا يوجد مزود خدمة مؤهل للحجز في منطقتك'
            : 'لا يوجد مزود خدمة متاح بالقرب منك حاليًا';
      }


      final order = ServiceOrder(
        id: '',
        customerId: uid,
        customerName: customer?.fullName ?? '',
        customerPhone: customer?.phone ?? '',
        vehicleId: vehicle.id,
        vehicleTitle: vehicle.title,
        vehicleColor: vehicle.color,
        vehiclePlateArabic: vehicle.plateNumberArabic,
        vehiclePlateLatin: vehicle.plateNumberLatin,
        serviceCategoryId: categoryId,
        serviceCategoryLabel: category?.label ?? '',
        serviceOptionId: option.id,
        serviceOptionLabel: selectedOptionLabel,
        serviceBranch: option.branch,
        note: note,
        estimatedPrice: estimatedPrice,
        status: scheduledAt == null
            ? OrderStatus.pending : OrderStatus.scheduledPending,
        scheduledAt: scheduledAt,
        usedFreeWash: isFreeWash,

// Locations belong to this individual order.
// Non-towing orders intentionally store no drop-off location.
pickupLocation: pickupLocation,
dropoffLocation: needsDropoff ? dropoffLocation : null,
candidateProviderIds: candidates,
      );

      createdOrderId = await _orderModel.createOrder(order);

      // #47: notify every matched provider. A failed notification never
      // fails the order, because providers still see it in their list.
      try {
        await _notifications.notifyNewRequest(
          orderId: createdOrderId!,
          providerIds: candidates,
          serviceLabel: selectedOptionLabel,
          vehicleTitle: vehicle.title,
          scheduledAt: scheduledAt,
        );
      } catch (e) {
        debugPrint('notifyNewRequest failed: $e');
      }
      return null;
    } catch (e) {
      debugPrint('createOrder failed: $e'); // shows the real Firestore error
      return 'لم يتم إرسال الطلب. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
 