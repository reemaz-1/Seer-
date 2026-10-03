import 'package:flutter/foundation.dart';

import '../models/lookup_model.dart';
import '../models/vehicle.dart';

/// CONTROLLER for the vehicle pages (user stories #7-#10).
class VehicleController extends ChangeNotifier {
  VehicleController({
    required this.uid,
    VehicleModel? model,
    LookupModel? lookupModel,
  })  : _model = model ?? VehicleModel(),
        _lookupModel = lookupModel ?? LookupModel();

  final String uid;
  final VehicleModel _model;
  final LookupModel _lookupModel;

  List<Vehicle> vehicles = [];
  VehicleLookups lookups = VehicleLookups.fallback();
  bool isLoading = true;
  bool isLoadingLookups = true;
  bool isSaving = false;
  String? errorMessage;

  static const _networkError = 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      vehicles = await _model.getVehicles(uid);
    } catch (e) {
      errorMessage = 'تعذّر تحميل المركبات. $_networkError';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the shared brand, model and color lists. Never throws: if
  /// Firestore cannot be read, the built-in lists are used so the form
  /// still works.
  Future<void> loadLookups() async {
    isLoadingLookups = true;
    notifyListeners();
    try {
      lookups = await _lookupModel.getVehicleLookups();
    } catch (e) {
      lookups = VehicleLookups.fallback();
    } finally {
      isLoadingLookups = false;
      notifyListeners();
    }
  }

  // ---------- Dropdown options ----------

  /// [current] is the vehicle's saved value: it is added to the list when it
  /// is no longer in the shared one, so editing an older vehicle does not
  /// silently clear the field.
  List<String> brandOptions(String? current) => _withOther(lookups.brands, current);

  List<String> colorOptions(String? current) => _withOther(lookups.colors, current);

  /// The models of [brand], always ending with "أخرى". Empty when no brand is
  /// chosen yet, so the model dropdown stays disabled until then.
  List<String> modelOptions(String? brand) {
    if (brand == null || brand.isEmpty) return const [];
    return _withOther(lookups.models[brand] ?? const [], null);
  }

  static List<String> _withOther(List<String> options, String? current) {
    final result = [
      for (final option in options)
        if (option != kOtherOption) option,
    ];
    if (current != null &&
        current.isNotEmpty &&
        current != kOtherOption &&
        !result.contains(current)) {
      result.add(current);
    }
    return [...result, kOtherOption];
  }

  /// Next year down to 30 years back, newest first. Built from today's date,
  /// so it stays correct without anyone editing the code.
  static List<int> get yearOptions {
    final thisYear = DateTime.now().year;
    return [for (var y = thisYear + 1; y >= thisYear - 30; y--) y];
  }

  // ---------- Plate helpers ----------
  // Stored as "<digits> <letters>", the same order the provider app uses.

  static String buildPlate({required String digits, required String letters}) =>
      '${digits.trim()} ${letters.trim()}';

  /// "1234 ععه" -> ("1234", "ععه")
  static (String digits, String letters) splitPlate(String plate) {
    final parts = plate.trim().split(' ');
    if (parts.length < 2) return (parts.isEmpty ? '' : parts.first, '');
    return (parts.first, parts.last);
  }

  // ---------- Saving ----------

  /// Adds a new vehicle (empty id) or updates an existing one.
  /// Returns null on success, or a message to show the user.
  Future<String?> saveVehicle(Vehicle vehicle) async {
    isSaving = true;
    notifyListeners();
    try {
      final existing = await _model.getVehicles(uid);
      // Compared on the Latin plate, which is the same string in both apps
      // whichever script the customer typed in.
      final duplicate = existing.any(
        (v) => v.plateNumberLatin == vehicle.plateNumberLatin && v.id != vehicle.id,
      );
      if (duplicate) return 'هذه اللوحة مضافة مسبقًا في مركباتك';

      if (vehicle.id.isEmpty) {
        await _model.addVehicle(uid, vehicle);
      } else {
        await _model.updateVehicle(uid, vehicle);
      }
      return null;
    } catch (e) {
      return 'لم يتم حفظ المركبة. $_networkError';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> deleteVehicle(Vehicle vehicle) async {
    // Later: block deleting a vehicle that has an ongoing service request.
    isSaving = true;
    notifyListeners();
    try {
      await _model.deleteVehicle(uid, vehicle.id);
      return null;
    } catch (e) {
      return 'لم يتم حذف المركبة. $_networkError';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ---------- Validation ----------

  static String? validateBrand(String? value) =>
      (value == null || value.isEmpty) ? 'اختر الشركة المصنعة' : null;

  static String? validateColor(String? value) =>
      (value == null || value.isEmpty) ? 'اختر لون المركبة' : null;

  static String? validateYear(int? value) => value == null ? 'اختر سنة الصنع' : null;

  /// The model dropdown. Picking "أخرى" is valid: the typed value is then
  /// checked by [validateCustomValue].
  static String? validateModelSelection(String? value) =>
      (value == null || value.isEmpty) ? 'اختر طراز المركبة' : null;

  /// The text field shown after "أخرى" is picked, for a brand, model or color.
  static String? validateCustomValue(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'اكتب القيمة';
    if (v.length < 2) return 'أدخل حرفين على الأقل';
    return null;
  }

  /// Checked separately from the Form, because the plate is a custom widget.
  /// Saudi private plates always have 3 letters, so 3 is required here and in
  /// PlateNumberField.isValid.
  static String? validatePlate({
    required String digits,
    required String arabicLetters,
  }) {
    if (digits.isEmpty) return 'أدخل أرقام اللوحة';
    if (digits.length > 4) return 'من 1 إلى 4 أرقام';
    if (arabicLetters.isEmpty) return 'أدخل حروف اللوحة';
    if (arabicLetters.length != 3) return 'أدخل 3 حروف للوحة';
    return null;
  }
}
