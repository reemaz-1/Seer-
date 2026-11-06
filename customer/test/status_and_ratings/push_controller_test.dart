import 'dart:async';

import 'package:customer/controllers/customer_push_controller.dart';
import 'package:customer/services/customer_push_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class Gateway implements CustomerPushGateway {
  @override
  bool supported = true;
  bool permitted = true;
  bool fail = false;
  bool failDelete = false;
  String token = 'token-one';
  int deletes = 0;
  int permissions = 0;
  PushOrderOpen? initial;
  Completer<void>? registration;
  final registrations = <String>[];
  final previous = <String?>[];
  final refresh = StreamController<String>.broadcast();
  final taps = StreamController<PushOrderOpen>.broadcast();
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<PushOrderOpen> get opened => taps.stream;
  @override
  Future<bool> requestPermission() async {
    permissions++;
    return permitted;
  }

  @override
  Future<String?> getToken() async => token;
  @override
  Future<PushOrderOpen?> initialOpen() async {
    final value = initial;
    initial = null;
    return value;
  }

  @override
  Future<void> register(
    String token,
    String uid, {
    String? previousToken,
  }) async {
    if (registration != null) await registration!.future;
    if (fail) throw StateError('server unavailable');
    registrations.add('$uid:$token');
    previous.add(previousToken);
  }

  @override
  Future<void> deleteToken() async {
    deletes++;
    if (failDelete) throw StateError('offline');
  }

  Future<void> close() async {
    await refresh.close();
    await taps.close();
  }
}

void main() {
  late Gateway gateway;
  late CustomerPushController controller;
  late List<PushOrderOpen> opened;
  setUp(() {
    gateway = Gateway();
    opened = [];
    controller = CustomerPushController(gateway: gateway, onOpen: opened.add);
  });
  tearDown(() async {
    await controller.dispose();
    await gateway.close();
  });
  test('registers one eligible customer and retries an unavailable backend on resume', () async {
    gateway.fail = true;
    await controller.setUser('c1');
    expect(controller.ready, isFalse);
    gateway.fail = false;
    await controller.retry();
    expect(controller.ready, isTrue);
    expect(gateway.registrations, ['c1:token-one']);
  });
  test('denied permission does not register a token', () async {
    gateway.permitted = false;
    await controller.setUser('c1');
    expect(gateway.registrations, isEmpty);
    expect(controller.ready, isFalse);
  });
  test('unsupported platforms keep working without Messaging calls', () async {
    gateway.supported = false;
    await controller.setUser('c1');
    expect(gateway.permissions, 0);
    expect(gateway.registrations, isEmpty);
  });
  test(
    'cold-start and background taps open only the signed-in customer order',
    () async {
      gateway.initial = const PushOrderOpen(orderId: 'cold', recipientId: 'c1');
      await controller.setUser('c1');
      gateway.taps.add(
        const PushOrderOpen(orderId: 'foreign', recipientId: 'c2'),
      );
      gateway.taps.add(
        const PushOrderOpen(orderId: 'background', recipientId: 'c1'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened.map((message) => message.orderId), ['cold', 'background']);
      await controller.setUser(null);
      gateway.taps.add(
        const PushOrderOpen(orderId: 'logged-out', recipientId: 'c1'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened.length, 2);
    },
  );
  test(
    'logout invalidates the old installation before the next account registers',
    () async {
      await controller.setUser('c1');
      await controller.setUser(null);
      await controller.setUser('c2');
      expect(gateway.deletes, 1);
      expect(gateway.registrations, ['c1:token-one', 'c2:token-one']);
    },
  );
  test(
    'token refresh includes the prior token for server-side cleanup',
    () async {
      await controller.setUser('c1');
      gateway.refresh.add('token-two');
      await Future<void>.delayed(Duration.zero);
      await controller.retry();
      expect(gateway.registrations.last, 'c1:token-two');
      expect(gateway.previous.last, 'token-one');
    },
  );
  test(
    'failed token deletion does not prevent the next customer logging in',
    () async {
      await controller.setUser('c1');
      gateway.failDelete = true;
      await controller.setUser('c2');
      expect(gateway.registrations.last, 'c2:token-one');
    },
  );
  test(
    'a logout during registration cannot leave the old account ready',
    () async {
      gateway.registration = Completer<void>();
      final start = controller.setUser('c1');
      await Future<void>.delayed(Duration.zero);
      final stop = controller.setUser(null);
      gateway.registration!.complete();
      await start;
      await stop;
      expect(controller.ready, isFalse);
      expect(gateway.deletes, 1);
    },
  );
  test('unrelated payloads cannot navigate to an order', () {
    expect(
      PushOrderOpen.fromData({'orderId': 'o1', 'recipientId': 'c1'}),
      isNull,
    );
    expect(
      PushOrderOpen.fromData({
        'type': 'orderStatusChanged',
        'orderId': '',
        'recipientId': 'c1',
      }),
      isNull,
    );
  });
}
