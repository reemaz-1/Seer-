// Firebase SDK types are faked only at the persistence boundary.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore extends Fake implements FirebaseFirestore {
  final data = <String, Map<String, dynamic>>{};
  final written = <String>[];
  bool failCommit = false;
  int permissionFailures = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = _Transaction(this);
    final result = await handler(tx);
    if (permissionFailures > 0) {
      permissionFailures--;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    if (failCommit) throw StateError('Injected commit failure');
    for (final entry in tx.writes.entries) {
      data[entry.key] = {...?data[entry.key], ...entry.value};
      written.add(entry.key);
    }
    return result;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final MemoryStore store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(store, '$path/${id ?? 'generated'}');
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final MemoryStore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final MemoryStore store;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    if (writes.isNotEmpty) throw StateError('Transaction read after write');
    return _Snapshot<T>(ref.id, store.data[ref.path] as T?);
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes[ref.path] = data as Map<String, dynamic>;
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    writes[ref.path] = data;
    return this;
  }
}
