import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../controllers/saved_locations_controller.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/save_place_sheet.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.title,
    this.initialSelectedLocation,
    this.places,
  });

  final String title;
  final LatLng? initialSelectedLocation;

  /// The customer's saved places. When given, a "save this place" button
  /// appears next to the confirm button, so a place can be saved while it is
  /// picked.
  final SavedLocationsController? places;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const String _apiKey = String.fromEnvironment('STADIA_API_KEY');
  static const LatLng _initialLocation = LatLng(24.7136, 46.6753);

  final MapController _mapController = MapController();
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
    _fetchCurrentLocation();
  }

  /// Saves the selected spot under a name the customer picks. Saving a spot
  /// that already has a name renames it, so one spot never has two names.
  Future<void> _savePlace() async {
    final controller = widget.places;
    final selected = _selectedLocation;
    if (controller == null || selected == null) return;
    final point = GeoPoint(selected.latitude, selected.longitude);
    final existing = controller.placeAt(point);

    final choice = await showSavePlaceSheet(
      context,
      savedPlaces: controller.places,
      current: existing,
    );
    if (choice == null || !mounted) return;

    // The list already changes; confirm now, and speak again only if it fails.
    final result = controller.save(
      kind: choice.kind,
      name: choice.name,
      point: point,
      replaceId: existing?.kind == choice.kind ? existing?.id : null,
    );
    final label = choice.kind == 'other' ? choice.name! : (choice.kind == 'home' ? 'المنزل' : 'العمل');
    showAppMessage(
      context,
      existing == null ? 'تم حفظ الموقع كـ $label' : 'تم تحديث الاسم إلى $label',
      type: AppMessageType.success,
    );
    final error = await result;
    if (error != null && mounted) {
      showAppMessage(context, error, type: AppMessageType.warning);
    }
    if (mounted) setState(() {});
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

    _mapController.move(location, 16);
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
              onTap: (tapPosition, point) {
                _clearSearchResults();
                setState(() {
                  _selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=$_apiKey',
                userAgentPackageName: 'com.example.seer',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
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

          // Save and confirm buttons.
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.places != null) ...[
                    _saveButton(),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton(
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Save this place", or "rename" when the spot already has a name.
  Widget _saveButton() {
    final selected = _selectedLocation;
    final existing = selected == null
        ? null
        : widget.places!.placeAt(GeoPoint(selected.latitude, selected.longitude));
    return OutlinedButton.icon(
      onPressed: selected == null ? null : _savePlace,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(
        existing == null ? Icons.bookmark_add_outlined : Icons.bookmark,
        size: 20,
      ),
      label: Text(
        existing == null ? 'حفظ هذا المكان' : 'محفوظ باسم ${existing.label} · تغيير',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
