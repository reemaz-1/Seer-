// Firebase SDK types are faked only at the persistence boundary.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:admin/models/dashboard_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class StreamStore extends Fake implements FirebaseFirestore {
  final streams = {
    for (final path in ['customers', 'providers', 'orders', 'complaints'])
      path: StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(),
  };

  /// Takes a collection path; returns its independently controlled snapshot source.
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      StreamCollection(streams[path]!);
}

class StreamCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  /// Takes a source; creates a fake collection for the stream boundary.
  StreamCollection(this.source);
  final StreamController<QuerySnapshot<Map<String, dynamic>>> source;

  /// Takes snapshot options; returns the collection's stream.
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => this.source.stream;
}

class Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  /// Takes one document and cache state; creates a Firestore snapshot.
  Snapshot(this.docs, {bool cached = false}) : metadata = Metadata(cached);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

class Metadata extends Fake implements SnapshotMetadata {
  /// Takes the cache flag; creates snapshot metadata.
  Metadata(this.isFromCache);
  @override
  final bool isFromCache;
}

class Record extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  /// Takes the id and stored fields; creates a snapshot document.
  Record(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;

  /// Takes no arguments; returns the stored record.
  @override
  Map<String, dynamic> data() => value;
}

/// Verifies the actual collection-combining model without a network connection.
void main() {
  test(
    'waits for all sources, preserves failures and cancels every listener',
    () async {
      final store = StreamStore();
      final values = <DashboardData>[];
      final errors = <Object>[];
      final sub = DashboardModel(firestore: store)
          .watch()
          .listen(values.add, onError: errors.add);
      for (final path in ['customers', 'providers', 'orders']) {
        store.streams[path]!.add(
          Snapshot([
            Record(path, {'status': 'pending'}),
          ]),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      store.streams['complaints']!.add(Snapshot([], cached: true));
      await Future<void>.delayed(Duration.zero);
      expect(values.single.customers.single['id'], 'customers');
      expect(values.single.orders.length, 1);
      expect(values.single.isFromCache, true);
      store.streams['complaints']!.add(Snapshot([]));
      await Future<void>.delayed(Duration.zero);
      expect(values.last.isFromCache, false);
      store.streams['orders']!.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));
      final previousCount = values.length;
      store.streams['customers']!.add(Snapshot([]));
      await Future<void>.delayed(Duration.zero);
      expect(
        values.length,
        previousCount,
      ); // Never replace a failed order read with zero.
      await sub.cancel();
      expect(store.streams.values.every((source) => !source.hasListener), true);
      for (final source in store.streams.values) {
        await source.close();
      }
    },
  );
}
