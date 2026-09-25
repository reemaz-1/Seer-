import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/customer.dart';
import '../models/vehicle.dart';
 
/// CONTROLLER: sits between the profile screens (views) and the models.
/// Views call its methods and rebuild when it calls notifyListeners().
class ProfileController extends ChangeNotifier {
  ProfileController({CustomerModel? customerModel, VehicleModel? vehicleModel})
      : _customerModel = customerModel ?? CustomerModel(),
        _vehicleModel = vehicleModel ?? VehicleModel();
 
  final CustomerModel _customerModel;
  final VehicleModel _vehicleModel;
 
  Customer? customer;
  List<Vehicle> vehicles = [];
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
 
  Future<void> load(String uid) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      customer = await _customerModel.getCustomer(uid);
      vehicles = await _vehicleModel.getVehicles(uid);
    } catch (e) {
      errorMessage = 'تعذّر تحميل بيانات الحساب. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
 
  /// Reloads only the vehicles card (after the vehicle pages change something).
  Future<void> refreshVehicles(String uid) async {
    try {
      vehicles = await _vehicleModel.getVehicles(uid);
      notifyListeners();
    } catch (e) {
      // Keep showing the old list if the refresh fails.
    }
  }
 
  /// Returns null on success, or an error message to show the user.
  Future<String?> saveProfile(Customer updated) async {
    isSaving = true;
    notifyListeners();
    try {
      await _customerModel.updateCustomer(updated);
      customer = updated;
      return null;
    } catch (e) {
      return 'لم يتم حفظ التعديلات. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
 
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
 
  // ---------- Validation (kept here so the views stay simple) ----------
 
  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'هذا الحقل مطلوب';
    if (v.length < 2) return 'أدخل حرفين على الأقل';
    return null;
  }
 
  static String? validatePhone(String? value) {
    final v = normalizeDigits(value?.trim() ?? '');
    if (v.isEmpty) return 'رقم الجوال مطلوب';
    if (!RegExp(r'^05\d{8}$').hasMatch(v)) {
      return 'أدخل رقم جوال من 10 أرقام يبدأ بـ 05';
    }
    return null;
  }
 
  /// Converts Arabic-Indic digits (٠١٢…) to 012… so Arabic keyboards work.
  static String normalizeDigits(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      final index = arabicDigits.indexOf(ch);
      buffer.write(index == -1 ? ch : index.toString());
    }
    return buffer.toString();
  }
}
 