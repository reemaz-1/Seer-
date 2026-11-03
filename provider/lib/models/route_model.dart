import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';

/// A route from the provider to the customer, ready to draw on the map.
class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.isRoadRoute,
  });

  /// The line drawn on the map.
  final List<LatLng> points;

  final double distanceMeters;

  /// true = follows the roads (OpenRouteService).
  /// false = a straight line, used when the routing service is unavailable;
  /// the page then says the distance is approximate.
  final bool isRoadRoute;

  double get distanceKm => distanceMeters / 1000;
}

/// MODEL: gets the route between two points (#45).
///
/// Uses OpenRouteService, which is free with a key (Google's routing API is
/// not used by the team). The key is NOT written in the code, because the
/// repo is public; it is passed when running the app:
///
///   flutter run --dart-define=ORS_API_KEY=your_key_here
///
/// Without a key, or if the service fails, it falls back to a straight line
/// so the page still works.
class RouteModel {
  RouteModel({String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('ORS_API_KEY');

  final String _apiKey;

  bool get hasRoutingKey => _apiKey.isNotEmpty;

  Future<DrivingRoute> getRoute(LatLng from, LatLng to) async {
    if (hasRoutingKey) {
      final ors = OpenRouteService(apiKey: _apiKey);
      try {
        final coords = await ors.directionsRouteCoordsGet(
          startCoordinate:
              ORSCoordinate(latitude: from.latitude, longitude: from.longitude),
          endCoordinate:
              ORSCoordinate(latitude: to.latitude, longitude: to.longitude),
          profileOverride: ORSProfile.drivingCar,
        );
        if (coords.length >= 2) {
          final points = [
            for (final c in coords) LatLng(c.latitude, c.longitude),
          ];
          return DrivingRoute(
            points: points,
            distanceMeters: _lengthOf(points),
            isRoadRoute: true,
          );
        }
      } catch (_) {
        // Fall through to the straight line below.
      } finally {
        ors.close();
      }
    }

    return DrivingRoute(
      points: [from, to],
      distanceMeters: Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      ),
      isRoadRoute: false,
    );
  }

  /// Length of a line made of several points, in meters.
  static double _lengthOf(List<LatLng> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }
}