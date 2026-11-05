import 'package:latlong2/latlong.dart';

import '../services/seer_tracking_route_service.dart';

/// Provider-facing adapter around the SAME Stadia / Valhalla route service
/// used by Customer. No straight-line fallback is labeled as a driving route.
class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.travelSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double travelSeconds;

  double get distanceKm => distanceMeters / 1000;
  bool get isRoadRoute => true;
}

class RouteModel {
  RouteModel({SeerTrackingRouteService? service, String? apiKey})
      : _service = service ?? const SeerTrackingRouteService(),
        _apiKey = apiKey ?? _configuredKey;

  // Same configuration keys as Customer. No key is checked into the repo.
  static const String _stadiaKey = String.fromEnvironment('STADIA_API_KEY');
  static const String _legacyKey =
      String.fromEnvironment('STADIA_MAPS_API_KEY');
  static String get _configuredKey =>
      _stadiaKey.isNotEmpty ? _stadiaKey : _legacyKey;

  final SeerTrackingRouteService _service;
  final String _apiKey;

  bool get hasRoutingKey => _apiKey.isNotEmpty;

  Future<DrivingRoute> getRoute(LatLng from, LatLng to) async {
    final result = await _service.getDrivingRoute(
      provider: from,
      pickup: to,
      apiKey: _apiKey,
    );
    return DrivingRoute(
      points: result.points,
      distanceMeters: result.distanceKm * 1000,
      travelSeconds: result.travelSeconds,
    );
  }
}
