import 'dart:async';

import '../models/customer_notification.dart';
import '../models/order.dart';
import '../services/customer_device_alerts.dart';

/// CONTROLLER: routes alerts and keeps the service alive until final delivery.
/// Service startup is restricted to the foreground; logout always stops it.
class CustomerAlertsController {
  /// Takes platform callbacks and a bounded final-event wait; creates alert state.
  CustomerAlertsController({
    required this.onBanner,
    this.finalNoticeTimeout = const Duration(seconds: 30),
    Future<void> Function()? requestPermission,
    Future<bool> Function(bool)? setMode,
    Future<void> Function(CustomerNotification)? showSystem,
  }) : _requestPermission =
           requestPermission ?? CustomerDeviceAlerts.requestPermission,
       _setMode = setMode ?? CustomerDeviceAlerts.setOrderUpdatesMode,
       _showSystem =
           showSystem ??
           ((item) => CustomerDeviceAlerts.showSystemNotification(
             id: item.id,
             title: item.title,
             body: item.body,
           ));

  final void Function(CustomerNotification item, bool withSound) onBanner;
  final Future<void> Function() _requestPermission;
  final Future<bool> Function(bool) _setMode;
  final Future<void> Function(CustomerNotification) _showSystem;
  final Duration finalNoticeTimeout;
  final _orderStatuses = <String, String>{};
  final _waiting = <String, Timer>{};
  final _delivered = <String>{};
  final _announced = <String>{};
  int _delivering = 0;
  static const _activeStatuses = {OrderStatus.pending, ...OrderStatus.active};
  static const _terminalStatuses = {
    OrderStatus.completed,
    OrderStatus.rejected,
    OrderStatus.autoCancelled,
    OrderStatus.cancelled,
  };
  bool _foreground = true;
  bool _active = false;
  bool _running = false;
  bool _disposed = false;
  bool _requested = false;
  CustomerNotification? _missed;
  Future<void> _pending = Future.value();

  /// Takes live orders; holds the service across either snapshot delivery order.
  /// A bounded wait covers legacy/self-cancelled orders with no customer event.
  Future<void> setOrders(List<ServiceOrder> orders) {
    if (_disposed) return Future.value();
    for (final order in orders) {
      final previous = _orderStatuses[order.id];
      final key = '${order.id}_${order.status}';
      if (_activeStatuses.contains(previous) &&
          _terminalStatuses.contains(order.status) &&
          !_delivered.contains(key) &&
          !_waiting.containsKey(key)) {
        _waiting[key] = Timer(finalNoticeTimeout, () {
          _waiting.remove(key);
          unawaited(_sync());
        });
      }
      _orderStatuses[order.id] = order.status;
    }
    return setActive(
      orders.any((order) => _activeStatuses.contains(order.status)),
    );
  }

  /// Takes active-order state; synchronizes native tracking without duplicates.
  Future<void> setActive(bool active) {
    _active = active;
    return _sync();
  }

  /// Takes lifecycle visibility; resumes with at most one silent missed banner.
  Future<void> setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      final missed = _missed;
      _missed = null;
      if (!_disposed && missed != null) onBanner(missed, false);
    }
    return _sync();
  }

  /// Takes no inputs; serializes native starts/stops and final-event delivery.
  Future<void> _sync() {
    _pending = _pending
        .then((_) async {
          if (_disposed || (!_active && _waiting.isEmpty && _delivering == 0)) {
            if (_running) {
              if (await _setMode(false)) _running = false;
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
          _running = await _setMode(true);
        })
        .catchError((Object _) {
          // Alert failures must not prevent order updates or signing out.
        });
    return _pending;
  }

  /// Takes an inbox event; delivers it once before releasing any final hold.
  Future<void> onNotification(CustomerNotification item) async {
    if (_disposed || !_announced.add(item.id)) return;
    _delivering++;
    try {
      if (_foreground) {
        onBanner(item, true);
      } else {
        _missed = item;
        await _showSystem(item);
      }
    } catch (_) {
      // Optional platform alerts must not block the order or logout.
    } finally {
      final status =
          item.status ??
          (item.type == 'adminCancellation' ? OrderStatus.cancelled : null);
      if (status != null) {
        final key = '${item.orderId}_$status';
        _delivered.add(key);
        _waiting.remove(key)?.cancel();
      }
      _delivering--;
      await _sync();
    }
  }

  /// Takes no inputs; cancels holds, suppresses late events and stops tracking.
  Future<void> dispose() {
    _disposed = true;
    for (final timer in _waiting.values) {
      timer.cancel();
    }
    _waiting.clear();
    _missed = null;
    return _sync();
  }
}
