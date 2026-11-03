import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/route_model.dart';

/// CONTROLLER: the route from the provider to the customer (#45).
///
/// Gets the provider's position, keeps following it while the page is open,
/// and asks [RouteModel] for a new route when the provider has moved far
/// from where the last route started.
class RouteToCustomerController extends ChangeNotifier {
  RouteToCustomerController({
    required GeoPoint customerLocation,
    RouteModel? routeModel,
  })  : customer = LatLng(customerLocation.latitude, customerLocation.longitude),
        _routeModel = routeModel ?? RouteModel();

  /// Where the customer's vehicle is (the order's pickupLocation).
  final LatLng customer;

  final RouteModel _routeModel;

  /// The provider's live position; null until GPS answers.
  LatLng? provider;
  DrivingRoute? route;
  bool isLoading = true;
  String? error;

  StreamSubscription<Position>? _positionSub;
  LatLng? _routeStart;
  bool _routing = false;
  bool _disposed = false;

  /// A new route is requested after the provider moves this far.
  static const rerouteAfterMeters = 300.0;

  Future<void> start() async {
    isLoading = true;
    error = null;
    _notify();

    final problem = await _checkLocationPermission();
    if (problem != null) {
      error = problem;
      isLoading = false;
      _notify();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      provider = LatLng(position.latitude, position.longitude);
      await _refreshRoute();

      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25, // meters
        ),
      ).listen(_onMoved, onError: (_) {});
    } catch (e) {
      debugPrint('RouteToCustomerController: $e');
      error = 'تعذّر تحديد موقعك الحالي. تأكد من تشغيل GPS ثم حاول مرة أخرى.';
    }

    isLoading = false;
    _notify();
  }

  void _onMoved(Position position) {
    provider = LatLng(position.latitude, position.longitude);
    final start = _routeStart;
    if (start == null ||
        Geolocator.distanceBetween(start.latitude, start.longitude,
                position.latitude, position.longitude) >
            rerouteAfterMeters) {
      _refreshRoute();
    }
    _notify();
  }

  /// Also called by the «تحديث المسار» button.
  Future<void> refreshRoute() => _refreshRoute();

  Future<void> _refreshRoute() async {
    final from = provider;
    if (from == null || _routing) return;
    _routing = true;
    try {
      route = await _routeModel.getRoute(from, customer);
      _routeStart = from;
    } finally {
      _routing = false;
      _notify();
    }
  }

  /// Opens Google Maps with turn-by-turn directions to the customer, for the
  /// actual driving. Maps URLs need no API key; if the Maps app isn't
  /// installed, it opens in the browser.
  Future<bool> openNavigation() {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${customer.latitude},${customer.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Returns null when location can be used, or the Arabic message to show.
  Future<String?> _checkLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'خدمة الموقع (GPS) مغلقة. شغّلها لعرض المسار.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'يلزم السماح بالوصول إلى موقعك لعرض المسار.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'الوصول إلى الموقع مرفوض. فعّله من إعدادات الجهاز ثم حاول مرة أخرى.';
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    super.dispose();
  }
}