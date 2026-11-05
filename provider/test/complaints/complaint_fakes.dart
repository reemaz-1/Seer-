import 'dart:async';

import 'package:provider/models/complaint.dart';
import 'package:provider/models/complaint_model.dart';

/// Keeps complaints in memory instead of Firestore.
class FakeComplaintModel extends ComplaintModel {
  /// Takes an optional [existing] complaint already saved for the order.
  FakeComplaintModel({this.existing});

  Complaint? existing;
  final List<Complaint> submitted = [];
  final _changes = StreamController<Complaint?>.broadcast(sync: true);

  /// Set to make the next submit fail like a network error.
  Object? failure;

  @override
  Stream<Complaint?> watchComplaintForOrder(String orderId) async* {
    yield existing;
    yield* _changes.stream;
  }

  @override
  Future<void> submit(Complaint complaint) async {
    if (failure != null) throw failure!;
    if (existing != null) throw const ComplaintAlreadyExists();
    submitted.add(complaint);
    existing = complaint;
    _changes.add(complaint);
  }

  @override
  Future<String?> providerName(String uid) async => 'مزود الخدمة';
}
