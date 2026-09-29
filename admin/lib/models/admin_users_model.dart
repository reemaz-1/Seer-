import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserData {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String vehicleBrand;
  final String vehicleModel;

  const AdminUserData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.vehicleBrand = '',
    this.vehicleModel = '',
  });

  factory AdminUserData.fromMap(Map<String, dynamic> data) {
    return AdminUserData(
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      vehicleBrand: data['vehicleBrand'] ?? '',
      vehicleModel: data['vehicleModel'] ?? '',
    );
  }
}

class AdminUsersModel {
  static Stream<List<AdminUserData>> streamCustomers() {
    return FirebaseFirestore.instance
        .collection('customers')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminUserData.fromMap(doc.data()))
              .toList(),
        );
  }

  static Stream<List<AdminUserData>> streamApprovedProviders() {
    return FirebaseFirestore.instance
        .collection('providers')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminUserData.fromMap(doc.data()))
              .toList(),
        );
  }
}