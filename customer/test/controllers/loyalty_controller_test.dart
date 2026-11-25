import 'package:flutter_test/flutter_test.dart';
import 'package:customer/controllers/loyalty_controller.dart';
import 'package:customer/models/complaint.dart';
import 'package:customer/models/order.dart';

/// Takes a status and whether a free wash paid for it; returns a test order.
ServiceOrder _order(String status, {bool usedFreeWash = false}) =>
    ServiceOrder.fromMap('o', {
      'status': status,
      if (usedFreeWash) 'usedFreeWash': true,
    });

/// Takes whether the admin compensated it; returns a test complaint.
Complaint _complaint({bool granted = false}) =>
    Complaint.fromMap('c', {if (granted) 'freeWashGranted': true});

void main() {
  group('LoyaltyController.countCompleted', () {
    test('counts only completed orders', () {
      final count = LoyaltyController.countCompleted([
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.completed,
        OrderStatus.pending,
        OrderStatus.autoCancelled,
      ]);
      expect(count, 2);
    });
  });

  group('LoyaltyProgress card (#68, #70)', () {
    test('a new customer starts with no cars lit', () {
      const progress = LoyaltyProgress(completed: 0);
      expect(progress.filled, 0);
      expect(progress.counter, '0 / 5');
      expect(progress.title, 'مكافأة الولاء');
      expect(progress.message, 'أكمل 5 خدمات للحصول على خدمة تنظيف سيارتك مجانًا');
      expect(progress.hasFreeWash, isFalse);
      expect(progress.availableLabel, isNull);
    });

    test('lights one car per completed service', () {
      const progress = LoyaltyProgress(completed: 2);
      expect(progress.filled, 2);
      expect(progress.message, 'باقي 3 خدمات للحصول على خدمة تنظيف سيارتك مجانًا');
    });

    test('uses the dual and singular forms', () {
      expect(
        const LoyaltyProgress(completed: 3).message,
        'باقي خدمتان للحصول على خدمة تنظيف سيارتك مجانًا',
      );
      expect(
        const LoyaltyProgress(completed: 4).message,
        'باقي خدمة واحدة للحصول على خدمة تنظيف سيارتك مجانًا',
      );
    });
  });

  group('Free washes (#66, #69)', () {
    test('the fifth service earns a wash and starts a new card', () {
      const progress = LoyaltyProgress(completed: 5);
      expect(progress.available, 1);
      expect(progress.filled, 0);
      expect(progress.title, 'مكافأة الولاء');
      expect(progress.availableLabel, 'متاح لك تنظيف السيارة مجانًا');
    });

    test('a used wash is taken off', () {
      const progress = LoyaltyProgress(completed: 6, used: 1);
      expect(progress.available, 0);
      expect(progress.filled, 1);
      expect(progress.hasFreeWash, isFalse);
    });

    test('compensations add to the card washes', () {
      const progress = LoyaltyProgress(completed: 10, compensations: 1);
      expect(progress.available, 3);
      expect(progress.availableLabel, 'متاح لك تنظيف السيارة مجانًا 3 مرات');
    });

    test('says twice for two free washes', () {
      const progress = LoyaltyProgress(completed: 10);
      expect(progress.availableLabel, 'متاح لك تنظيف السيارة مجانًا مرتين');
    });

    test('never goes below zero', () {
      expect(const LoyaltyProgress(completed: 0, used: 2).available, 0);
    });
  });

  group('LoyaltyController.progressFrom', () {
    test('combines orders and compensated complaints', () {
      final progress = LoyaltyController.progressFrom(
        [
          for (var i = 0; i < 5; i++) _order(OrderStatus.completed),
          _order(OrderStatus.completed, usedFreeWash: true),
          _order(OrderStatus.pending),
        ],
        [_complaint(granted: true), _complaint()],
      );
      // 5 paid completed (the free one is not counted): 1 + 1 - 1 = 1.
      expect(progress.completed, 5);
      expect(progress.compensations, 1);
      expect(progress.used, 1);
      expect(progress.available, 1);
    });

    test('a free wash that never happened gives the reward back', () {
      final progress = LoyaltyController.progressFrom(
        [
          _order(OrderStatus.cancelled, usedFreeWash: true),
          _order(OrderStatus.rejected, usedFreeWash: true),
          _order(OrderStatus.autoCancelled, usedFreeWash: true),
        ],
        [_complaint(granted: true)],
      );
      expect(progress.used, 0);
      expect(progress.available, 1);
    });

    test('a free wash in progress is already taken off', () {
      final progress = LoyaltyController.progressFrom(
        [_order(OrderStatus.pending, usedFreeWash: true)],
        [_complaint(granted: true)],
      );
      expect(progress.used, 1);
      expect(progress.available, 0);
    });
  });
}
