import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/seer_tracking_route_service.dart';
import '../theme/app_colors.dart';

/// Customer tracking for an assigned provider during `onTheWay` (#27).
///
/// Keeps the existing Firestore path unchanged:
/// orders/{orderId}/tracking/current {location: GeoPoint, updatedAt: Timestamp}
/// An optional Stadia Maps API key enables road shape, driving distance and ETA.
class CustomerOrderTrackingMap extends StatefulWidget {
  const CustomerOrderTrackingMap({
    super.key,
    required this.orderId,
    required this.pickupLocation,
    this.fullScreen = false,
    this.initialProvider,
    this.initialUpdatedAt,
    this.initialRoute,
    this.initialRouteOrigin,
  });

  final String orderId;
  final GeoPoint pickupLocation;
  final bool fullScreen;

  /// Optional shared snapshot when the existing map opens full screen.
  /// Avoids a second immediate Stadia request and a blank first frame.
  final LatLng? initialProvider;
  final DateTime? initialUpdatedAt;
  final SeerTrackingRoute? initialRoute;
  final LatLng? initialRouteOrigin;

  @override
  State<CustomerOrderTrackingMap> createState() =>
      _CustomerOrderTrackingMapState();
}

class _CustomerOrderTrackingMapState extends State<CustomerOrderTrackingMap> {
  static const Color _navy = CustomerColors.primaryText;
  static const Color _teal = CustomerColors.accent;
  static const Color _blue = CustomerColors.accent;
  static const Color _muted = CustomerColors.secondaryText;
  static const Color _pickupColor = Color(0xFFF06763);

  static const bool _preciseRoute =
      bool.fromEnvironment('SEER_PRECISE_ROUTE', defaultValue: false);
  static const String _stadiaKey = String.fromEnvironment('STADIA_API_KEY');
  static const String _legacyKey =
      String.fromEnvironment('STADIA_MAPS_API_KEY');
  static String get _key => _stadiaKey.isNotEmpty ? _stadiaKey : _legacyKey;

  final MapController _controller = MapController();
  final SeerTrackingRouteService _routing = const SeerTrackingRouteService();
  final Distance _distance = const Distance();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _freshnessTimer;
  Timer? _trackingRetryTimer;
  int _trackingListenerGeneration = 0;
  int _trackingFailures = 0;
  bool _trackingConnectionError = false;
  LatLng? _provider;
  DateTime? _updatedAt;
  SeerTrackingRoute? _route;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteAttempt;
  LatLng? _lastFitProvider;
  bool _routingInProgress = false;
  bool _mapReady = false;
  bool _following = true;
  bool _fitQueued = false;
  bool _suspendedForFullScreen = false;
  int _routeGeneration = 0;
  double _directionRadians = 0;

  LatLng get _pickup => LatLng(
        widget.pickupLocation.latitude,
        widget.pickupLocation.longitude,
      );

  // GPS age changes even if Firestore emits no more events.
  bool get _stale {
    final updatedAt = _updatedAt;
    if (updatedAt == null) return true;
    final age = DateTime.now().difference(updatedAt);
    return age > const Duration(seconds: 90) ||
        age < const Duration(seconds: -10);
  }

  // Routing is intentionally throttled to avoid excess Stadia requests.
  // When the provider has moved far beyond the route's starting point, do
  // not present its old distance/ETA as a fresh estimate.
  bool get _routeOriginOutdated {
    final current = _provider;
    final origin = _lastRouteOrigin;
    return _route != null && current != null && origin != null &&
        _meters(origin, current) > 250;
  }

  String get _locationStatus {
    if (_trackingConnectionError) {
      return 'تعذّر الاتصال بتحديثات الموقع. يُعرض آخر موقع معروف.';
    }
    if (_routeOriginOutdated && !_stale) {
      return 'تقدير المسار يحتاج تحديثًا بعد تحرك المزود.';
    }
    if (_updatedAt == null) return 'بانتظار تحديث موقع المزود';
    final age = DateTime.now().difference(_updatedAt!);
    if (age.isNegative) return 'وقت تحديث الموقع غير موثوق حاليًا';
    if (age.inMinutes < 1) return 'موقع المزود غير محدّث حاليًا';
    return 'آخر موقع معروف منذ ${age.inMinutes} دقيقة';
  }

  String get _tiles => _key.isNotEmpty
      ? 'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=$_key'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _provider = widget.initialProvider;
    _updatedAt = widget.initialUpdatedAt;
    _route = widget.initialRoute;
    _lastRouteOrigin = widget.initialRouteOrigin ?? widget.initialProvider;
    if (_route != null) _lastRouteAttempt = DateTime.now();
    // Low-frequency UI refresh; no additional GPS or Stadia requests.
    _freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final current = _provider;
      if (current != null && !_stale) _refreshRouteIfNeeded(current);
      if (current != null || _trackingConnectionError) setState(() {});
    });
    _listen();
  }

  @override
  void didUpdateWidget(covariant CustomerOrderTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.pickupLocation != widget.pickupLocation) {
      _routeGeneration++;
      _provider = null;
      _updatedAt = null;
      _route = null;
      _lastRouteOrigin = null;
      _lastRouteAttempt = null;
      _lastFitProvider = null;
      _following = true;
      _routingInProgress = false;
      _trackingConnectionError = false;
      _listen();
    }
  }

  void _listen() {
    _trackingRetryTimer?.cancel();
    _trackingRetryTimer = null;
    final listenerGeneration = ++_trackingListenerGeneration;
    unawaited(_subscription?.cancel());
    _subscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('tracking')
        .doc('current')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || listenerGeneration != _trackingListenerGeneration) return;
        _trackingFailures = 0;
        if (_trackingConnectionError) {
          setState(() => _trackingConnectionError = false);
        }
        final data = snapshot.data();
        final position = data?['location'];
        final time = data?['updatedAt'];
        final nextProvider = position is GeoPoint
            ? LatLng(position.latitude, position.longitude)
            : null;
        final previous = _provider;
        final sameCoordinates = previous?.latitude == nextProvider?.latitude &&
            previous?.longitude == nextProvider?.longitude;
        if (sameCoordinates) {
          // Freshness metadata does not affect the marker or the visible UI.
          // Avoid rebuilding the tile layer for identical GPS coordinates.
          _updatedAt = time is Timestamp ? time.toDate() : null;
          if (nextProvider != null && !_stale) {
            _refreshRouteIfNeeded(nextProvider);
          }
          return;
        }
        var bearing = _directionRadians;
        if (previous != null && nextProvider != null &&
            _meters(previous, nextProvider) >= 5) {
          final lat1 = previous.latitude * math.pi / 180;
          final lat2 = nextProvider.latitude * math.pi / 180;
          final deltaLon =
              (nextProvider.longitude - previous.longitude) * math.pi / 180;
          final east = math.sin(deltaLon) * math.cos(lat2);
          final north = math.cos(lat1) * math.sin(lat2) -
              math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
          bearing = math.atan2(east, north);
        }
        setState(() {
          _provider = nextProvider;
          _updatedAt = time is Timestamp ? time.toDate() : null;
          _directionRadians = bearing;
        });
        _fitIfNeeded();
        if (nextProvider != null && !_stale) {
          _refreshRouteIfNeeded(nextProvider);
        }
      },
      onError: (Object error) {
        if (!mounted || listenerGeneration != _trackingListenerGeneration) return;
        debugPrint('Customer tracking listener error: $error');
        _subscription = null;
        _trackingFailures++;
        setState(() => _trackingConnectionError = true);
        final shift = (_trackingFailures - 1).clamp(0, 5).toInt();
        final delay = (1 << shift).clamp(2, 60).toInt();
        _trackingRetryTimer = Timer(Duration(seconds: delay), () {
          _trackingRetryTimer = null;
          if (mounted && listenerGeneration == _trackingListenerGeneration) {
            _listen();
          }
        });
      },
      cancelOnError: true,
    );
  }

  double _meters(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Meter, a, b);

  void _fitIfNeeded({bool force = false}) {
    if (!_mapReady || _provider == null) return;
    if (!force && !_following) return;
    if (!force && _lastFitProvider != null &&
        _meters(_lastFitProvider!, _provider!) < 150) {
      return;
    }
    if (_fitQueued) return;
    _fitQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitQueued = false;
      if (!mounted || !_mapReady || _provider == null) return;
      if (!force && !_following) return;
      _lastFitProvider = _provider;
      // Always fit the CURRENT provider and the pickup, even if the last
      // fetched road route still starts at an older provider GPS position.
      final coords = <LatLng>[_provider!, _pickup, ...?_route?.points];
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: coords,
          padding: EdgeInsets.fromLTRB(
            widget.fullScreen ? 64 : 32,
            widget.fullScreen ? 96 : 54,
            widget.fullScreen ? 64 : 32,
            widget.fullScreen ? 120 : 54,
          ),
          maxZoom: 15.5,
        ),
      );
    });
  }

  void _recenter() {
    _following = true;
    _fitIfNeeded(force: true);
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    // Manual zoom should not be overwritten by the next GPS update.
    _following = false;
    final camera = _controller.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 19.0).toDouble();
    _controller.move(camera.center, zoom);
  }

  void _refreshRouteIfNeeded(LatLng provider) {
    if (_key.isEmpty || _routingInProgress || _suspendedForFullScreen) {
      return;
    }
    final since = _lastRouteAttempt == null
        ? null
        : DateTime.now().difference(_lastRouteAttempt!);
    final moved = _lastRouteOrigin == null
        ? null
        : _meters(_lastRouteOrigin!, provider);
    if (since != null && since < const Duration(seconds: 60)) return;
    if (moved != null && moved < 120 && _route != null) return;

    _lastRouteAttempt = DateTime.now();
    _lastRouteOrigin = provider;
    _routingInProgress = true;
    final generation = ++_routeGeneration;
    _loadRoute(provider, generation);
  }

  Future<void> _loadRoute(LatLng origin, int generation) async {
    try {
      final route = await _routing.getDrivingRoute(
        provider: origin,
        pickup: _pickup,
        apiKey: _key,
      );
      if (!mounted || generation != _routeGeneration) return;
      setState(() {
        _route = route;
        _routingInProgress = false;
      });
      assert(() {
        debugPrint(
          'SEER route: API ${route.distanceKm.toStringAsFixed(2)} km, '
          'geometry ${route.geometryDistanceKm.toStringAsFixed(2)} km, '
          '${route.points.length} points',
        );
        return true;
      }());
      _fitIfNeeded(force: _following);
    } catch (error) {
      if (!mounted || generation != _routeGeneration) return;
      debugPrint('Tracking route request failed: $error');
      setState(() {
        // Keep any previous valid road route rather than flickering the line.
        _routingInProgress = false;
      });
    }
  }

  Future<void> _openFullScreen() async {
    if (widget.fullScreen || _suspendedForFullScreen) return;
    _suspendedForFullScreen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('تتبع المزود'),
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: _navy,
            ),
            body: SafeArea(
              child: CustomerOrderTrackingMap(
                orderId: widget.orderId,
                pickupLocation: widget.pickupLocation,
                fullScreen: true,
                initialProvider: _provider,
                initialUpdatedAt: _updatedAt,
                initialRoute: _route,
                initialRouteOrigin: _lastRouteOrigin,
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    _suspendedForFullScreen = false;
    final provider = _provider;
    if (provider != null && !_stale) _refreshRouteIfNeeded(provider);
  }

  @override
  void dispose() {
    _routeGeneration++;
    _freshnessTimer?.cancel();
    _trackingRetryTimer?.cancel();
    _trackingListenerGeneration++;
    unawaited(_subscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  Widget _mapView() {
    final provider = _provider;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _pickup,
            initialZoom: 13,
            backgroundColor: const Color(0xFFF2F5F6),
            // Embedded map must not steal page scroll or pinch gestures.
            // The explicit expand button opens the interactive full-screen map.
            interactionOptions: InteractionOptions(
              flags: widget.fullScreen
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onMapReady: () {
              _mapReady = true;
              _fitIfNeeded(force: true);
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _following && mounted) {
                _following = false;
              }
            },
          ),
          children: [
            // Match the Provider map's bright street style in both views.
            // Without a Stadia key, use the unfiltered OSM tiles as Provider does.
            TileLayer(
              urlTemplate: _tiles,
              userAgentPackageName: 'com.swe444.seer',
            ),
            if (_route != null)
              PolylineLayer(
                // flutter_map normally simplifies vertices for rendering speed.
                // Set --dart-define=SEER_PRECISE_ROUTE=true to inspect the exact
                // geometry from Stadia without simplification.
                simplificationTolerance: _preciseRoute ? 0 : 0.3,
                polylines: [
                  Polyline(
                    points: _route!.points,
                    color: _blue,
                    strokeWidth: 5,
                    borderStrokeWidth: 2.5,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _pickup,
                  height: 56,
                  width: 56,
                  child: Tooltip(
                    message: 'موقع مركبتك',
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: _pickupColor,
                      size: 49,
                      shadows: [
                        Shadow(color: Colors.white, blurRadius: 5),
                      ],
                    ),
                  ),
                ),
                if (provider != null)
                  Marker(
                    point: provider,
                    width: 64,
                    height: 64,
                    child: Tooltip(
                      message: 'موقع مزود الخدمة',
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _teal.withValues(alpha: 0.16),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _stale ? _muted : _teal,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33112C40),
                                blurRadius: 9,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: _directionRadians,
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                if (_key.isNotEmpty)
                  TextSourceAttribution('© Stadia Maps, © OpenStreetMap contributors')
                else
                  TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        PositionedDirectional(
          top: 12,
          end: 12,
          child: Column(
            children: [
              if (!widget.fullScreen) ...[
                _mapButton(
                  icon: Icons.open_in_full_rounded,
                  label: 'تكبير الخريطة',
                  onTap: _openFullScreen,
                ),
                const SizedBox(height: 9),
              ],
              _mapButton(
                icon: Icons.center_focus_strong_rounded,
                label: 'إظهار المزود ومركبتك',
                onTap: _recenter,
              ),
              if (widget.fullScreen) ...[
                const SizedBox(height: 12),
                _mapButton(
                  icon: Icons.add_rounded,
                  label: 'تكبير',
                  onTap: () => _zoomBy(1),
                ),
                const SizedBox(height: 7),
                _mapButton(
                  icon: Icons.remove_rounded,
                  label: 'تصغير',
                  onTap: () => _zoomBy(-1),
                ),
              ],
            ],
          ),
        ),
        if (provider != null &&
            (_stale || _trackingConnectionError || _routeOriginOutdated))
          PositionedDirectional(
            start: 10,
            bottom: 10,
            end: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_outlined,
                        color: _muted, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(_locationStatus,
                          style: const TextStyle(color: _navy, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (provider == null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'بانتظار موقع المزود...',
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        icon: Icon(icon, color: _navy, size: 22),
      ),
    );
  }

  String _etaLabel() {
    if (_route == null) return '—';
    final minutes = (_route!.travelSeconds / 60).ceil();
    if (minutes == 0) return 'أقل من دقيقة';
    return '$minutes دقيقة';
  }

  String _distanceLabel() {
    if (_route == null) return '—';
    final km = _route!.distanceKm;
    if (km < 1) return '${(km * 1000).round()} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  /// Keep the last road route for orientation, but never label estimates as
  /// live when the provider's GPS has not updated recently.
  Widget _summary() {
    if (_route == null) {
      if (_provider != null && !_stale && _key.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Text('المسافة ووقت الوصول غير متاحين حاليًا.',
              style: TextStyle(color: _muted, fontSize: 12)),
        );
      }
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              icon: Icons.schedule_rounded,
              label: 'وقت الوصول المتوقع',
              value: (_stale || _trackingConnectionError || _routeOriginOutdated)
                  ? 'غير محدّث'
                  : _etaLabel(),
            ),
          ),
          Container(width: 1, height: 44, color: CustomerColors.cardBorder),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              icon: Icons.route_rounded,
              label: 'المسافة المتبقية',
              value: (_stale || _trackingConnectionError || _routeOriginOutdated)
                  ? 'غير محدّث'
                  : _distanceLabel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _teal),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = _mapView();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: widget.fullScreen
              ? BorderRadius.zero
              : BorderRadius.circular(20),
          border: widget.fullScreen
              ? null
              : Border.all(color: const Color(0xFFE5EAF0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.fullScreen)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 13),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 9, color: Color(0xFF26B89D)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المزود في الطريق إليك',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                        ),
                      ),
                    ),
                    Icon(Icons.navigation_rounded, color: _teal),
                  ],
                ),
              ),
            if (widget.fullScreen)
              Expanded(child: map)
            else
              SizedBox(height: 265, child: map),
            _summary(),
          ],
        ),
      ),
    );
  }
}
