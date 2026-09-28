import 'package:flutter/foundation.dart';
import '../models/service_provider.dart';

class ProviderProfileController extends ChangeNotifier {
  ProviderProfileController({ProviderModel? providerModel})
      : _providerModel = providerModel ?? ProviderModel();

  final ProviderModel _providerModel;

  ServiceProviderData? provider;
  bool isLoading = true;
  String? errorMessage;

  Future<void> load(String uid) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _providerModel.getProvider(uid);
      if (result == null) {
        errorMessage = 'المستند غير موجود';
      } else {
        provider = result;
      }
    } catch (e) {
      errorMessage = 'تم قطع الاتصال، الرجاء التأكد من اتصالك بالإنترنت';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> saveUpdates(
    String uid,
    Map<String, dynamic> updates,
    ServiceProviderData updated,
  ) async {
    try {
      await _providerModel.updateProvider(uid, updates);
      provider = updated;
      notifyListeners();
      return null;
    } catch (e) {
      return 'تعذر حفظ التعديلات، تحقق من اتصالك بالإنترنت';
    }
  }
}