import 'dart:async';

import 'package:admin/controllers/dashboard_controller.dart';
import 'package:admin/models/dashboard_model.dart';
import 'package:admin/views/admin_main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 23, 12);

/// Takes optional order fields; returns a realistic Firestore record for tests.
Map<String, dynamic> order({
  String customer = 'a',
  String status = 'completed',
  String service = 'battery',
  bool free = false,
  DateTime? created,
  DateTime? completed,
}) => {
  'customerId': customer,
  'status': status,
  'serviceCategoryId': service,
  'usedFreeWash': free,
  'createdAt': Timestamp.fromDate(created ?? now),
  'completedAt': Timestamp.fromDate(completed ?? now),
};

class TestModel extends DashboardModel {
  final source = StreamController<DashboardData>.broadcast();
  int starts = 0;

  /// Takes no arguments; returns a controllable stream with no Firebase connection.
  @override
  Stream<DashboardData> watch() {
    starts++;
    return source.stream;
  }
}

/// Runs dashboard calculations, lifecycle and responsive screen checks.
void main() {
  test('US82 counts customers, all providers and each request once', () {
    final stats = DashboardStats.from(
      DashboardData(
        customers: [{}, {}],
        providers: [
          {'status': 'approved'},
          {'status': 'pending'},
          {'status': 'rejected'},
        ],
        orders: [
          order(),
          order(status: 'cancelled'),
          order(status: 'pending'),
        ],
      ),
      DashboardPeriod.all,
      now,
    );
    expect(
      [
        stats.customers,
        stats.providers,
        stats.approvedProviders,
        stats.orders,
        stats.completedOrders,
      ],
      [2, 3, 1, 3, 1],
    );
  });
  test('US83 groups all five services and preserves unknown categories', () {
    final stats = DashboardStats.from(
      DashboardData(
        orders: [
          for (final service in [
            'battery',
            'battery',
            'fuel',
            'tires',
            'towing',
            'carwash',
            'legacy',
          ])
            order(service: service),
        ],
      ),
      DashboardPeriod.all,
      now,
    );
    expect(stats.services['البطارية'], 2);
    expect(stats.services['غسيل السيارة'], 1);
    expect(stats.services['خدمة أخرى'], 1);
    expect(stats.services.values.reduce((a, b) => a + b), stats.orders);
  });
  test('US84 compensated complaints remain resolved, not a third status', () {
    final stats = DashboardStats.from(
      const DashboardData(
        complaints: [
          {'status': 'pending'},
          {'status': 'resolved'},
          {'status': 'resolved', 'freeWashGranted': true},
        ],
      ),
      DashboardPeriod.all,
      now,
    );
    expect(
      [
        stats.pendingComplaints,
        stats.resolvedComplaints,
        stats.compensatedComplaints,
      ],
      [1, 2, 1],
    );
  });
  test(
    'US85 earns rewards per customer, excluding free and unfinished services',
    () {
      final stats = DashboardStats.from(
        DashboardData(
          orders: [
            for (var i = 0; i < 4; i++) order(customer: 'a'),
            for (var i = 0; i < 4; i++) order(customer: 'b'),
            for (var i = 0; i < 10; i++) order(customer: 'c'),
            order(customer: 'a', free: true),
            order(customer: 'a', status: 'accepted'),
          ],
          complaints: const [
            {'freeWashGranted': true},
            {'freeWashGranted': false},
          ],
        ),
        DashboardPeriod.all,
        now,
      );
      expect(stats.loyaltyGranted, 2); // 4 + 4 must not become another reward.
      expect(stats.compensationGranted, 1);
      expect(stats.washesGranted, 3);
    },
  );
  test('US85 excludes returned washes and includes active reservations', () {
    final stats = DashboardStats.from(
      DashboardData(
        orders: [
          for (final status in [
            'completed',
            'pending',
            'accepted',
            'cancelled',
            'rejected',
            'autoCancelled',
          ])
            order(status: status, free: true, service: 'carwash'),
        ],
      ),
      DashboardPeriod.all,
      now,
    );
    expect(stats.washesUsed, 3);
    expect(stats.loyaltyGranted, 0);
  });
  test(
    'period includes first midnight, excludes older, missing and future dates',
    () {
      final start = DateTime(2026, 11, 17);
      final stats = DashboardStats.from(
        DashboardData(
          orders: [
            order(created: start),
            order(created: start.subtract(const Duration(seconds: 1))),
            order(created: now),
            order(created: now.add(const Duration(seconds: 1))),
            {'status': 'completed', 'serviceCategoryId': 'fuel'},
          ],
        ),
        DashboardPeriod.week,
        now,
      );
      expect(stats.orders, 2);
      expect(stats.dailyOrders.values.reduce((a, b) => a + b), 2);
    },
  );
  test(
    'period reward counts use historical fifth completion, not five new orders',
    () {
      final old = now.subtract(const Duration(days: 20));
      final stats = DashboardStats.from(
        DashboardData(
          orders: [
            for (var i = 0; i < 4; i++) order(created: old, completed: old),
            order(created: old, completed: now),
          ],
          complaints: [
            {
              'freeWashGranted': true,
              'createdAt': Timestamp.fromDate(old),
              'compensatedAt': Timestamp.fromDate(now),
            },
          ],
        ),
        DashboardPeriod.week,
        now,
      );
      expect(stats.orders, 0);
      expect(stats.loyaltyGranted, 1);
      expect(stats.compensationGranted, 1);
    },
  );
  test('empty database returns zeros and seven empty day buckets', () {
    final stats = DashboardStats.from(
      const DashboardData(),
      DashboardPeriod.all,
      now,
    );
    expect(
      [
        stats.customers,
        stats.providers,
        stats.orders,
        stats.washesGranted,
        stats.washesUsed,
      ],
      [0, 0, 0, 0, 0],
    );
    expect(stats.dailyOrders.length, 7);
    expect(stats.services, isEmpty);
    expect(stats.topProviders, isEmpty);
  });
  test('provider ranking excludes unrated and unapproved accounts', () {
    final stats = DashboardStats.from(
      const DashboardData(
        providers: [
          {'id': 'a', 'status': 'approved', 'ratingCount': 2, 'rating': 4.5},
          {'id': 'b', 'status': 'approved', 'ratingCount': 1, 'rating': 2.0},
          {'id': 'c', 'status': 'pending', 'ratingCount': 10, 'rating': 5.0},
          {'id': 'd', 'status': 'approved', 'ratingCount': 0, 'rating': 0},
        ],
      ),
      DashboardPeriod.all,
      now,
    );
    expect(stats.topProviders.map((p) => p['id']), ['a', 'b']);
    expect(stats.lowestProviders.map((p) => p['id']), ['b', 'a']);
  });
  test('live updates and filters recalculate without resubscribing', () async {
    final model = TestModel();
    final controller = DashboardController(model: model, clock: () => now);
    await controller.start();
    model.source.add(
      DashboardData(
        orders: [order(created: now.subtract(const Duration(days: 40)))],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.stats!.orders, 1);
    controller.selectPeriod(DashboardPeriod.week);
    expect(controller.stats!.orders, 0);
    model.source.add(DashboardData(orders: [order()]));
    await Future<void>.delayed(Duration.zero);
    expect(controller.stats!.orders, 1);
    expect(model.starts, 1);
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(model.source.hasListener, false);
    await model.source.close();
  });
  test('read failures clear stale statistics and retry can recover', () async {
    final model = TestModel();
    final controller = DashboardController(model: model);
    await controller.start();
    model.source.add(const DashboardData());
    await Future<void>.delayed(Duration.zero);
    model.source.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.stats, isNull);
    expect(controller.error, contains('صلاحية'));
    await controller.start();
    model.source.add(const DashboardData(customers: [{}], isFromCache: true));
    await Future<void>.delayed(Duration.zero);
    expect(controller.error, isNull);
    expect(controller.stats!.customers, 1);
    expect(controller.isFromCache, true);
    controller.dispose();
    await model.source.close();
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'dashboard renders and filters without overflow at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = TestModel();
        final controller = DashboardController(model: model, clock: () => now);
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: AdminMain(dashboardController: controller),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        model.source.add(
          DashboardData(
            orders: [order()],
            complaints: const [
              {'status': 'pending'},
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('لوحة التحكم'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('آخر 7 أيام'));
        await tester.pumpAndSettle();
        expect(controller.period, DashboardPeriod.week);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await model.source.close();
      },
    );
  }
}
