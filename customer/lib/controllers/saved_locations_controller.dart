import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/saved_location.dart';

/// CONTROLLER: the customer's saved places (home, work, and named places).
///
/// Used by the request page and by the saved places page. Every change shows
/// on screen at once and the write follows; if the write fails the old list
/// comes back and the caller gets a message to show.
class SavedLocationsController extends ChangeNotifier {
  SavedLocationsController({required this.uid, SavedLocationModel? model})
      : _model = model ?? SavedLocationModel();

  final String uid;
  final SavedLocationModel _model;

  List<SavedLocation> places = [];
  bool isLoading = true;
  String? loadError;

  static const _networkError = 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';

  /// Never throws: without the places the customer just picks on the map.
  Future<void> load() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      places = await _model.getAll(uid);
    } catch (e) {
      debugPrint('loading saved places failed: $e');
      loadError = 'تعذّر تحميل أماكنك. $_networkError';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// The saved place at [point], if there is one.
  SavedLocation? placeAt(GeoPoint? point) {
    for (final place in places) {
      if (place.isSameAs(point)) return place;
    }
    return null;
  }

  /// Saves [point] as home, work, or an "other" place called [name].
  ///
  /// A place already saved at the same spot is replaced, so one spot never
  /// has two names: saving it again just renames it. Saving as home or work
  /// replaces the old home or work. [replaceId] keeps the id of an "other"
  /// place that is being moved to a new spot.
  ///
  /// Returns null on success, or a message to show.
  Future<String?> save({
    required String kind,
    String? name,
    required GeoPoint point,
    String? replaceId,
  }) async {
    final cleanName = name?.trim() ?? '';
    if (kind == SavedLocation.other) {
      if (cleanName.isEmpty) return 'اكتب اسمًا للمكان';
      if (cleanName.length > SavedLocation.maxNameLength) {
        return 'الاسم أطول من ${SavedLocation.maxNameLength} حرفًا';
      }
    }

    final before = places;
    final isHomeOrWork = kind != SavedLocation.other;
    // An "other" place never reuses the id of home or work (renaming home to
    // a custom name gets a fresh id; the old home is removed as the same spot).
    final reusable = replaceId != null &&
        replaceId != SavedLocation.home &&
        replaceId != SavedLocation.work;
    final id = isHomeOrWork ? kind : (reusable ? replaceId : _model.newId(uid));
    final place = SavedLocation(
      id: id,
      kind: kind,
      location: point,
      name: isHomeOrWork ? null : cleanName,
    );
    final sameSpot = [
      for (final p in before)
        if (p.id != id && p.isSameAs(point)) p.id,
    ];

    final isNew = !before.any((p) => p.id == id);
    final freed = sameSpot.length;
    if (isNew && before.length - freed >= SavedLocation.maxPlaces) {
      return 'وصلت للحد الأقصى (${SavedLocation.maxPlaces} أماكن). احذف مكانًا أولًا.';
    }

    places = [
      for (final p in before)
        if (p.id != id && !sameSpot.contains(p.id)) p,
      place,
    ]..sort(SavedLocation.compare);
    notifyListeners();

    try {
      await _model.save(uid, place, removeIds: sameSpot);
      return null;
    } catch (e) {
      debugPrint('saving a place failed: $e');
      places = before;
      notifyListeners();
      return 'تعذّر حفظ الموقع. $_networkError';
    }
  }

  /// Returns null on success, or a message to show.
  Future<String?> remove(String id) async {
    final before = places;
    places = [
      for (final p in before)
        if (p.id != id) p,
    ];
    notifyListeners();
    try {
      await _model.delete(uid, id);
      return null;
    } catch (e) {
      debugPrint('deleting a place failed: $e');
      places = before;
      notifyListeners();
      return 'تعذّر حذف الموقع. $_networkError';
    }
  }
}
