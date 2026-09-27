import 'package:cloud_firestore/cloud_firestore.dart';

/// MODEL: a customer's vehicle, and where vehicles are loaded from / saved to.
class Vehicle {
  final String id;
  final String brand;
  final String model;
  final int year;

  /// Stored as "ABD 1234" (letters, space, digits).
  final String plateNumber;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  String get title => '$brand $model $year';

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? year,
    String? plateNumber,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      plateNumber: plateNumber ?? this.plateNumber,
    );
  }

  /// Build a Vehicle from a Firestore document.
  factory Vehicle.fromMap(String id, Map<String, dynamic> map) {
    return Vehicle(
      id: id,
      brand: (map['brand'] ?? '') as String,
      model: (map['model'] ?? '') as String,
      year: (map['year'] ?? 0) as int,
      plateNumber: (map['plateNumber'] ?? '') as String,
    );
  }

  /// Convert to a map to save in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'plateNumber': plateNumber,
    };
  }
}

/// Talks to the database.
class VehicleModel {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _vehiclesRef(String uid) {
    return _firestore.collection('customers').doc(uid).collection('vehicles');
  }

  Future<List<Vehicle>> getVehicles(String uid) async {
    final snap = await _vehiclesRef(uid).get();
    return snap.docs.map((d) => Vehicle.fromMap(d.id, d.data())).toList();
  }

  /// Returns the saved vehicle with its new id.
  Future<Vehicle> addVehicle(String uid, Vehicle vehicle) async {
    final ref = await _vehiclesRef(uid).add(vehicle.toMap());
    return vehicle.copyWith(id: ref.id);
  }

  Future<void> updateVehicle(String uid, Vehicle vehicle) async {
    await _vehiclesRef(uid).doc(vehicle.id).update(vehicle.toMap());
  }

  Future<void> deleteVehicle(String uid, String vehicleId) async {
    await _vehiclesRef(uid).doc(vehicleId).delete();
  }
}