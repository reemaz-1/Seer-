import 'dart:async';

import '../models/customer_notification.dart';
import '../services/customer_device_alerts.dart';

/// Same native notification mechanism as the provider app. The foreground
/// service runs only while an order is active, and starts only in the foreground.
class CustomerAlertsController {
  CustomerAlertsController({
    required this.onBanner,
    Future<void> Function()? requestPermission,
    Future<void> Function(bool)? setMode,
    Future<void> Function(CustomerNotification)? showSystem,
  }) : _requestPermission =
           requestPermission ?? CustomerDeviceAlerts.requestPermission,
       _setMode = setMode ?? CustomerDeviceAlerts.setOrderUpdatesMode,
       _showSystem =
           showSystem ??
           ((item) => CustomerDeviceAlerts.showSystemNotification(
             title: item.title,
             body: item.body,
           ));

  final void Function(CustomerNotification item, bool withSound) onBanner;
  final Future<void> Function() _requestPermission;
  final Future<void> Function(bool) _setMode;
  final Future<void> Function(CustomerNotification) _showSystem;
  bool _foreground = true;
  bool _active = false;
  bool _running = false;
  bool _disposed = false;
  bool _requested = false;
  CustomerNotification? _missed;
  Future<void> _pending = Future.value();

  Future<void> setActive(bool active) {
    _active = active;
    return _sync();
  }

  Future<void> setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      final missed = _missed;
      _missed = null;
      if (!_disposed && missed != null) onBanner(missed, false);
    }
    return _sync();
  }

  Future<void> _sync() {
    _pending = _pending
        .then((_) async {
          if (_disposed || !_active) {
            if (_running) {
              await _setMode(false);
              _running = false;
            }
            return;
          }
          // Android 12+ does not permit an ordinary foreground-service launch
          // after the app has already moved into the background.
          if (!_foreground || _running) return;
          if (!_requested) {
            _requested = true;
            await _requestPermission();
          }
          if (_disposed || !_active || !_foreground) return;
          await _setMode(true);
          _running = true;
        })
        .catchError((Object _) {
          // Alert failures must not prevent order updates or signing out.
        });
    return _pending;
  }

  Future<void> onNotification(CustomerNotification item) async {
    if (_disposed) return;
    if (_foreground) {
      onBanner(item, true);
    } else {
      _missed = item;
      try {
        await _showSystem(item);
      } catch (_) {
        /* Optional platform alert. */
      }
    }
  }

  Future<void> dispose() {
    _disposed = true;
    _missed = null;
    return _sync();
  }
}
