import 'dart:ui' show Locale;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

/// MODEL: turns saved coordinates into a readable address.
class AddressModel {
  static const _locale = Locale('ar', 'SA');
  static const _separator = '، ';

  late final Geocoding _geocoding = Geocoding(locale: _locale);

  /// Looks up the address of a point using the device geocoder.
  ///
  /// Parameters: [point] is the saved location.
  /// Returns: the full address line, or the district and city when the
  /// full line is missing, or null when no address is found.
  Future<String?> addressOf(GeoPoint point) async {
    final places = await _geocoding.placemarkFromCoordinates(
      point.latitude,
      point.longitude,
    );
    if (places.isEmpty) return null;

    final place = places.first;
    final fullLine = place.street?.trim() ?? '';
    if (fullLine.isNotEmpty) return fullLine;

    final parts = [place.subLocality, place.locality]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(_separator);
  }
}
