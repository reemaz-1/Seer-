import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/route_to_customer_controller.dart';
import '../theme/app_colors.dart';

/// VIEW: the route from the provider to the customer (#45).
///
/// Uses flutter_map with Stadia Maps tiles, the same map the customer app's
/// location picker uses, so no Google Maps key is needed. The tiles key is
/// passed when running the app:
///
///   flutter run --dart-define=STADIA_API_KEY=your_key_here
///
/// Without that key the page falls back to the standard OpenStreetMap tiles,
/// which is fine for testing.
class RouteToCustomerPage extends StatefulWidget {
  const RouteToCustomerPage({
    super.key,
    required this.customerLocation,
    required this.customerName,
  });

  /// The order's pickupLocation.
  final GeoPoint customerLocation;
  final String customerName;

  @override
  State<RouteToCustomerPage> createState() => _RouteToCustomerPageState();
}

class _RouteToCustomerPageState extends State<RouteToCustomerPage> {
  static const String _stadiaKey = String.fromEnvironment('STADIA_API_KEY');

  late final RouteToCustomerController _controller =
      RouteToCustomerController(customerLocation: widget.customerLocation);
  final MapController _mapController = MapController();

  bool _mapReady = false;

  /// The map zooms to show both points once, when the first route arrives,
  /// and again only when the refresh button is pressed, so it does not jump
  /// around while the provider is driving.
  bool _fittedOnce = false;

  String get _tileUrl => _stadiaKey.isNotEmpty
      ? 'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=$_stadiaKey'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  String get _attribution => _stadiaKey.isNotEmpty
      ? '© Stadia Maps, © OpenStreetMap contributors'
      : '© OpenStreetMap contributors';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.start();
  }

  @override
  void dispose() {
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

  Future<void> _refresh() async {
    // Reads the GPS again, then rebuilds the route from the new position.
    await _controller.start();
    if (mounted) _fitBothPoints();
  }

  Future<void> _startNavigation() async {
    var opened = false;
    try {
      opened = await _controller.openNavigation();
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح تطبيق الخرائط.')),
      );
    }
  }

  String get _distanceText {
    final route = _controller.route;
    if (route == null) return 'جارٍ حساب المسار...';
    final km = route.distanceKm.toStringAsFixed(1);
    return route.isRoadRoute
        ? 'المسافة بالطريق: $km كم'
        : 'المسافة التقريبية (خط مستقيم): $km كم';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المسار إلى العميل'),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
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
              Polyline(
                points: route.points,
                strokeWidth: 5,
                color: AppColors.blue,
                // Dashed when it is only a straight line.
                pattern: route.isRoadRoute
                    ? const StrokePattern.solid()
                    : StrokePattern.dashed(segments: const [12, 8]),
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
                    color: AppColors.blue,
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _startNavigation,
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('ابدأ الملاحة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 64,
                  child: Tooltip(
                    message: 'تحديث المسار',
                    child: OutlinedButton(
                      onPressed: _refresh,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Icon(Icons.alt_route),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}