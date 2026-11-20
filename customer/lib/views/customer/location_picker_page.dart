import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../controllers/nearby_providers_controller.dart';
import '../../models/nearby_provider.dart';
import '../../widgets/nearby_service_marker.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.title,
    this.initialSelectedLocation,
    this.categoryId,
    this.optionId,
  });

  final String title;
  final LatLng? initialSelectedLocation;
  // Only supplied for the pickup picker, never for the towing destination.
  final String? categoryId;
  final String? optionId;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const String _apiKey = String.fromEnvironment('STADIA_API_KEY');
  static const LatLng _initialLocation = LatLng(24.7136, 46.6753);

  final MapController _mapController = MapController();
  NearbyProvidersController? _nearby;
  // Cache a lookup for each already-approximated marker location.
  final Map<String, Future<String>> _providerAreaCache = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LatLng? _selectedLocation;
  LatLng? _currentLocation;

  bool _isFetchingLocation = true;
  bool _gpsFailed = false;
  bool _isSearching = false;
  String? _searchError;

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  int _searchVersion = 0;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialSelectedLocation;
    if (widget.categoryId != null && widget.optionId != null) {
      _nearby = NearbyProvidersController()..addListener(_onNearbyChanged);
      if (_selectedLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedLocation != null) {
            _loadNearby(_selectedLocation!);
          }
        });
      }
    }
    _fetchCurrentLocation();
  }

  void _onNearbyChanged() {
    if (mounted) setState(() {});
  }

  void _loadNearby(LatLng location) {
    final nearby = _nearby;
    if (nearby == null) return;
    nearby.configure(
      categoryId: widget.categoryId!,
      optionId: widget.optionId!,
      pickup: location,
    );
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _gpsFailed = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isFetchingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingLocation = false;
        _gpsFailed = true;
      });
      debugPrint('GPS error: $e');
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final version = ++_searchVersion;

    if (text.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _suggestions = [];
      _searchError = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(text.trim(), version);
    });
  }

  Future<void> _fetchSuggestions(String query, int version) async {
    try {
      final uri = Uri.https(
        'api.stadiamaps.com',
        '/geocoding/v1/autocomplete',
        {
          'text': query,
          'api_key': _apiKey,
          'size': '5',
          'focus.point.lat': '24.7136',
          'focus.point.lon': '46.6753',
          'boundary.country': 'SA',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (!mounted || version != _searchVersion) return;

      if (response.statusCode != 200) {
        throw Exception('Search API returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      setState(() {
        _suggestions = features.whereType<Map<String, dynamic>>().toList();
        _isSearching = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || version != _searchVersion) return;

      setState(() {
        _isSearching = false;
        _suggestions = [];
        _searchError = 'تعذر البحث، حاولي مرة أخرى';
      });
      debugPrint('Stadia autocomplete error: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;

    if (coordinates == null || coordinates.length < 2) return;

    // GeoJSON coordinates are [longitude, latitude].
    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();
    final location = LatLng(latitude, longitude);

    _debounce?.cancel();
    _searchVersion++;

    final properties = feature['properties'] as Map<String, dynamic>?;
    final name =
        properties?['label']?.toString() ??
        properties?['name']?.toString() ??
        '';

    _searchController.text = name;
    _searchFocus.unfocus();

    setState(() {
      _selectedLocation = location;
      _suggestions = [];
      _isSearching = false;
      _searchError = null;
    });

    _loadNearby(location);
    _mapController.move(location, 16);
  }

  // Changes only the map camera; the selected pickup and provider filter stay unchanged.
  void _changeMapZoom(double amount) {
    final camera = _mapController.camera;
    final nextZoom = (camera.zoom + amount).clamp(3.0, 18.0).toDouble();
    _mapController.move(camera.center, nextZoom);
  }

  // Read-only details: tapping a provider must not select a new pickup point.
  // Only lookup the already-rounded map marker position, never the provider's
  // precise GPS point. Fetch only when the details card is opened.
  Future<String> _providerArea(NearbyProvider provider) {
    final point = provider.mapPoint;
    final key =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    return _providerAreaCache.putIfAbsent(key, () async {
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          point.latitude,
          point.longitude,
          locale: const Locale('ar', 'SA'),
        );
        if (places.isNotEmpty) {
          final district = (places.first.subLocality ?? '').trim();
          final city = (places.first.locality ?? '').trim();
          if (district.isNotEmpty && city.isNotEmpty && district != city) {
            return '$district، $city';
          }
          if (city.isNotEmpty) return city;
          if (district.isNotEmpty) return district;
        }
      } catch (error) {
        // A missing geocoding backend / network should not block the map.
        debugPrint('Approximate provider area lookup failed: $error');
      }
      return 'الموقع غير متوفر حاليًا';
    });
  }

  void _showNearbyProviderDetails(NearbyProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'معلومات مزود الخدمة',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF22324D),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEAF3EC),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22324D),
                      ),
                    ),
                  ),
                  if (provider.rating != null) ...[
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF3B63F),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '(${provider.ratingCount})',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ] else
                    const Text(
                      'لا توجد تقييمات بعد',
                      style: TextStyle(color: Colors.black54),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.near_me_outlined,
                    size: 19,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'على بُعد حوالي ${provider.distanceKm.toStringAsFixed(1)} كم',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 19,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _providerArea(provider),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Text('جارٍ تحديد الحي والمدينة...');
                        }
                        return Text(snapshot.data ?? 'الموقع غير متوفر حاليًا');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'الموقع المعروض تقريبي لحماية خصوصية المزود.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Short count-only message; service and radius are already reflected in markers.
  String _nearbyStatusMessage() {
    final nearby = _nearby;
    if (nearby == null) return '';
    if (nearby.loading) return 'جارٍ البحث عن مزودين قريبين...';
    if (nearby.error != null) return nearby.error!;
    return switch (nearby.providers.length) {
      0 => 'ما فيه مزودين قريبين حاليًا',
      1 => 'فيه مزود قريب منك!',
      2 => 'فيه مزودين قريبين منك!',
      final count => 'فيه $count مزودين قريبين منك!',
    };
  }

  void _clearSearchResults() {
    _debounce?.cancel();
    _searchVersion++;
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _searchError = null;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    _nearby?.removeListener(_onNearbyChanged);
    _nearby?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialSelectedLocation ?? _initialLocation,
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 18,
              onTap: (tapPosition, point) {
                _clearSearchResults();
                setState(() {
                  _selectedLocation = point;
                });
                _loadNearby(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=$_apiKey',
                userAgentPackageName: 'com.example.seer',
              ),
              MarkerLayer(
                markers: [
                  for (final provider
                      in _nearby?.providers ?? const <NearbyProvider>[])
                    Marker(
                      point: provider.mapPoint,
                      width: 46,
                      height: 46,
                      child: Semantics(
                        button: true,
                        label: 'عرض معلومات ${provider.displayName}',
                        child: Tooltip(
                          message: 'عرض معلومات ${provider.displayName}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showNearbyProviderDetails(provider),
                            child: NearbyServiceMarker(
                              categoryId: widget.categoryId!,
                              optionId: widget.optionId!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_selectedLocation != null)
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 45,
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© Stadia Maps, © OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),

          // #78: zoom controls are separate from selecting a pickup location.
          Positioned(
            top: 90,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تكبير الخريطة',
                      onPressed: () => _changeMapZoom(1),
                      icon: const Icon(Icons.add_rounded),
                      color: const Color(0xFF22324D),
                    ),
                    const SizedBox(width: 30, child: Divider(height: 1)),
                    IconButton(
                      tooltip: 'تصغير الخريطة',
                      onPressed: () => _changeMapZoom(-1),
                      icon: const Icon(Icons.remove_rounded),
                      color: const Color(0xFF22324D),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // GPS button remains available below the search bar.
          Positioned(
            top: 90,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                child: TextButton.icon(
                  onPressed: _isFetchingLocation
                      ? null
                      : _gpsFailed
                      ? _fetchCurrentLocation
                      : () {
                          if (_currentLocation == null) return;
                          _clearSearchResults();
                          setState(() {
                            _selectedLocation = _currentLocation;
                          });
                          _loadNearby(_currentLocation!);
                          _mapController.move(_currentLocation!, 16);
                        },
                  icon: _isFetchingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.grey,
                          ),
                        )
                      : Icon(
                          _gpsFailed
                              ? Icons.location_disabled
                              : Icons.my_location,
                          color: _gpsFailed
                              ? Colors.grey
                              : const Color(0xFF2E7D32),
                        ),
                  label: Text(
                    _isFetchingLocation
                        ? 'جارٍ تحديد الموقع...'
                        : _gpsFailed
                        ? 'إعادة المحاولة'
                        : 'موقعي الحالي',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    disabledForegroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search bar and autocomplete suggestions.
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن موقع أو عنوان...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _clearSearchResults();
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_suggestions.isNotEmpty || _searchError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      constraints: const BoxConstraints(maxHeight: 230),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: _searchError != null
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_searchError!),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final feature = _suggestions[index];
                                final properties =
                                    feature['properties']
                                        as Map<String, dynamic>?;

                                final label =
                                    properties?['label']?.toString() ??
                                    properties?['name']?.toString() ??
                                    'موقع';

                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  title: Text(
                                    label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectSuggestion(feature),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),

          // Display read-only provider availability on the same pickup map.
          if (_selectedLocation != null && _nearby != null)
            Positioned(
              bottom: 94,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (_nearby!.loading) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            _nearbyStatusMessage(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22324D),
                            ),
                          ),
                        ),
                        if (_nearby!.error != null)
                          IconButton(
                            tooltip: 'إعادة المحاولة',
                            onPressed: () => _nearby!.retry(),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Existing confirmation button.
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _selectedLocation == null
                    ? null
                    : () => Navigator.pop(context, _selectedLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'تأكيد الموقع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
