import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/provider_location_model.dart';

/// Injectable foreground GPS boundary for distance and provider matching.
abstract class ProviderLocationSource {
  /// Takes no inputs; returns the current location or throws a readable error.
  Future<GeoPoint> current();

  /// Takes no inputs; streams subsequent positions while the screen is open.
  Stream<GeoPoint> watch();
}

/// SERVICE: obtains foreground location for distance to the vehicle.
class ProviderLocationService implements ProviderLocationSource {
  /// Takes the signed-in [providerId] and optional model; creates a GPS service.
  ProviderLocationService({
    required this.providerId,
    ProviderLocationModel? model,
  }) : _model = model ?? ProviderLocationModel();
  final String providerId;
  final ProviderLocationModel _model;

  /// Takes a device [position]; stores only currentLocation and returns its point.
  Future<GeoPoint> _save(Position position) async {
    final point = GeoPoint(position.latitude, position.longitude);
    try {
      await _model.saveCurrentLocation(providerId, point);
    } catch (_) {
      throw StateError(
        'تعذر حفظ موقعك لاستقبال الطلبات. تحقق من الاتصال والصلاحيات.',
      );
    }
    return point;
  }

  /// Takes no inputs; checks permissions and returns the current GPS point.
  @override
  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('فعّل خدمة الموقع لحساب المسافة إلى المركبة.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('فعّل إذن الموقع للتطبيق من إعدادات الجهاز.');
    }
    if (permission == LocationPermission.denied) {
      throw StateError('اسمح بالوصول إلى الموقع لحساب المسافة.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return _save(position);
  }

  /// Takes no inputs; returns GPS updates after approximately ten metres.
  @override
  Stream<GeoPoint> watch() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).asyncMap(_save);
}
