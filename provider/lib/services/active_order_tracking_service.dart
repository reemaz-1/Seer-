import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order.dart';

/// Shares the assigned provider's location only while the order is onTheWay.
///
/// The owner is ServiceProviderMain, not the current-order tab. On Android,
/// the native location stream uses a foreground service with a visible notice
/// so an already-running trip can continue when SEER is backgrounded or locked.
/// Android/OS restrictions still apply; force-stop is not supported.
class ActiveOrderTrackingService {
  ActiveOrderTrackingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (_activeOrderId != null && user?.uid != _activeProviderUid) {
        unawaited(syncOrder(null));
      }
    });
  }

  static const Duration _minWriteInterval = Duration(seconds: 20);
  static const Duration _retryDelay = Duration(seconds: 30);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<Position>? _subscription;
  Future<void>? _startingFuture;
  Timer? _retryTimer;
  Timer? _gpsWatchdog;
  DateTime? _lastGpsEventAt;
  String? _activeOrderId;
  String? _activeProviderUid;
  DateTime? _lastQueuedAt;
  Position? _pendingPosition;
  bool _writing = false;
  bool _disposed = false;
  bool _appForeground = true;
  int _generation = 0;

  bool _isCurrent(String orderId, int generation) =>
      !_disposed && _activeOrderId == orderId && _generation == generation;

  /// Starts or stops location sharing as active order/status changes.
  /// Can be called repeatedly from Firestore snapshots without duplicate GPS.
  Future<void> syncOrder(ServiceOrder? order) async {
    if (_disposed) return;
    final uid = _auth.currentUser?.uid;
    final nextId = order != null &&
            uid != null &&
            order.providerId == uid &&
            order.status == OrderStatus.onTheWay
        ? order.id
        : null;

    if (_activeOrderId != nextId) {
      _generation++;
      _activeOrderId = nextId;
      _activeProviderUid = nextId == null ? null : uid;
      _lastQueuedAt = null;
      _pendingPosition = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _gpsWatchdog?.cancel();
      _gpsWatchdog = null;
      _lastGpsEventAt = null;
      final old = _subscription;
      _subscription = null;
      if (old != null) await old.cancel();
    }

    if (nextId == null || _disposed || !_appForeground) return;
    await _startIfNeeded(nextId, _generation);
  }

  /// Do not start a NEW location foreground service while Android is in the
  /// background. An already-running native service continues undisturbed.
  void setAppForeground(bool foreground) {
    if (_disposed) return;
    _appForeground = foreground;
    if (foreground) {
      final id = _activeOrderId;
      if (id != null) {
        unawaited(_startIfNeeded(id, _generation));
      }
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  Future<void> _startIfNeeded(String orderId, int generation) async {
    if (!_isCurrent(orderId, generation) ||
        !_appForeground ||
        _subscription != null) {
      return;
    }

    final previousStart = _startingFuture;
    if (previousStart != null) {
      await previousStart;
      if (!_isCurrent(orderId, generation) ||
          !_appForeground ||
          _subscription != null) {
        return;
      }
    }

    final start = _tryStart(orderId, generation);
    _startingFuture = start;
    try {
      await start;
    } finally {
      if (identical(_startingFuture, start)) _startingFuture = null;
    }
  }

  Future<void> _tryStart(String orderId, int generation) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('Tracking: device location is disabled.');
        _scheduleRetry(orderId, generation);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!_isCurrent(orderId, generation) || !_appForeground) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!_isCurrent(orderId, generation) || !_appForeground) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Tracking: location permission is not granted.');
        // Do not repeatedly prompt the user; retry on the next app resume.
        return;
      }

      // distanceFilter=0 allows fresh positions while the provider is stopped.
      // Android controls actual delivery cadence; 20s is a request, not an SLA.
      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: 20),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'سير - مشاركة الموقع',
          notificationText: 'يتم مشاركة موقعك مع عميل الطلب أثناء التوجه إليه',
          notificationChannelName: 'تتبع الطلب النشط',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      if (!_isCurrent(orderId, generation) || !_appForeground) return;
      _lastGpsEventAt = DateTime.now();
      _subscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) => _queueLocation(orderId, generation, position),
        onError: (Object error) {
          debugPrint('Tracking GPS stream error: $error');
          _restartAfterStreamEnd(orderId, generation);
        },
        onDone: () => _restartAfterStreamEnd(orderId, generation),
        cancelOnError: true,
      );
      // Detect a silently stalled GPS stream while the app is in foreground.
      // Do not start a new Android location foreground service from the
      // background; on resume the existing recovery code will restart it.
      _gpsWatchdog?.cancel();
      _gpsWatchdog = Timer.periodic(const Duration(seconds: 45), (_) {
        if (!_isCurrent(orderId, generation) ||
            !_appForeground ||
            _subscription == null) {
          return;
        }
        final last = _lastGpsEventAt;
        if (last != null &&
            DateTime.now().difference(last) > const Duration(minutes: 2)) {
          debugPrint('Tracking: GPS fixes stalled; reconnecting stream.');
          _restartAfterStreamEnd(orderId, generation);
        }
      });

      // The stream may take a moment to report its first position.
      try {
        final initial = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        _queueLocation(orderId, generation, initial);
      } catch (error) {
        debugPrint('Tracking: first GPS fix unavailable: $error');
        // The already-active stream can still deliver positions.
      }
    } catch (error) {
      debugPrint('Tracking could not start: $error');
      _scheduleRetry(orderId, generation);
    }
  }

  void _restartAfterStreamEnd(String orderId, int generation) {
    if (!_isCurrent(orderId, generation)) return;
    final old = _subscription;
    _subscription = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    if (old != null) unawaited(old.cancel());
    _scheduleRetry(orderId, generation);
  }

  void _scheduleRetry(String orderId, int generation) {
    if (!_isCurrent(orderId, generation) || !_appForeground) return;
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      if (_isCurrent(orderId, generation) && _appForeground) {
        unawaited(_startIfNeeded(orderId, generation));
      }
    });
  }

  void _queueLocation(String orderId, int generation, Position position) {
    if (!_isCurrent(orderId, generation)) return;
    final now = DateTime.now();
    // Do not publish old cached fixes as if they were current live positions.
    final age = now.difference(position.timestamp);
    if (age > const Duration(seconds: 60) ||
        age < const Duration(seconds: -10)) {
      return;
    }
    _lastGpsEventAt = now;
    if (_lastQueuedAt != null &&
        now.difference(_lastQueuedAt!) < _minWriteInterval) {
      return;
    }
    _lastQueuedAt = now;
    // Coalesce pending updates instead of building an unbounded offline queue.
    _pendingPosition = position;
    if (!_writing) unawaited(_flushLatest(orderId, generation));
  }

  Future<void> _flushLatest(String orderId, int generation) async {
    if (_writing) return;
    _writing = true;
    try {
      while (_isCurrent(orderId, generation) && _pendingPosition != null) {
        final position = _pendingPosition!;
        _pendingPosition = null;
        try {
          await _firestore
              .collection('orders')
              .doc(orderId)
              .collection('tracking')
              .doc('current')
              .set({
            'location': GeoPoint(position.latitude, position.longitude),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (error) {
          // The rules may reject writes after arrival or cancellation.
          debugPrint('Tracking Firestore write failed: $error');
        }
      }
    } finally {
      _writing = false;
      // An order change can occur while an old write is in flight. Continue
      // only with the latest position for the NEW active order.
      final current = _activeOrderId;
      if (!_disposed && current != null && _pendingPosition != null) {
        unawaited(_flushLatest(current, _generation));
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _activeOrderId = null;
    _activeProviderUid = null;
    _pendingPosition = null;
    unawaited(_authSubscription.cancel());
    _retryTimer?.cancel();
    _retryTimer = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    final old = _subscription;
    _subscription = null;
    if (old != null) unawaited(old.cancel());
  }
}
