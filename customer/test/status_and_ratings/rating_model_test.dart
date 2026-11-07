import 'package:customer/models/rating_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_store.dart';

void main() {
  late MemoryStore store;
  late RatingModel model;
  setUp(() {
    store = MemoryStore();
    store.data['orders/o1'] = {
      'customerId': 'c1',
      'providerId': 'p1',
      'status': 'completed',
    };
    store.data['providers/p1'] = {
      'ratingSum': 8,
      'ratingCount': 2,
      'rating': 4.0,
      'firstName': 'Provider',
      'isAvailable': true,
      'status': 'approved',
      'servicesOffered': {'battery': true},
      'activeOrderId': 'another-order',
    };
    model = RatingModel(firestore: store);
  });
  Future<void> submit({int stars = 5, String customerId = 'c1'}) =>
      model.submit(orderId: 'o1', customerId: customerId, stars: stars);
  test('rating and provider aggregate commit together', () async {
    await submit();
    expect(store.data['ratings/o1']!['stars'], 5);
    expect(store.data['providers/p1']!['ratingCount'], 3);
    expect(store.data['providers/p1']!['rating'], closeTo(13 / 3, 0.00001));
    expect(store.written, ['ratings/o1', 'providers/p1']);
    expect(store.data['providers/p1']!['firstName'], 'Provider');
    expect(store.data['providers/p1']!['servicesOffered'], {'battery': true});
    expect(store.data['providers/p1']!['activeOrderId'], 'another-order');
    expect(store.data['providers/p1']!['status'], 'approved');
    expect(store.data['providers/p1']!['isAvailable'], true);
  });
  test('retries a permission conflict in a fresh transaction without double counting', () async {
    store.permissionFailures = 1;
    await submit();
    expect(store.data['providers/p1']!['ratingCount'], 3);
    expect(store.written, ['ratings/o1', 'providers/p1']);
  });
  test('duplicate submission leaves the aggregate unchanged', () async {
    await submit();
    await expectLater(submit(stars: 1), throwsA(isA<RatingException>()));
    expect(store.data['providers/p1']!['ratingCount'], 3);
  });
  for (final stars in [0, 6]) {
    test('rejects $stars stars', () async {
      await expectLater(submit(stars: stars), throwsA(isA<RatingException>()));
      expect(store.written, isEmpty);
    });
  }
  for (final status in [
    'pending',
    'accepted',
    'inProgress',
    'cancelled',
    'rejected',
  ]) {
    test('cannot rate a $status order', () async {
      store.data['orders/o1']!['status'] = status;
      await expectLater(submit(), throwsA(isA<RatingException>()));
      expect(store.written, isEmpty);
    });
  }
  test('another customer cannot rate this order', () async {
    await expectLater(
      submit(customerId: 'c2'),
      throwsA(isA<RatingException>()),
    );
    expect(store.written, isEmpty);
  });
  test(
    'failed commit saves neither the rating nor the new aggregate',
    () async {
      store.failCommit = true;
      await expectLater(submit(), throwsStateError);
      expect(store.data.containsKey('ratings/o1'), isFalse);
      expect(store.data['providers/p1']!['ratingCount'], 2);
    },
  );
}
