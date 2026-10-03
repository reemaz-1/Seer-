import 'package:flutter/foundation.dart';
 
import '../models/customer.dart';
import '../models/order.dart';
import '../models/pricing_model.dart';
import '../models/service_catalog.dart';
import '../models/vehicle.dart';
 
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
 
  List<Vehicle> vehicles = [];
  bool isLoadingVehicles = true;
  bool isSubmitting = false;
  String? vehiclesError;
 
  ServicePrices prices = ServicePrices.fallback();
 
  /// Read so the order can carry the customer's name and phone, which is what
  /// the provider app shows and calls (Shams #37, Dana #43).
  Customer? customer;
 
  String? selectedOptionId;
  Vehicle? selectedVehicle;
  String note = '';
 
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
    notifyListeners();
    try {
      final vehicle = selectedVehicle!;
      final option = selectedOption!;
 
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
        // TODO(#15, #16): pass the chosen locations once those stories exist.
        pickupLocation: null,
        dropoffLocation: null,
      );
 
      await _orderModel.createOrder(order);
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
 
