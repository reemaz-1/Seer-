import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderRegistrationRequest {
  final String id;
  final String firstName;
  final String lastName;
  final String nationalId; // National ID / Iqama
  final String phone;
  final String email;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleYear;
  final String plateNumber;
  final String licenseNumber;
  final Map<String, List<String>> servicesByCategory;
  final String status; // pending / approved / rejected
  final DateTime? createdAt;

  ProviderRegistrationRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.nationalId,
    required this.phone,
    required this.email,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.plateNumber,
    required this.licenseNumber,
    required this.servicesByCategory,
    required this.status,
    this.createdAt,
  });

  static CollectionReference<Map<String, dynamic>> _collection() {
    return FirebaseFirestore.instance.collection('providers');
  }

  // servicesOffered comes as a map of categories (battery, fuel, tires,
  // towing), each with a "label" (category name) and an "options" list
  // of {enabled, id, label}. We keep the category label as a heading,
  // and list under it the labels of just the enabled options.
  static Map<String, List<String>> _parseServicesOffered(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw is Map) {
      for (final category in raw.values) {
        if (category is Map && category['options'] is List) {
          final categoryLabel = category['label']?.toString() ?? '';
          final enabledLabels = <String>[];
          for (final option in category['options']) {
            if (option is Map &&
                option['enabled'] == true &&
                option['label'] != null) {
              enabledLabels.add(option['label'].toString());
            }
          }
          if (enabledLabels.isNotEmpty && categoryLabel.isNotEmpty) {
            result[categoryLabel] = enabledLabels;
          }
        }
      }
    }
    return result;
  }

  factory ProviderRegistrationRequest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ProviderRegistrationRequest(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      nationalId: data['nationalId'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      vehicleBrand: data['vehicleBrand'] ?? '',
      vehicleModel: data['vehicleModel'] ?? '',
      vehicleYear: data['vehicleYear'] ?? '',
      plateNumber: '${data['plateNumberArabic'] ?? ''} / ${data['plateNumberLatin'] ?? ''}',
      licenseNumber: data['licenseNumber'] ?? '',
      servicesByCategory: _parseServicesOffered(data['servicesOffered']),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // Story #52: list of pending registration requests
  static Stream<List<ProviderRegistrationRequest>> streamAll() {
    return _collection()
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProviderRegistrationRequest.fromFirestore(doc))
            .toList());
  }

  // Story #51: details of one registration request
  static Future<ProviderRegistrationRequest?> fetchById(String id) async {
    final doc = await _collection().doc(id).get();
    if (!doc.exists) return null;
    return ProviderRegistrationRequest.fromFirestore(doc);
  }

  // Story #53: approve or reject a registration request
  static Future<void> updateStatus(String id, String newStatus) async {
    await _collection().doc(id).update({'status': newStatus});
  }
}