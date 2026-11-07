import 'dart:async';

import 'package:customer/controllers/customer_alerts_controller.dart';
import 'package:customer/models/customer_notification.dart';
import 'package:customer/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

const notice = CustomerNotification(
  id: 'n1',
  orderId: 'o1',
  title: 'تم قبول طلبك',
  body: 'بطارية',
  read: false,
);
void main() {
  late CustomerAlertsController controller;
  late List<bool> modes;
  late List<bool> sounds;
  late List<CustomerNotification> system;
  var permissions = 0;
  setUp(() {
    modes = [];
    sounds = [];
    system = [];
    permissions = 0;
    controller = CustomerAlertsController(
      onBanner: (item, sound) => sounds.add(sound),
      requestPermission: () async {
        permissions++;
      },
      setMode: (on) async {
        modes.add(on);
        return true;
      },
      showSystem: (item) async {
        system.add(item);
      },
    );
  });
  tearDown(() => controller.dispose());
  test('an active order starts the same native keep-alive mode as provider availability', () async {
    await controller.setActive(true);
    await controller.setActive(true);
    expect(permissions, 1);
    expect(modes, [true]);
    await controller.setActive(false);
    expect(modes, [true, false]);
  });
  test(
    'inactive orders do not keep the app running or ask permission',
    () async {
      await controller.setActive(false);
      expect(permissions, 0);
      expect(modes, isEmpty);
    },
  );
  test('foreground alerts use a banner and phone-mode sound without a system duplicate', () async {
    await controller.onNotification(notice);
    expect(sounds, [true]);
    expect(system, isEmpty);
  });
  test('Home and screen lock produce system alerts; resume shows one silent banner', () async {
    await controller.setActive(true);
    await controller.setForeground(false);
    await controller.onNotification(notice);
    expect(system, [notice]);
    expect(sounds, isEmpty);
    await controller.setForeground(true);
    await controller.setForeground(true);
    expect(sounds, [false]);
    expect(modes, [true]);
  });
  test(
    'service is not launched from the background; resume starts it',
    () async {
      await controller.setForeground(false);
      await controller.setActive(true);
      expect(modes, isEmpty);
      await controller.setForeground(true);
      expect(modes, [true]);
    },
  );
  test('completion stops the service even while in background', () async {
    await controller.setActive(true);
    await controller.setForeground(false);
    await controller.setActive(false);
    expect(modes, [true, false]);
  });
  test(
    'signout/disposal stops the service and suppresses late events',
    () async {
      await controller.setActive(true);
      await controller.dispose();
      await controller.onNotification(notice);
      expect(modes, [true, false]);
      expect(system, isEmpty);
      expect(sounds, isEmpty);
    },
  );
  test(
    'signout during permission prompt cannot start a stale service',
    () async {
      await controller.dispose();
      final permission = Completer<void>();
      controller = CustomerAlertsController(
        onBanner: (_, _) {},
        requestPermission: () => permission.future,
        setMode: (on) async {
          modes.add(on);
          return true;
        },
      );
      final start = controller.setActive(true);
      await Future<void>.delayed(Duration.zero);
      final stop = controller.dispose();
      permission.complete();
      await start;
      await stop;
      expect(modes, isEmpty);
    },
  );
  test(
    'failed native startup is retried on the next foreground sync',
    () async {
      await controller.dispose();
      var attempts = 0;
      controller = CustomerAlertsController(
        onBanner: (_, _) {},
        requestPermission: () async {},
        setMode: (on) async {
          modes.add(on);
          return !on || ++attempts > 1;
        },
      );
      await controller.setActive(true);
      await controller.setForeground(false);
      expect(modes, [true]);
      await controller.setForeground(true);
      expect(modes, [true, true]);
      await controller.setActive(false);
      expect(modes, [true, true, false]);
    },
  );
  ServiceOrder order(String status, {String id = 'o1'}) =>
      ServiceOrder.fromMap(id, {'customerId': 'c1', 'status': status});
  CustomerNotification terminal(String status, {String id = 'o1'}) =>
      CustomerNotification(
        id: '${id}_$status',
        orderId: id,
        title: status,
        body: '',
        read: false,
        status: status,
      );

  for (final status in ['completed', 'rejected', 'autoCancelled']) {
    test(
      '$status order snapshot waits for native notification completion',
      () async {
        await controller.dispose();
        final posted = Completer<void>();
        controller = CustomerAlertsController(
          onBanner: (_, _) {},
          requestPermission: () async {},
          setMode: (on) async {
            modes.add(on);
            return true;
          },
          showSystem: (item) async {
            system.add(item);
            await posted.future;
          },
        );
        await controller.setOrders([order('pending')]);
        await controller.setForeground(false);
        await controller.setOrders([order(status)]);
        await controller.setOrders([order(status)]);
        expect(modes, [true]);
        final delivery = controller.onNotification(terminal(status));
        await Future<void>.delayed(Duration.zero);
        expect(system, hasLength(1));
        expect(modes, [true]);
        posted.complete();
        await delivery;
        expect(modes, [true, false]);
        await controller.onNotification(terminal(status));
        expect(system, hasLength(1));
      },
    );
    test(
      '$status notification snapshot can arrive before order snapshot',
      () async {
        await controller.setOrders([order('pending')]);
        await controller.setForeground(false);
        await controller.onNotification(terminal(status));
        expect(modes, [true]);
        await controller.setOrders([order(status)]);
        expect(modes, [true, false]);
      },
    );
  }
  test('one completed order does not stop another active order', () async {
    await controller.setOrders([
      order('accepted'),
      order('accepted', id: 'o2'),
    ]);
    await controller.setForeground(false);
    await controller.setOrders([
      order('completed'),
      order('accepted', id: 'o2'),
    ]);
    await controller.onNotification(terminal('completed'));
    expect(modes, [true]);
  });
  test('admin cancellation event releases the cancelled order hold', () async {
    await controller.setOrders([order('accepted')]);
    await controller.setForeground(false);
    await controller.setOrders([order('cancelled')]);
    expect(modes, [true]);
    await controller.onNotification(
      const CustomerNotification(
        id: 'admin-event',
        orderId: 'o1',
        title: 'cancelled',
        body: '',
        read: false,
        type: 'adminCancellation',
      ),
    );
    expect(modes, [true, false]);
  });
  test(
    'missing legacy final event times out without a permanent service',
    () async {
      await controller.dispose();
      controller = CustomerAlertsController(
        onBanner: (_, _) {},
        requestPermission: () async {},
        setMode: (on) async {
          modes.add(on);
          return true;
        },
        finalNoticeTimeout: const Duration(milliseconds: 30),
      );
      await controller.setOrders([order('accepted')]);
      await controller.setForeground(false);
      await controller.setOrders([order('cancelled')]);
      expect(modes, [true]);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(modes, [true]);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(modes, [true, false]);
    },
  );
  test('logout cancels pending final holds immediately', () async {
    await controller.setOrders([order('accepted')]);
    await controller.setForeground(false);
    await controller.setOrders([order('completed')]);
    await controller.dispose();
    expect(modes, [true, false]);
    await controller.onNotification(terminal('completed'));
    expect(system, isEmpty);
  });
}
