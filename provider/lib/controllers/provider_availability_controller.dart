import '../models/service_provider.dart';
import '../services/auth_service.dart';

class ProviderAvailabilityController {
  ProviderAvailabilityController(this.authService);

  final AuthService authService;
  final ProviderModel _model = ProviderModel();

  Future<bool> loadAvailability() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('سجّل الدخول أولاً.');
    }

    final provider = await _model.getProvider(uid);
    if (provider == null) {
      throw const AuthException('تعذر العثور على بيانات مزود الخدمة.');
    }

    return provider.isAvailable;
  }

  Future<void> updateAvailability(bool isAvailable) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('سجّل الدخول أولاً.');
    }

    await _model.updateProvider(uid, {
      'isAvailable': isAvailable,
    });
  }
}