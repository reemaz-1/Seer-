import 'package:flutter/foundation.dart';

import '../models/vehicle.dart';
import 'profile_controller.dart';

/// CONTROLLER for the vehicle pages (user stories #7–#10).
class VehicleController extends ChangeNotifier {
  VehicleController({required this.uid, VehicleModel? model})
      : _model = model ?? VehicleModel();

  final String uid;
  final VehicleModel _model;

  List<Vehicle> vehicles = [];
  bool isLoading = true;
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

  /// Adds a new vehicle (id empty) or updates an existing one.
  /// Returns null on success, or an error message to show the user.
  Future<String?> saveVehicle(Vehicle vehicle) async {
    isSaving = true;
    notifyListeners();
    try {
      final existing = await _model.getVehicles(uid);
      final duplicate = existing.any(
        (v) => v.plateNumber == vehicle.plateNumber && v.id != vehicle.id,
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

  /// Returns null on success, or an error message to show the user.
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

  // ---------- Plate helpers ----------
  // Saudi private plates: 3 letters + 1 to 4 digits.
  // Only these 17 English letters are used on Saudi plates.
  static const allowedPlateLetters = 'ABDEGHJKLNRSTUVXZ';

  static String buildPlate(String letters, String digits) =>
      '${letters.trim().toUpperCase()} ${ProfileController.normalizeDigits(digits.trim())}';

  /// "ABD 1234" -> ("ABD", "1234")
  static (String letters, String digits) splitPlate(String plate) {
    final parts = plate.trim().split(' ');
    if (parts.length < 2) return (plate.trim(), '');
    return (parts.first, parts.last);
  }

  /// Years shown in the dropdown, newest first.
  static List<int> get yearOptions {
    final last = DateTime.now().year + 1;
    return [for (var y = last; y >= 1980; y--) y];
  }

  // ---------- Validation ----------

  static String? validateBrand(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'اكتب الشركة المصنعة';
    if (v.length < 2) return 'أدخل حرفين على الأقل';
    return null;
  }

  static String? validateModel(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'اكتب طراز المركبة';
    return null;
  }

  static String? validateYear(int? value) {
    if (value == null) return 'اختر سنة الصنع';
    return null;
  }

  static String? validatePlateLetters(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'أدخل حروف اللوحة';
    if (!RegExp(r'^[A-Z]+$').hasMatch(v)) {
      return 'اكتب الحروف بالإنجليزية كما في اللوحة';
    }
    if (v.length != 3) return 'أدخل 3 حروف';
    for (final ch in v.split('')) {
      if (!allowedPlateLetters.contains(ch)) {
        return 'الحرف $ch غير مستخدم في اللوحات';
      }
    }
    return null;
  }

  static String? validatePlateDigits(String? value) {
    final v = ProfileController.normalizeDigits(value?.trim() ?? '');
    if (v.isEmpty) return 'أدخل أرقام اللوحة';
    if (!RegExp(r'^\d{1,4}$').hasMatch(v)) return 'من 1 إلى 4 أرقام';
    return null;
  }
}
