import 'package:cloud_firestore/cloud_firestore.dart';

/// MODEL: the customer's data, and where it is loaded from / saved to.
class Customer {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;

  const Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
  });

  String get fullName => '$firstName $lastName';

  /// First letter of the first name, shown in the avatar.
  String get initial => firstName.isNotEmpty ? firstName.substring(0, 1) : '?';

  Customer copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
  }) {
    return Customer(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  /// Build a Customer from a Firestore document.
  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    return Customer(
      id: id,
      firstName: (map['firstName'] ?? '') as String,
      lastName: (map['lastName'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      email: (map['email'] ?? '') as String,
    );
  }

  /// Convert to a map to save in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
    };
  }
}

/// Talks to the database.
class CustomerModel {
  final _firestore = FirebaseFirestore.instance;

  Future<Customer> getCustomer(String uid) async {
    final doc = await _firestore.collection('customers').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Customer not found');
    }
    return Customer.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _firestore
        .collection('customers')
        .doc(customer.id)
        .update(customer.toMap());
  }
}