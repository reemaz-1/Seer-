import 'package:flutter/services.dart';

/// Phone-level alerts for customer order updates (#28), written from scratch.
///
/// Talks to the Android code in MainActivity.kt through one channel, with no
/// packages and no Firebase Cloud Messaging. Every call is optional: if it
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

  /// A notification in the status bar and on the lock screen, used while the
  /// app is in the background. Android applies the phone's mode to it.
  static Future<void> showSystemNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('showSystemNotification', {
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Optional.
    }
  }

  /// Turns "order updates mode" on or off: while on, a small fixed notification
  /// shows and Android keeps the app running in the background, so new
  /// order updates can arrive while Android keeps the process running.
  static Future<void> setOrderUpdatesMode(bool on) async {
    try {
      await _channel.invokeMethod('setOrderUpdatesMode', {'on': on});
    } catch (_) {
      // Optional.
    }
  }

  /// Asks once for the notifications permission (Android 13 and later).
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {
      // Optional.
    }
  }
}
