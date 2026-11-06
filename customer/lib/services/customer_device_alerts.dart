import 'package:flutter/services.dart';

/// Foreground sounds for customer order updates.
///
/// Talks to the Android code in MainActivity.kt through one channel, with no
/// extra sound packages. Every call is optional: if it
/// fails (or runs on a platform without this code), the app carries on.
class CustomerDeviceAlerts {
  CustomerDeviceAlerts._();

  static const MethodChannel _channel = MethodChannel(
    'seer/notification_sound',
  );

  /// Sound or vibration for the in-app banner, following the phone's mode:
  /// normal = tone only, vibrate = vibration only, silent = nothing.
  static Future<void> playForCurrentMode() async {
    String mode = 'normal';
    try {
      mode = await _channel.invokeMethod<String>('ringerMode') ?? 'normal';
    } catch (_) {
      // Not available (e.g. iOS): treat it as normal.
    }

    try {
      switch (mode) {
        case 'silent':
          return;
        case 'vibrate':
          await _channel.invokeMethod('vibrate');
          return;
        default:
          await _channel.invokeMethod('playNotificationTone');
      }
    } catch (_) {
      // Sound and vibration are optional.
    }
  }
}
