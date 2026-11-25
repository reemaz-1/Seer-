import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/nearby_provider.dart';
import 'matching_controller.dart';

/// Read-only, live preview for #78. This never assigns or books a provider.
class NearbyProvidersController extends ChangeNotifier {
  NearbyProvidersController({
    FirebaseFirestore? firestore,
    DateTime Function()? now,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _now = now ?? DateTime.now;

  static const Duration locationMaxAge = Duration(minutes: 15);
  static const Duration clockTolerance = Duration(minutes: 2);
  static const double approximateGridDegrees = 0.002; // ~200 m north/south

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _freshnessTimer;
  List<MapEntry<String, Map<String, dynamic>>> _docs = const [];
  LatLng? _pickup;
  String? _categoryId;
  String? _optionId;
  bool _disposed = false;
  int _generation = 0;

  bool loading = false;
  String? error;
  List<NearbyProvider> providers = const [];

  /// A change of service or pickup re-filters the same live provider stream.
  void configure({
    required String categoryId,
    required String optionId,
    required LatLng pickup,
  }) {
    _categoryId = categoryId;
    _optionId = optionId;
    _pickup = pickup;
    if (_subscription == null) {
      _start();
    } else {
      _recalculate();
    }
  }

  void _start() {
    loading = true;
    error = null;
    notifyListeners();
    final currentGeneration = ++_generation;
    _subscription = _firestore
        .collection('providers')
        .where('status', isEqualTo: 'approved')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (_disposed || currentGeneration != _generation) return;
            _docs = [
              for (final doc in snapshot.docs) MapEntry(doc.id, doc.data()),
            ];
            loading = false;
            error = null;
            _recalculate();
          },
          onError: (Object _) {
            if (_disposed || currentGeneration != _generation) return;
            _docs = const [];
            providers = const [];
            loading = false;
            error =
                'تعذر تحميل المزودين القريبين. تحققي من الاتصال وحاولي مجددًا.';
            notifyListeners();
          },
        );
    _freshnessTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _recalculate(),
    );
  }

  void _recalculate() {
    if (_disposed ||
        _pickup == null ||
        _categoryId == null ||
        _optionId == null)
      return;
    providers = filterProviders(
      _docs,
      categoryId: _categoryId!,
      optionId: _optionId!,
      pickup: _pickup!,
      now: _now(),
    );
    notifyListeners();
  }

  /// Tests can exercise filtering without Firebase or a map widget.
  @visibleForTesting
  static List<NearbyProvider> filterProviders(
    Iterable<MapEntry<String, Map<String, dynamic>>> docs, {
    required String categoryId,
    required String optionId,
    required LatLng pickup,
    required DateTime now,
  }) {
    final found = <NearbyProvider>[];
    for (final entry in docs) {
      final data = entry.value;
      if (data['status'] != 'approved' || data['isAvailable'] != true) continue;
      if ((data['activeOrderId'] ?? '').toString().trim().isNotEmpty) continue;
      if (!MatchingController.offersOption(
        data['servicesOffered'],
        categoryId,
        optionId,
      ))
        continue;

      final point = MatchingController.readLatLng(data['currentLocation']);
      if (point == null ||
          !point.lat.isFinite ||
          !point.lng.isFinite ||
          point.lat < -90 ||
          point.lat > 90 ||
          point.lng < -180 ||
          point.lng > 180)
        continue;

      // Fail closed on stale/missing timestamps; never imply an old fix is live.
      final rawTime = data['currentLocationUpdatedAt'];
      if (rawTime is! Timestamp) continue;
      final age = now.difference(rawTime.toDate());
      if (age > locationMaxAge || age < -clockTolerance) continue;

      final km = MatchingController.distanceKm(
        pickup.latitude,
        pickup.longitude,
        point.lat,
        point.lng,
      );
      if (km > MatchingController.radiusKm) continue;

      // Visual approximation only. Firestore still holds precise provider GPS;
      // a separate server-side public projection is needed for strong privacy.
      final lat =
          (point.lat / approximateGridDegrees).round() * approximateGridDegrees;
      final lng =
          (point.lng / approximateGridDegrees).round() * approximateGridDegrees;
      // Only display a first name, never contact information or a plate number.
      final firstName = (data['firstName'] ?? '').toString().trim();
      final displayName = firstName.isEmpty ? 'مزود خدمة' : firstName;
      final count = data['ratingCount'] is num
          ? (data['ratingCount'] as num).toInt()
          : 0;
      final rawRating = data['rating'];
      final rating =
          count > 0 &&
              rawRating is num &&
              rawRating.toDouble() >= 0 &&
              rawRating.toDouble() <= 5
          ? rawRating.toDouble()
          : null;
      found.add(
        NearbyProvider(
          id: entry.key,
          mapPoint: LatLng(lat, lng),
          distanceKm: km,
          displayName: displayName,
          rating: rating,
          ratingCount: count,
        ),
      );
    }
    found.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return List.unmodifiable(found);
  }

  Future<void> retry() async {
    await _subscription?.cancel();
    _subscription = null;
    _freshnessTimer?.cancel();
    if (!_disposed) _start();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _freshnessTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
