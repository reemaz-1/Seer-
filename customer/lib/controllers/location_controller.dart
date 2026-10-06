import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Handles the customer's location logic for service requests.
///
/// This controller is independent of the map provider.
/// Google Maps or OpenStreetMap can be connected to these coordinates later.
class LocationController extends ChangeNotifier {
  GeoPoint? _pickupLocation;
  GeoPoint? _dropoffLocation;

  bool _isLoading = false;
  String? _errorMessage;

  GeoPoint? get pickupLocation => _pickupLocation;
  GeoPoint? get dropoffLocation => _dropoffLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Gets the device's current GPS location and uses it as the
  /// vehicle's pickup location.
  Future<bool> getCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // The phone's location service must be enabled before requesting GPS.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _errorMessage = 'Please enable location services.';
        return false;
      }

      // Check whether the app already has permission to access location.
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permission was denied.';
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage =
            'Location permission is permanently denied. Please enable it in settings.';
        return false;
      }

      final position = await Geolocator.getCurrentPosition();

      _pickupLocation = GeoPoint(
        position.latitude,
        position.longitude,
      );

      // Temporary debugging output so we can verify GPS works
      // before connecting Google Maps or OpenStreetMap.
      debugPrint(
        'Pickup location: ${position.latitude}, ${position.longitude}',
      );

      return true;
    } catch (e) {
      _errorMessage = 'Unable to get the current location.';
      debugPrint('Location error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the towing destination selected by the customer.
  ///
  /// TODO(#16): The latitude and longitude will later come from the
  /// map when the customer selects a towing drop-off location.
  void setDropoffLocation(double latitude, double longitude) {
    _dropoffLocation = GeoPoint(latitude, longitude);

    debugPrint('Drop-off location: $latitude, $longitude');

    notifyListeners();
  }

  /// Clears the towing destination when it is no longer needed.
  void clearDropoffLocation() {
    _dropoffLocation = null;
    notifyListeners();
  }
}