import 'package:latlong2/latlong.dart';

/// A nearby available provider shown as an approximate map marker (#78).
/// The public-facing marker intentionally contains no name, phone or plate.
class NearbyProvider {
  const NearbyProvider({
    required this.id,
    required this.mapPoint,
    required this.distanceKm,
    required this.displayName,
    this.rating,
    required this.ratingCount,
  });

  final String id;
  final LatLng mapPoint;
  final double distanceKm;
  final String displayName;
  final double? rating; // null means no verified rating yet
  final int ratingCount;
}
