import 'package:flutter/foundation.dart';
 
import '../models/customer.dart';
import '../models/order.dart';
import '../models/pricing_model.dart';
import '../models/service_catalog.dart';
import '../models/vehicle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'matching_controller.dart';
 
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
    VehicleModel? vehicleModel,
    OrderModel? orderModel,
    PricingModel? pricingModel,
    CustomerModel? customerModel,
  })  : _vehicleModel = vehicleModel ?? VehicleModel(),
        _orderModel = orderModel ?? OrderModel(),
        _pricingModel = pricingModel ?? PricingModel(),
        _customerModel = customerModel ?? CustomerModel();
 
  final String uid;
 
  /// The service picked on the home page: 'battery', 'fuel', 'tires', 'towing'.
  final String categoryId;
 
  /// The vehicle shown on the home page, so the same one is pre-selected here.
  final String? preferredVehicleId;
 
  final VehicleModel _vehicleModel;
  final OrderModel _orderModel;
  final PricingModel _pricingModel;
  final CustomerModel _customerModel;
  final MatchingController _matching = MatchingController();
 
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
  Vehicle? selectedVehicle;
  String note = '';

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
    note = order.note;
    pickupLocation = order.pickupLocation;
    dropoffLocation = order.dropoffLocation;
  }

  ServiceCategory? get category => ServiceCatalog.categoryById(categoryId);
 
  ServiceOption? get selectedOption => selectedOptionId == null
      ? null
      : ServiceCatalog.optionById(categoryId, selectedOptionId!);
 
  /// Towing is the only service that also needs a drop-off location (#16).
  bool get needsDropoff => categoryId == ServiceCatalog.towingId;
 
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
  num? priceOf(String optionId) => prices.basePriceFor(optionId);
 
  /// What the customer is charged for the chosen option, before any distance
  /// fee. null when this service has no price yet.
  num? get estimatedPrice =>
      selectedOptionId == null ? null : prices.basePriceFor(selectedOptionId!);
 
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
    notifyListeners();
  }
 
  void selectVehicle(Vehicle vehicle) {
    selectedVehicle = vehicle;
    notifyListeners();
  }
 
  void setNote(String value) {
    note = value.trim();
  }
 
/// Returns null when the draft is ready, or the message to show.
String? validate() {
  if (selectedOptionId == null) return 'اختر نوع الخدمة';
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
      );

      // #19: nobody nearby, so nothing is saved
      if( candidates.isEmpty){
        noNearbyProviders = true;
        return 'لا يوجد مزود خدمة متاح بالقرب منك حاليًا';
      }


      final order = ServiceOrder(
        id: '',
        customerId: uid,
        customerName: customer?.fullName ?? '',
        customerPhone: customer?.phone ?? '',
        vehicleId: vehicle.id,
        vehicleTitle: vehicle.title,
        vehiclePlateArabic: vehicle.plateNumberArabic,
        vehiclePlateLatin: vehicle.plateNumberLatin,
        serviceCategoryId: categoryId,
        serviceCategoryLabel: category?.label ?? '',
        serviceOptionId: option.id,
        serviceOptionLabel: option.label,
        serviceBranch: option.branch,
        note: note,
        estimatedPrice: estimatedPrice,
        status: OrderStatus.pending,

// Locations belong to this individual order.
// Non-towing orders intentionally store no drop-off location.
pickupLocation: pickupLocation,
dropoffLocation: needsDropoff ? dropoffLocation : null,
candidateProviderIds: candidates,
      );

      createdOrderId = await _orderModel.createOrder(order);
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
 