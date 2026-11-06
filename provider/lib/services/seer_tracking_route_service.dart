import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Optional road routing for the customer's live-tracking view.
///
/// This file is isolated from provider tracking and Firestore (#27). A Stadia
/// Maps key is required. The API returns a real road shape, distance and ETA;
/// the UI never invents a straight-line route or estimated arrival time.
class SeerTrackingRoute {
  const SeerTrackingRoute({
    required this.points,
    required this.distanceKm,
    required this.travelSeconds,
    required this.geometryDistanceKm,
  });

  final List<LatLng> points;
  final double distanceKm;
  final double travelSeconds;

  /// Sum of distances between decoded polyline vertices, for diagnostics.
  /// Kept separate from the authoritative server-provided route distance.
  final double geometryDistanceKm;
}

class SeerTrackingRouteService {
  const SeerTrackingRouteService();

  /// Experimental only: favor shorter distance in Stadia/Valhalla.
  ///
  /// Default is false, preserving the original routing behavior. Enable only
  /// for local route review with --dart-define=SEER_PREFER_SHORTER_ROUTE=true.
  /// Verify legal road access and the arrival side before adopting this choice.
  static const bool _preferShorterRoute = bool.fromEnvironment(
    'SEER_PREFER_SHORTER_ROUTE',
    defaultValue: false,
  );

  Future<SeerTrackingRoute> getDrivingRoute({
    required LatLng provider,
    required LatLng pickup,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('A Stadia Maps API key is required for routing.');
    }

    final uri = Uri.https(
      'api.stadiamaps.com',
      '/route/v1',
      {'api_key': apiKey},
    );

    final body = jsonEncode({
      'locations': [
        {'lat': provider.latitude, 'lon': provider.longitude, 'type': 'break'},
        {'lat': pickup.latitude, 'lon': pickup.longitude, 'type': 'break'},
      ],
      'costing': 'auto',
      'units': 'kilometers',
      if (_preferShorterRoute)
        'costing_options': {
          'auto': {'use_distance': 1.0},
        },
    });

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw StateError('Stadia routing HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected routing response.');
    }

    final trip = decoded['trip'];
    if (trip is! Map<String, dynamic>) {
      throw const FormatException('Routing trip is missing.');
    }

    final summary = trip['summary'];
    final legs = trip['legs'];
    if (summary is! Map<String, dynamic> || legs is! List || legs.isEmpty) {
      throw const FormatException('Routing summary or legs are missing.');
    }

    final distance = summary['length'];
    final travelTime = summary['time'];
    if (distance is! num ||
        travelTime is! num ||
        distance < 0 ||
        travelTime < 0) {
      throw const FormatException('Invalid route distance or time.');
    }

    final points = <LatLng>[];
    for (final leg in legs) {
      if (leg is! Map<String, dynamic> || leg['shape'] is! String) {
        throw const FormatException('Invalid road geometry.');
      }

      final decodedPoints = decodeValhallaPolyline6(leg['shape'] as String);
      if (decodedPoints.isEmpty) continue;

      if (points.isNotEmpty && points.last == decodedPoints.first) {
        points.addAll(decodedPoints.skip(1));
      } else {
        points.addAll(decodedPoints);
      }
    }

    if (points.length < 2) {
      throw const FormatException('Road geometry is empty.');
    }

    // Independent length calculation helps diagnose overly-simplified or
    // malformed geometry, without replacing Stadia's driving distance.
    final geoDistance = const Distance();
    var lengthMeters = 0.0;
    for (var i = 1; i < points.length; i++) {
      lengthMeters += geoDistance.as(
        LengthUnit.Meter,
        points[i - 1],
        points[i],
      );
    }

    return SeerTrackingRoute(
      points: List.unmodifiable(points),
      distanceKm: distance.toDouble(),
      travelSeconds: travelTime.toDouble(),
      geometryDistanceKm: lengthMeters / 1000,
    );
  }
}

/// Valhalla uses an encoded polyline with SIX decimal places (not Google's 5).
List<LatLng> decodeValhallaPolyline6(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int nextDelta() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (index >= encoded.length || shift > 35) {
        throw const FormatException('Malformed Valhalla polyline.');
      }

      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) {
        throw const FormatException('Invalid Valhalla polyline character.');
      }

      result |= (value & 0x1f) << shift;
      if (value < 0x20) break;
      shift += 5;
    }

    return result.isOdd ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    latitude += nextDelta();
    longitude += nextDelta();
    final lat = latitude / 1000000.0;
    final lon = longitude / 1000000.0;

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      throw const FormatException('Decoded route has invalid coordinates.');
    }

    points.add(LatLng(lat, lon));
  }

  return points;
}
