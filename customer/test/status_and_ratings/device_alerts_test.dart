import 'package:customer/services/customer_device_alerts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('seer/notification_sound');
  final calls = <String>[];
  var mode = 'normal';
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'ringerMode' ? mode : true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  for (final entry in {
    'normal': 'playNotificationTone',
    'vibrate': 'vibrate',
    'silent': null,
  }.entries) {
    test('foreground banner respects ${entry.key} phone mode', () async {
      mode = entry.key;
      await CustomerDeviceAlerts.playForCurrentMode();
      expect(calls, ['ringerMode', if (entry.value != null) entry.value]);
    });
  }
  for (final result in [true, false, null]) {
    test('service callback preserves native result $result', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => result);
      expect(
        await CustomerDeviceAlerts.setOrderUpdatesMode(true),
        result == true,
      );
    });
  }
  test('missing native service is reported as failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'unavailable'),
        );
    expect(await CustomerDeviceAlerts.setOrderUpdatesMode(true), false);
  });
  test('system notification carries the stable inbox id', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return true;
        });
    await CustomerDeviceAlerts.showSystemNotification(
      id: 'o1_completed',
      title: 'done',
      body: 'service',
    );
    expect(captured!.arguments, {
      'id': 'o1_completed',
      'title': 'done',
      'body': 'service',
    });
  });
}
