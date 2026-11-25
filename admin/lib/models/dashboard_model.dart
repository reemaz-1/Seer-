import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only records used by the administrator's dashboard.
class DashboardData {
  /// Takes the four collection snapshots and their cache state; creates a dataset.
  const DashboardData({
    this.customers = const [],
    this.providers = const [],
    this.orders = const [],
    this.complaints = const [],
    this.isFromCache = false,
  });

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> providers;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> complaints;
  final bool isFromCache;
}

class DashboardModel {
  /// Takes an optional Firestore client; creates the dashboard's data source.
  DashboardModel({this.firestore});

  final FirebaseFirestore? firestore;

  /// Takes no arguments; streams complete datasets or forwards read errors.
  /// No partial counts are emitted before all four collections have loaded.
  Stream<DashboardData> watch() {
    final db = firestore ?? FirebaseFirestore.instance;
    const paths = ['customers', 'providers', 'orders', 'complaints'];
    final values = <String, List<Map<String, dynamic>>>{};
    final cached = <String, bool>{};
    final failures = <String>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<DashboardData> output;
    output = StreamController<DashboardData>(
      onListen: () {
        for (final path in paths) {
          subscriptions.add(
            db
                .collection(path)
                .snapshots(includeMetadataChanges: true)
                .listen(
                  (snapshot) {
                    values[path] = snapshot.docs
                        .map((doc) => {...doc.data(), 'id': doc.id})
                        .toList();
                    cached[path] = snapshot.metadata.isFromCache;
                    failures.remove(path);
                    if (values.length != paths.length || failures.isNotEmpty) {
                      return;
                    }
                    output.add(
                      DashboardData(
                        customers: values['customers']!,
                        providers: values['providers']!,
                        orders: values['orders']!,
                        complaints: values['complaints']!,
                        isFromCache: cached.values.any((value) => value),
                      ),
                    );
                  },
                  onError: (Object error, StackTrace stack) {
                    failures.add(path);
                    output.addError(error, stack);
                  },
                ),
          );
        }
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return output.stream;
  }
}
