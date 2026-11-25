import 'package:cloud_firestore/cloud_firestore.dart';

/// MODEL: a place the customer saved to pick it quickly when requesting a
/// service. It can be home, work, or any other place under a name the
/// customer chose.
///
///   customers/{uid}/savedLocations/{id}
///
/// Home and work are one each, so their document id is the kind itself
/// ("home" / "work"). Other places get a generated id and keep their name.
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.kind,
    required this.location,
    this.name,
  });

  static const home = 'home';
  static const work = 'work';
  static const other = 'other';

  /// The longest name a customer can give a place.
  static const maxNameLength = 20;

  /// How many places a customer can keep.
  static const maxPlaces = 10;

  final String id;

  /// 'home', 'work' or 'other'.
  final String kind;
  final GeoPoint location;

  /// The customer's own name. Only for kind 'other'.
  final String? name;

  /// What the customer reads for home and work.
  static String labelOf(String kind) {
    if (kind == home) return 'المنزل';
    if (kind == work) return 'العمل';
    return 'مكان آخر';
  }

  /// The name shown on the chip and in the list.
  String get label {
    if (kind != other) return labelOf(kind);
    final text = name?.trim() ?? '';
    return text.isEmpty ? 'مكان محفوظ' : text;
  }

  /// True when [point] is the same place, give or take about 10 metres, so a
  /// location picked on the map again still counts as the saved one.
  bool isSameAs(GeoPoint? point) {
    if (point == null) return false;
    return (point.latitude - location.latitude).abs() < 0.0001 &&
        (point.longitude - location.longitude).abs() < 0.0001;
  }

  /// null when the document is not a valid saved place.
  static SavedLocation? fromMap(String id, Map<String, dynamic> map) {
    final point = map['location'];
    if (point is! GeoPoint) return null;

    final kind = map['kind'];
    if (kind == home || kind == work) {
      // Home and work always live under their own id.
      if (id != kind) return null;
      return SavedLocation(id: id, kind: kind as String, location: point);
    }
    if (kind == other) {
      final name = map['name'];
      if (name is! String || name.trim().isEmpty) return null;
      return SavedLocation(
        id: id,
        kind: other,
        location: point,
        name: name.trim(),
      );
    }
    return null;
  }

  /// Home first, then work, then the others by name.
  static int compare(SavedLocation a, SavedLocation b) {
    int rank(SavedLocation p) =>
        p.kind == home ? 0 : (p.kind == work ? 1 : 2);
    final byKind = rank(a).compareTo(rank(b));
    return byKind != 0 ? byKind : a.label.compareTo(b.label);
  }
}

/// Talks to the database.
class SavedLocationModel {
  SavedLocationModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _placesOf(String uid) =>
      _firestore.collection('customers').doc(uid).collection('savedLocations');

  /// A fresh id for a new "other" place. Made on the phone, no network, so
  /// the screen can show the place before it is written.
  String newId(String uid) => _placesOf(uid).doc().id;

  /// The saved places, home first. Empty when the customer saved none.
  Future<List<SavedLocation>> getAll(String uid) async {
    final snapshot = await _placesOf(uid).get();
    final result = <SavedLocation>[];
    for (final doc in snapshot.docs) {
      final place = SavedLocation.fromMap(doc.id, doc.data());
      if (place != null) result.add(place);
    }
    result.sort(SavedLocation.compare);
    return result;
  }

  /// Writes [place], and deletes the places in [removeIds] (another name for
  /// the same spot) in the same batch, so they never show twice.
  Future<void> save(
    String uid,
    SavedLocation place, {
    List<String> removeIds = const [],
  }) {
    final places = _placesOf(uid);
    final batch = _firestore.batch();
    for (final id in removeIds) {
      if (id != place.id) batch.delete(places.doc(id));
    }
    batch.set(places.doc(place.id), {
      'kind': place.kind,
      if (place.kind == SavedLocation.other) 'name': place.name!.trim(),
      'location': place.location,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  Future<void> delete(String uid, String id) {
    return _placesOf(uid).doc(id).delete();
  }
}
