import 'dart:async';

import 'package:customer/controllers/customer_alerts_controller.dart';
import 'package:customer/models/customer_notification.dart';
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
}
