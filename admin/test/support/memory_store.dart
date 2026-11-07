// Firebase SDK types are faked only at the persistence boundary.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore extends Fake implements FirebaseFirestore {
  final data = <String, Map<String, dynamic>>{};
  final written = <String>[];
  int nextId = 0;
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
      final updated = {...?data[entry.key]};
      for (final field in entry.value.entries) {
        if (field.value == FieldValue.delete()) {
          updated.remove(field.key);
        } else if (field.value == FieldValue.serverTimestamp()) {
          updated[field.key] = Timestamp.now();
        } else {
          updated[field.key] = field.value;
        }
      }
      data[entry.key] = updated;
      written.add(entry.key);
    }
    return result;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Query(store, path, field.toString(), isEqualTo);

  final MemoryStore store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(store, '$path/${id ?? 'generated-${store.nextId++}'}');
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
  _Snapshot(this.id, this.value, this.reference);
  @override
  final DocumentReference<T> reference;
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
    return _Snapshot<T>(ref.id, store.data[ref.path] as T?, ref);
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes[ref.path] = data as Map<String, dynamic>;
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    writes[ref.path] = {...?writes[ref.path], ...data};
    return this;
  }
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.store, this.path, this.field, this.value);
  final MemoryStore store;
  final String path, field;
  final Object? value;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QuerySnapshot([
    for (final entry in store.data.entries)
      if (entry.key.startsWith('$path/') && entry.value[field] == value)
        _QueryDoc(entry.key.split('/').last, entry.value),
  ]);
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _QueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDoc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}
