import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/route_to_customer_controller.dart';
import '../theme/app_colors.dart';

/// VIEW: the route from the provider to the customer (#45).
///
/// Uses flutter_map with Stadia tiles and Valhalla road routing,
/// matching the Customer tracking map. Pass the Stadia key via
/// --dart-define-from-file when launching the app. Without a key, map tiles
/// fall back to OpenStreetMap, but road-route calculations require the key.
class RouteToCustomerPage extends StatefulWidget {
  const RouteToCustomerPage({
    super.key,
    required this.orderId,
    required this.customerLocation,
    required this.customerName,
  });

  final String orderId;
  /// The order's pickupLocation.
  final GeoPoint customerLocation;
  final String customerName;

  @override
  State<RouteToCustomerPage> createState() => _RouteToCustomerPageState();
}

class _RouteToCustomerPageState extends State<RouteToCustomerPage> {
  static const String _stadiaKey = String.fromEnvironment('STADIA_API_KEY');
  static const String _legacyKey =
      String.fromEnvironment('STADIA_MAPS_API_KEY');
  static String get _key => _stadiaKey.isNotEmpty ? _stadiaKey : _legacyKey;

  late final RouteToCustomerController _controller =
      RouteToCustomerController(
        orderId: widget.orderId,
        customerLocation: widget.customerLocation,
      );
  final MapController _mapController = MapController();

  bool _mapReady = false;
  Timer? _freshnessTimer;

  // Bright sky blue that contrasts visibly with Provider navy and blue.
  // A white road-edge outline keeps
  // the route readable above yellow/orange streets without altering routing.
  static const Color _routeBlue = Color(0xFF38A8FF);
  static const Color _routeOutline = Colors.white;
  static const double _minZoom = 3;
  static const double _maxZoom = 19;

  /// The map zooms to show both points once, when the first route arrives,
  /// and again only when the user chooses "Show full route", so it does not
  /// jump around while the provider is driving.
  bool _fittedOnce = false;

  String get _tileUrl => _key.isNotEmpty
      ? 'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=$_key'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  String get _attribution => _key.isNotEmpty
      ? '© Stadia Maps, © OpenStreetMap contributors'
      : '© OpenStreetMap contributors';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _controller.refreshEstimateIfNeeded();
      if (_controller.route != null) setState(() {});
    });
    _controller.start();
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_fittedOnce && _controller.route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _fittedOnce || !_mapReady) return;
        _fittedOnce = true;
        _fitBothPoints();
      });
    }
  }

  /// Zooms the map so the provider, the customer and the route all fit.
  void _fitBothPoints() {
    if (!_mapReady) return;
    final points = <LatLng>[
      _controller.customer,
      if (_controller.provider != null) _controller.provider!,
      ...?_controller.route?.points,
    ];
    if (points.length < 2) {
      _mapController.move(_controller.customer, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(60),
        maxZoom: 17,
      ),
    );
  }

  /// Manual camera controls do not trigger new route requests or GPS reads.
  /// The route remains in the same geographic position when rotating.
  void _zoomBy(double difference) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final zoom = (camera.zoom + difference)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _mapController.move(camera.center, zoom);
  }

  void _rotateClockwise() {
    if (!_mapReady) return;
    final nextAngle = (_mapController.camera.rotation + 45) % 360;
    _mapController.rotate(nextAngle);
  }

  void _northUp() {
    if (!_mapReady) return;
    _mapController.rotate(0);
  }

  void _focusOnProvider() {
    if (!_mapReady) return;
    final provider = _controller.provider;
    if (provider == null) {
      _fitBothPoints();
      return;
    }
    final zoom = _mapController.camera.zoom < 16
        ? 16.0
        : _mapController.camera.zoom;
    _mapController.move(provider, zoom);
  }

  Widget _cameraButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.navy),
        iconSize: 23,
        constraints: const BoxConstraints(minHeight: 46, minWidth: 46),
      ),
    );
  }

  /// Google-Maps-like camera controls, entirely inside the SEER app.
  Widget _cameraControls() {
    return Positioned(
      top: 14,
      right: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cameraButton(
            icon: Icons.add_rounded,
            tooltip: 'تكبير الخريطة',
            onPressed: () => _zoomBy(1),
          ),
          const SizedBox(height: 8),
          _cameraButton(
            icon: Icons.remove_rounded,
            tooltip: 'تصغير الخريطة',
            onPressed: () => _zoomBy(-1),
          ),
          const SizedBox(height: 8),
          _cameraButton(
            icon: Icons.rotate_right_rounded,
            tooltip: 'تدوير الخريطة 45 درجة',
            onPressed: _rotateClockwise,
          ),
          const SizedBox(height: 8),
          _cameraButton(
            icon: Icons.explore_outlined,
            tooltip: 'إعادة اتجاه الخريطة إلى الشمال',
            onPressed: _northUp,
          ),
          const SizedBox(height: 20),
          _cameraButton(
            icon: Icons.my_location_rounded,
            tooltip: 'التركيز على موقع المزود',
            onPressed: _focusOnProvider,
          ),
        ],
      ),
    );
  }

  String get _distanceText {
    final route = _controller.route;
    if (route != null &&
        (_controller.locationIsStale || _controller.routeEstimateOutdated)) {
      return 'المسافة المتبقية: غير محدّثة';
    }
    if (route == null) {
      return _controller.error != null
          ? 'المسافة المتبقية: —'
          : 'جارٍ حساب المسار...';
    }
    final km = route.distanceKm.toStringAsFixed(1);
    if (route.distanceKm < 1) {
      return 'المسافة المتبقية: ${route.distanceMeters.round()} م';
    }
    return 'المسافة المتبقية: $km كم';
  }

  String get _etaText {
    final route = _controller.route;
    if (route != null &&
        (_controller.locationIsStale || _controller.routeEstimateOutdated)) {
      return 'وقت الوصول المتوقع: غير محدّث';
    }
    if (route == null) return 'وقت الوصول المتوقع: —';
    final minutes = (route.travelSeconds / 60).ceil();
    return minutes == 0
        ? 'وقت الوصول المتوقع: أقل من دقيقة'
        : 'وقت الوصول المتوقع: $minutes دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('المسار إلى العميل'),
          // Match Provider's light Fleet Blue screens, not Customer's navy header.
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      _map(),
                      _cameraControls(),
                      if (_controller.isLoading && _controller.error == null)
                        const Center(child: CircularProgressIndicator()),
                      if (_controller.error != null) _errorCard(),
                    ],
                  ),
                ),
                _bottomPanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _map() {
    final route = _controller.route;
    final provider = _controller.provider;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _controller.customer,
        initialZoom: 13,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapReady: () {
          _mapReady = true;
          _onControllerChanged();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl,
          userAgentPackageName: 'com.swe444.seerprovider',
        ),
        if (route != null)
          PolylineLayer(
            polylines: [
              // Draw a white casing first, then the brighter SEER route.
              // This is one road route, not an alternate path.
              Polyline(
                points: route.points,
                strokeWidth: 12,
                color: _routeOutline,
                pattern: const StrokePattern.solid(),
              ),
              Polyline(
                points: route.points,
                strokeWidth: 7,
                color: _routeBlue,
                pattern: const StrokePattern.solid(),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // The customer's vehicle.
            Marker(
              point: _controller.customer,
              width: 48,
              height: 48,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
            ),
            // The provider (blue dot).
            if (provider != null)
              Marker(
                point: provider,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: _routeBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution(_attribution)],
        ),
      ],
    );
  }

  Widget _errorCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined,
                size: 40, color: AppColors.navy),
            const SizedBox(height: 12),
            Text(
              _controller.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _controller.start,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customerName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _distanceText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _etaText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            if ((_controller.locationIsStale ||
                    _controller.routeEstimateOutdated) &&
                _controller.route != null) ...[
              const SizedBox(height: 7),
              Text(
                _controller.locationIsStale
                    ? 'آخر موقع معروف؛ بانتظار تحديث GPS من المزود.'
                    : 'المسار تقريبي وسيُحدّث بعد تحرك المزود.',
                style: const TextStyle(fontSize: 12, color: AppColors.navy),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _mapReady ? _fitBothPoints : null,
                icon: const Icon(Icons.zoom_out_map_rounded),
                label: const Text('عرض المسار كاملًا'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}