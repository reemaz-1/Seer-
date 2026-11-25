import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_catalog.dart';

/// MODEL: a customer's vehicle.
///
/// The plate is stored in the same two fields the provider app uses, in the
/// same order (digits then letters): "1234 ععه" and "1234 EEH".
class Vehicle {
  final String id;
  final String brand;
  final String model;
  final int year;
  final String color;
  final String plateNumberArabic;
  final String plateNumberLatin;

  /// 'standard' (sedan / small) or 'large' (SUV / big): the car wash price
  /// depends on it. null on vehicles saved before this field existed.
  final String? bodyType;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumberArabic,
    required this.plateNumberLatin,
    this.bodyType,
  });

  String get title => '$brand $model $year';

  /// The car size for services priced by size, null when not chosen yet.
  VehicleSize? get size => VehicleSize.byId(bodyType);

  /// The Arabic plate for display: the letters spaced out, then the digits,
  /// as on the real plate ("2026 سىر" -> "س ى ر 2026"). The stored value
  /// stays as it is, so old vehicles and the provider app still work.
  String get plateDisplay {
    final parts = plateNumberArabic.trim().split(' ');
    if (parts.length < 2) return plateNumberArabic;
    final letters = parts.last.split('').join(' ');
    return '$letters ${parts.first}';
  }

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? plateNumberArabic,
    String? plateNumberLatin,
    String? bodyType,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plateNumberArabic: plateNumberArabic ?? this.plateNumberArabic,
      plateNumberLatin: plateNumberLatin ?? this.plateNumberLatin,
      bodyType: bodyType ?? this.bodyType,
    );
  }

  factory Vehicle.fromMap(String id, Map<String, dynamic> map) {
    return Vehicle(
      id: id,
      brand: (map['brand'] ?? '') as String,
      model: (map['model'] ?? '') as String,
      year: (map['year'] as num?)?.toInt() ?? 0,
      color: (map['color'] ?? '') as String,
      plateNumberArabic: (map['plateNumberArabic'] ?? '') as String,
      plateNumberLatin: (map['plateNumberLatin'] ?? '') as String,
      bodyType: map['bodyType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'plateNumberArabic': plateNumberArabic,
      'plateNumberLatin': plateNumberLatin,
      if (bodyType != null) 'bodyType': bodyType,
    };
  }
}

/// Talks to the database.
class VehicleModel {
  VehicleModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _vehiclesOf(String uid) =>
      _firestore.collection('customers').doc(uid).collection('vehicles');

  Future<List<Vehicle>> getVehicles(String uid) async {
    final snapshot = await _vehiclesOf(uid).get();
    return snapshot.docs.map((d) => Vehicle.fromMap(d.id, d.data())).toList();
  }

  /// Returns the saved vehicle with the id Firestore gave it.
  Future<Vehicle> addVehicle(String uid, Vehicle vehicle) async {
    final ref = await _vehiclesOf(uid).add(vehicle.toMap());
    return vehicle.copyWith(id: ref.id);
  }

  Future<void> updateVehicle(String uid, Vehicle vehicle) async {
    await _vehiclesOf(uid).doc(vehicle.id).update(vehicle.toMap());
  }

  Future<void> deleteVehicle(String uid, String vehicleId) async {
    await _vehiclesOf(uid).doc(vehicleId).delete();
  }
}
