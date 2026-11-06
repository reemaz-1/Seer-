import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_model.dart';

/// Dima's route navigation UI, using the SAME real-road Stadia routing as
/// Customer. During `onTheWay` this observes the app-level #27 GPS data in
/// Firestore rather than opening a second ongoing GPS sensor subscription.
class RouteToCustomerController extends ChangeNotifier {
  RouteToCustomerController({
    required this.orderId,
    required GeoPoint customerLocation,
    RouteModel? routeModel,
    FirebaseFirestore? firestore,
  })  : customer = LatLng(
          customerLocation.latitude,
          customerLocation.longitude,
        ),
        _routeModel = routeModel ?? RouteModel(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String orderId;
  final LatLng customer;
  final RouteModel _routeModel;
  final FirebaseFirestore _firestore;

  LatLng? provider;
  DrivingRoute? route;
  DateTime? lastProviderUpdateAt;
  DateTime? lastRouteUpdatedAt;

  bool get routeEstimateOutdated {
    final current = provider;
    final start = _routeStart;
    if (route == null || current == null || start == null) return false;
    return Geolocator.distanceBetween(
          start.latitude, start.longitude,
          current.latitude, current.longitude,
        ) > 250;
  }

  bool get locationIsStale {
    final last = lastProviderUpdateAt;
    if (last == null) return true;
    final age = DateTime.now().difference(last);
    return age > const Duration(seconds: 90) ||
        age < const Duration(seconds: -10);
  }
  bool isLoading = true;
  String? error;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _trackingSub;
  Timer? _orderRetryTimer;
  Timer? _trackingRetryTimer;
  int _orderReadFailures = 0;
  int _trackingReadFailures = 0;
  bool _orderEnRoute = false;
  LatLng? _routeStart;
  DateTime? _lastRouteAttempt;
  bool _routing = false;
  bool _starting = false;
  bool _disposed = false;

  // Same route-refresh policy as Customer: no more than one every 60 seconds,
  // and only after at least 120 meters of displacement, unless manually asked.
  static const rerouteAfterMeters = 120.0;
  static const minRerouteInterval = Duration(seconds: 60);

  Future<void> start() async {
    if (_disposed || _starting) return;
    _starting = true;
    isLoading = route == null;
    error = null;
    _notify();

    try {
      final problem = await _checkLocationPermission();
      if (_disposed) return;
      if (problem != null) {
        error = problem;
        return;
      }

      // One location read to draw the initial route. The ongoing fixes are
      // already provided by ActiveOrderTrackingService when onTheWay.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (_disposed) return;
      provider = LatLng(position.latitude, position.longitude);
      lastProviderUpdateAt = position.timestamp;
      await _refreshRoute();
      if (_disposed) return;
      _listenToOrderStatus();
    } catch (e) {
      debugPrint('Provider route startup error: $e');
      error = 'تعذّر تحديد موقعك الحالي. تحقق من GPS ثم حاول مرة أخرى.';
    } finally {
      _starting = false;
      isLoading = false;
      _notify();
    }
  }

  // The route view reads the shared order-level GPS stream; it never starts
  // its own continuous GPS sensor subscription. Firestore listeners can close
  // after auth/rules errors, so recover them with bounded retry intervals.
  void _listenToOrderStatus() {
    if (_orderSub != null || _disposed) return;
    _orderRetryTimer?.cancel();
    _orderRetryTimer = null;
    _orderSub = _firestore.collection('orders').doc(orderId).snapshots().listen(
      (snapshot) {
        if (_disposed) return;
        _orderReadFailures = 0;
        final status = snapshot.data()?['status'];
        _orderEnRoute = status == 'onTheWay';
        if (_orderEnRoute) {
          _listenToSharedTracking();
        } else {
          // No location access after arrival, cancellation, or loss of an
          // active order. Cancel retries too, not only the current listener.
          _trackingRetryTimer?.cancel();
          _trackingRetryTimer = null;
          final previous = _trackingSub;
          _trackingSub = null;
          unawaited(previous?.cancel());
        }
      },
      onError: (Object e) {
        if (_disposed) return;
        debugPrint('Provider route order stream error: $e');
        _orderSub = null;
        _orderEnRoute = false;
        _trackingRetryTimer?.cancel();
        _trackingRetryTimer = null;
        final previous = _trackingSub;
        _trackingSub = null;
        unawaited(previous?.cancel());
        _scheduleOrderRetry();
      },
      cancelOnError: true,
    );
  }

  void _scheduleOrderRetry() {
    if (_disposed || (_orderRetryTimer?.isActive ?? false)) return;
    _orderReadFailures++;
    final shift = (_orderReadFailures - 1).clamp(0, 5).toInt();
    final seconds = (1 << shift).clamp(2, 60).toInt();
    _orderRetryTimer = Timer(Duration(seconds: seconds), () {
      _orderRetryTimer = null;
      _listenToOrderStatus();
    });
  }

  void _listenToSharedTracking() {
    if (_trackingSub != null || !_orderEnRoute || _disposed) return;
    _trackingRetryTimer?.cancel();
    _trackingRetryTimer = null;
    _trackingSub = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .doc('current')
        .snapshots()
        .listen(
      (snapshot) {
        if (_disposed || !_orderEnRoute) return;
        _trackingReadFailures = 0;
        final data = snapshot.data();
        final location = data?['location'];
        final updatedAt = data?['updatedAt'];
        if (location is! GeoPoint || updatedAt is! Timestamp) return;
        // Never replace the marker with an old cached GPS position.
        final age = DateTime.now().difference(updatedAt.toDate());
        if (age > const Duration(seconds: 90) ||
            age < const Duration(seconds: -10)) {
          return;
        }
        final next = LatLng(location.latitude, location.longitude);
        final changed = provider?.latitude != next.latitude ||
            provider?.longitude != next.longitude;
        provider = next;
        lastProviderUpdateAt = updatedAt.toDate();
        if (changed) _refreshRouteIfNeeded();
        _notify();
      },
      onError: (Object e) {
        if (_disposed) return;
        // Rules deny this document outside onTheWay; the order watcher
        // determines whether retries are still valid.
        debugPrint('Provider shared tracking stream error: $e');
        _trackingSub = null;
        _scheduleTrackingRetry();
      },
      cancelOnError: true,
    );
  }

  void _scheduleTrackingRetry() {
    if (_disposed ||
        !_orderEnRoute ||
        (_trackingRetryTimer?.isActive ?? false)) {
      return;
    }
    _trackingReadFailures++;
    final shift = (_trackingReadFailures - 1).clamp(0, 5).toInt();
    final seconds = (1 << shift).clamp(2, 60).toInt();
    _trackingRetryTimer = Timer(Duration(seconds: seconds), () {
      _trackingRetryTimer = null;
      _listenToSharedTracking();
    });
  }

  /// Recheck whether the route needs refreshing when GPS stops moving.
  /// This respects the same 60-second and 120-meter Stadia limits.
  void refreshEstimateIfNeeded() {
    if (!_disposed && !locationIsStale) _refreshRouteIfNeeded();
  }

  void _refreshRouteIfNeeded() {
    final from = provider;
    if (_disposed ||
        from == null ||
        _routing ||
        !_routeModel.hasRoutingKey ||
        locationIsStale) {
      return;
    }
    final since = _lastRouteAttempt == null
        ? null
        : DateTime.now().difference(_lastRouteAttempt!);
    final moved = _routeStart == null
        ? null
        : Geolocator.distanceBetween(
            _routeStart!.latitude,
            _routeStart!.longitude,
            from.latitude,
            from.longitude,
          );
    if (since != null && since < minRerouteInterval) return;
    if (route != null && moved != null && moved < rerouteAfterMeters) return;
    unawaited(_refreshRoute());
  }

  /// Re-reads GPS and asks Stadia for the current driving route.
  Future<void> refreshRoute() => start();

  Future<void> _refreshRoute() async {
    final from = provider;
    if (_disposed || from == null || _routing) return;
    _routing = true;
    _lastRouteAttempt = DateTime.now();
    _routeStart = from;
    try {
      final result = await _routeModel.getRoute(from, customer);
      if (_disposed) return;
      route = result;
      lastRouteUpdatedAt = DateTime.now();
      error = null;
    } catch (e) {
      if (_disposed) return;
      debugPrint('Provider Stadia route error: $e');
      route = null;
      error = _routeModel.hasRoutingKey
          ? 'تعذّر حساب المسار على الطرق الآن. حاول مرة أخرى.'
          : 'مفتاح Stadia Maps غير متوفر. تعذّر حساب المسار.';
    } finally {
      _routing = false;
      _notify();
    }
  }

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
      return 'الوصول إلى الموقع مرفوض. فعّله من إعدادات الجهاز.';
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _orderRetryTimer?.cancel();
    _trackingRetryTimer?.cancel();
    unawaited(_trackingSub?.cancel());
    unawaited(_orderSub?.cancel());
    super.dispose();
  }
}
