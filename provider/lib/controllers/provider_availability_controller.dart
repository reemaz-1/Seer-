import '../models/service_provider.dart';
import '../services/auth_service.dart';
import '../services/provider_location_service.dart';

class ProviderAvailabilityController {
  /// Takes the session and optional data/GPS dependencies; creates availability logic.
  ProviderAvailabilityController(
    this.authService, {
    ProviderModel? model,
    this.location,
  }) : _model = model ?? ProviderModel();

  final AuthService authService;
  final ProviderModel _model;
  final ProviderLocationSource? location;

  /// Takes no inputs; returns the current provider availability or an auth error.
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

  /// Takes the desired availability; saves current GPS before enabling matching.
  /// Completes after the profile update, or throws without enabling on GPS failure.
  Future<void> updateAvailability(bool isAvailable) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('سجّل الدخول أولاً.');
    }

    if (isAvailable) {
      await (location ?? ProviderLocationService(providerId: uid)).current();
    }

    await _model.updateProvider(uid, {'isAvailable': isAvailable});
  }
}
