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
}
