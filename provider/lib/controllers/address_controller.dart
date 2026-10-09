import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/address_model.dart';

/// CONTROLLER: gives views the address of a location and remembers
/// results so the same point is not looked up twice.
class AddressController {
  /// Creates the controller.
  ///
  /// Parameters: [model] is optional and mainly used in tests.
  AddressController({AddressModel? model}) : _model = model ?? AddressModel();

  final AddressModel _model;
  final Map<String, Future<String?>> _cache = {};

  /// Returns the address of a point.
  ///
  /// Parameters: [point] is the saved location.
  /// Returns: a future with the address, or null when it cannot be found.
  Future<String?> addressOf(GeoPoint point) {
    final key = '${point.latitude},${point.longitude}';
    return _cache.putIfAbsent(key, () => _safeLookup(point));
  }

  /// Runs the lookup and hides lookup errors from the view.
  ///
  /// Parameters: [point] is the saved location.
  /// Returns: the address, or null when the lookup fails.
  Future<String?> _safeLookup(GeoPoint point) async {
    try {
      return await _model.addressOf(point);
    } catch (_) {
      return null;
    }
  }
}
