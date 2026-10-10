import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/models/order.dart';
import 'package:provider/models/provider_request_model.dart';
import 'package:provider/services/provider_location_service.dart';
import 'package:provider/controllers/address_controller.dart';

/// Takes a clock and optional overrides; returns a fully populated test snapshot.
ServiceOrder requestFixture(
  DateTime now, {
  String id = 'request-1',
  Map<String, dynamic> overrides = const {},
}) => ServiceOrder.fromMap(id, {
  'customerId': 'customer-1',
  'customerName': 'PRIVATE CUSTOMER',
  'customerPhone': 'PRIVATE PHONE',
  'vehicleId': 'car-1',
  'vehicleTitle': 'تويوتا كامري 2022',
  'vehiclePlateArabic': '١٢٣٤ أ ب د',
  'vehiclePlateLatin': '1234 A B D',
  'serviceCategoryId': 'towing',
  'serviceCategoryLabel': 'خدمة السطحة',
  'serviceOptionId': 'regular',
  'serviceOptionLabel': 'سطحة عادية',
  'serviceBranch': 'عادية',
  'note': 'المركبة عند مدخل الحي',
  'estimatedPrice': 150,
  'status': 'pending',
  'providerId': null,
  'candidateProviderIds': ['p1', 'p2'],
  'rejectedBy': <String>[],
  'pickupLocation': const GeoPoint(24.7136, 46.6753),
  'dropoffLocation': const GeoPoint(24.7743, 46.7386),
  'createdAt': Timestamp.fromDate(now),
  'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 2))),
  ...overrides,
});

class FakeRequests implements RequestRepository {
  final stream = StreamController<List<ServiceOrder>>.broadcast(sync: true);
  int accepts = 0;
  int rejects = 0;
  Completer<void>? pending;
  Object? failure;

  /// Takes an id; returns the controllable candidate stream.
  @override
  Stream<List<ServiceOrder>> watchCandidates(String providerId) =>
      stream.stream;

  /// Takes response ids; records and optionally delays/fails acceptance.
  @override
  Future<void> accept(String orderId, String providerId) async {
    accepts++;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  /// Takes response ids; records and optionally fails rejection.
  @override
  Future<void> reject(String orderId, String providerId) async {
    rejects++;
    if (failure != null) throw failure!;
  }
}

class FakeLocation implements ProviderLocationSource {
  Object? failure;
  final stream = StreamController<GeoPoint>.broadcast(sync: true);

  /// Takes no inputs; returns the provider's test GPS point or configured error.
  @override
  Future<GeoPoint> current() async {
    if (failure != null) throw failure!;
    return const GeoPoint(24.7136, 46.6653);
  }

  /// Takes no inputs; returns controllable movement updates.
  @override
  Stream<GeoPoint> watch() => stream.stream;
}

class FakeAddresses extends AddressController {
  /// Takes a point; returns a readable address without platform dependencies.
  @override
  Future<String?> addressOf(GeoPoint point) async =>
      point.latitude < 24.75 ? 'شارع الملك فهد، الرياض' : 'حي النرجس، الرياض';
}
