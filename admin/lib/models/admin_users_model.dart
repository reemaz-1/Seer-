import 'package:cloud_firestore/cloud_firestore.dart';

/// A user shown in the administrator's user-management screen.
class AdminUserData {
  final String id;
  final String type; // customer or provider
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String vehicleBrand;
  final String vehicleModel;
  final bool isSuspended;

  const AdminUserData({
    required this.id,
    required this.type,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.isSuspended,
    this.vehicleBrand = '',
    this.vehicleModel = '',
  });

  factory AdminUserData.fromMap(
    String id,
    String type,
    Map<String, dynamic> data,
  ) {
    String read(String key) => data[key]?.toString() ?? '';
    return AdminUserData(
      id: id,
      type: type,
      firstName: read('firstName'),
      lastName: read('lastName'),
      email: read('email'),
      phone: read('phone'),
      vehicleBrand: read('vehicleBrand'),
      vehicleModel: read('vehicleModel'),
      isSuspended: data['isSuspended'] == true,
    );
  }

  String get name => '$firstName $lastName'.trim();
}

class AdminUsersModel {
  static Stream<List<AdminUserData>> streamCustomers() => FirebaseFirestore
      .instance
      .collection('customers')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AdminUserData.fromMap(doc.id, 'customer', doc.data()))
          .toList());

  // Keep approved providers in the list even after suspension, so the admin
  // can reactivate them. Approval and suspension are independent dimensions.
  static Stream<List<AdminUserData>> streamApprovedProviders() => FirebaseFirestore
      .instance
      .collection('providers')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AdminUserData.fromMap(doc.id, 'provider', doc.data()))
          .toList());

  static Future<void> setSuspended(AdminUserData user, bool suspended) {
    if (user.id.isEmpty || !['customer', 'provider'].contains(user.type)) {
      throw ArgumentError('Invalid account identifier or account type');
    }
    final collection = user.type == 'customer' ? 'customers' : 'providers';
    return FirebaseFirestore.instance.collection(collection).doc(user.id).update({
      'isSuspended': suspended,
    });
  }
}

/// Search input normalization: collapse all whitespace and ignore case.
String normalizeUserSearch(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();

bool matchesUserSearch(AdminUserData user, String input) {
  final query = normalizeUserSearch(input);
  if (query.isEmpty) return true;
  final searchable = normalizeUserSearch(
    '${user.firstName} ${user.lastName} ${user.email} ${user.phone}',
  );
  return searchable.contains(query);
}

List<AdminUserData> filterAdminUsers(
  List<AdminUserData> users, {
  required String search,
  required String type,
  required String status,
}) => users.where((user) {
  final typeMatches = type == 'all' || user.type == type;
  final statusMatches = status == 'all' ||
      (status == 'suspended' ? user.isSuspended : !user.isSuspended);
  return typeMatches && statusMatches && matchesUserSearch(user, search);
}).toList();
