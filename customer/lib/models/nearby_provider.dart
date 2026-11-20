import 'package:latlong2/latlong.dart';

/// A nearby available provider shown as an approximate map marker (#78).
/// The public-facing marker intentionally contains no name, phone or plate.
class NearbyProvider {
  const NearbyProvider({
    required this.id,
    required this.mapPoint,
    required this.distanceKm,
  });

  final String id;
  final LatLng mapPoint;
  final double distanceKm;
}
