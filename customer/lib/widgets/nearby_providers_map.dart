import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/matching_controller.dart';
import '../controllers/nearby_providers_controller.dart';
import '../theme/app_colors.dart';

/// #78: preview of eligible nearby providers before the service request is sent.
/// This is NOT #27's live tracking of an assigned provider.
class NearbyProvidersMap extends StatefulWidget {
  const NearbyProvidersMap({
    super.key,
    required this.categoryId,
    required this.optionId,
    required this.pickupLocation,
  });

  final String categoryId;
  final String optionId;
  final GeoPoint pickupLocation;

  @override
  State<NearbyProvidersMap> createState() => _NearbyProvidersMapState();
}

class _NearbyProvidersMapState extends State<NearbyProvidersMap> {
  final NearbyProvidersController _nearby = NearbyProvidersController();

  LatLng get _pickup => LatLng(widget.pickupLocation.latitude, widget.pickupLocation.longitude);

  @override
  void initState() {
    super.initState();
    _configure();
  }

  void _configure() {
    _nearby.configure(
      categoryId: widget.categoryId,
      optionId: widget.optionId,
      pickup: _pickup,
    );
  }

  @override
  void didUpdateWidget(covariant NearbyProvidersMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        oldWidget.optionId != widget.optionId ||
        oldWidget.pickupLocation != widget.pickupLocation) {
      _configure();
    }
  }

  @override
  void dispose() {
    _nearby.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: CustomerColors.background,
        appBar: AppBar(
          title: const Text('مزودو الخدمة القريبون'),
          backgroundColor: CustomerColors.darkPanel,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _nearby,
            builder: (_, __) => Column(
              children: [
                Expanded(
                  child: _NearbyMapCanvas(
                    controller: _nearby,
                    pickup: _pickup,
                    categoryId: widget.categoryId,
                    optionId: widget.optionId,
                    interactive: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _nearby.error ??
                        'المتاحون للخدمة المختارة ضمن ${MatchingController.radiusKm.toInt()} كم: '
                        '${_nearby.providers.length} • المواقع تقريبية وليست تتبعًا مباشرًا',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CustomerColors.secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _nearby,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CustomerColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'مزودو الخدمة القريبون',
                    style: TextStyle(
                      color: CustomerColors.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'ضمن ${MatchingController.radiusKm.toInt()} كم',
                  style: const TextStyle(
                    color: CustomerColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 190,
                child: _NearbyMapCanvas(
                  controller: _nearby,
                  pickup: _pickup,
                  categoryId: widget.categoryId,
                  optionId: widget.optionId,
                  interactive: false,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openFullScreen,
              icon: const Icon(Icons.open_in_full_rounded, size: 17),
              label: const Text('عرض الخريطة كاملة'),
            ),
            Text(
              'تظهر فقط المركبات المتاحة للخدمة المختارة. '
              'مواقعها تقريبية وقد تختلف عن الموقع الفعلي.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CustomerColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyMapCanvas extends StatelessWidget {
  const _NearbyMapCanvas({
    required this.controller,
    required this.pickup,
    required this.categoryId,
    required this.optionId,
    required this.interactive,
  });

  final NearbyProvidersController controller;
  final LatLng pickup;
  final String categoryId;
  final String optionId;
  final bool interactive;

  static const String _stadiaKey = String.fromEnvironment('STADIA_API_KEY');
  static const String _legacyKey = String.fromEnvironment('STADIA_MAPS_API_KEY');
  static String get _tiles {
    final key = _stadiaKey.isNotEmpty ? _stadiaKey : _legacyKey;
    return key.isEmpty
        ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
        : 'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=$key';
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: pickup,
        width: 56,
        height: 56,
        child: const Tooltip(
          message: 'موقع مركبتك',
          child: Icon(
            Icons.location_pin,
            size: 44,
            color: Color(0xFFDF625C),
            shadows: [Shadow(color: Colors.white, blurRadius: 5)],
          ),
        ),
      ),
      for (final provider in controller.providers)
        Marker(
          point: provider.mapPoint,
          width: 46,
          height: 46,
          child: Tooltip(
            message: 'مزود قريب للخدمة المختارة • موقع تقريبي',
            child: _ServiceMarker(categoryId: categoryId, optionId: optionId),
          ),
        ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          key: ValueKey('${pickup.latitude}:${pickup.longitude}:$interactive'),
          options: MapOptions(
            initialCenter: pickup,
            initialZoom: 12.5,
            backgroundColor: const Color(0xFFF4F6FA),
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(urlTemplate: _tiles, userAgentPackageName: 'com.swe444.seer'),
            MarkerLayer(markers: markers),
            RichAttributionWidget(attributions: [
              TextSourceAttribution(
                _stadiaKey.isEmpty && _legacyKey.isEmpty
                  ? '© OpenStreetMap contributors'
                  : '© Stadia Maps, © OpenStreetMap contributors',
              ),
            ]),
          ],
        ),
        if (controller.loading || controller.error != null || controller.providers.isEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 6)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.loading) ...[
                    const SizedBox(
                      width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      controller.loading
                          ? 'جارٍ البحث عن مزودين قريبين...'
                          : controller.error ?? 'لا يوجد مزودون مطابقون حاليًا',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: CustomerColors.primaryText),
                    ),
                  ),
                  if (controller.error != null)
                    IconButton(
                      tooltip: 'إعادة المحاولة',
                      onPressed: controller.retry,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The marker changes icon by service, while keeping the same SEER visual style.
class _ServiceMarker extends StatelessWidget {
  const _ServiceMarker({required this.categoryId, required this.optionId});

  final String categoryId;
  final String optionId;

  @override
  Widget build(BuildContext context) {
    final symbol = switch (categoryId) {
      'tires' => Icons.tire_repair_rounded,
      'battery' => Icons.battery_charging_full_rounded,
      'fuel' => Icons.local_gas_station_rounded,
      'towing' => Icons.local_shipping_rounded,
      _ => Icons.handyman_rounded,
    };

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: CustomerColors.accent, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x290E1B33), blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Center(
          child: categoryId == 'fuel'
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_gas_station_rounded, size: 17, color: CustomerColors.darkPanel),
                    Text(
                      optionId == 'petrol95' ? '95' : '91',
                      style: const TextStyle(fontSize: 9, height: 1, fontWeight: FontWeight.w900, color: CustomerColors.accent),
                    ),
                  ],
                )
              : Icon(symbol, size: 22, color: CustomerColors.darkPanel),
        ),
      ),
    );
  }
}
