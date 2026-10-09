import 'package:cloud_firestore/cloud_firestore.dart';

/// MODEL: persists the existing provider location used by customer matching.
class ProviderLocationModel {
  /// Takes an optional Firestore client; creates the own-profile location gateway.
  ProviderLocationModel({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// Takes the authenticated [providerId] and GPS [point]; updates only
  /// currentLocation and completes after the server write, or throws on failure.
  Future<void> saveCurrentLocation(String providerId, GeoPoint point) async {
    if (providerId.isEmpty) throw StateError('سجّل الدخول لتحديث موقعك.');
    await _firestore.collection('providers').doc(providerId).update({
      'currentLocation': point,
    });
  }
}
