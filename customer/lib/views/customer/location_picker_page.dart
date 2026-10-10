
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const String _apiKey = String.fromEnvironment('STADIA_API_KEY');

  // Riyadh is the initial location, but the map supports all of Saudi Arabia.
  static const LatLng _initialLocation = LatLng(24.7136, 46.6753);

  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _initialLocation,
              initialZoom: 13,
              onTap: (tapPosition, point) {
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
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),
),
            ),
          ),
        ],
      ),
    );
  }
}
