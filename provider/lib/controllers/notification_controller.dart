import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

/// CONTROLLER: the provider's notifications (#47).
///
/// Keeps the live list and the unread count for the bell badge, and calls
/// [onNew] once for each notification that arrives while the app is open,
/// so the screen can show the banner.
class NotificationController extends ChangeNotifier {
  NotificationController({
    required this.providerId,
    NotificationModel? model,
    DateTime Function()? now,
  })  : _model = model ?? NotificationModel(),
        _now = now ?? DateTime.now;

  final String providerId;
  final NotificationModel _model;
  final DateTime Function() _now;

  /// Called with the newest notification that just arrived.
  void Function(AppNotification notification)? onNew;

  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _items = const [];
  final Set<String> _seen = {};
  bool _loadedOnce = false;

  List<AppNotification> get items => _items;

  int get unreadCount => _items.where((n) => !n.read).length;

  /// Starts listening. Safe to call more than once.
  void start() {
    if (_subscription != null || providerId.isEmpty) return;
    // Notifications are extra: if they fail, the rest of the app keeps working.
    try {
      _subscription = _model.watch(providerId).listen(
            _onSnapshot,
            onError: (Object error) => debugPrint('notifications: $error'),
          );
    } catch (error) {
      debugPrint('notifications: $error');
    }
  }

  void _onSnapshot(List<AppNotification> list) {
    final now = _now();
    final arrived = <AppNotification>[];
    for (final n in list) {
      if (_seen.contains(n.id)) continue;
      // On the first load, only requests that can still be answered get a
      // banner. After that, anything new gets one.
      final isNew = _loadedOnce || n.isActive(now);
      if (isNew && !n.read) arrived.add(n);
    }
    _seen.addAll(list.map((n) => n.id));
    _loadedOnce = true;
    _items = list;
    notifyListeners();

    // The list is sorted newest first, so the first arrival is the newest.
    if (arrived.isNotEmpty) onNew?.call(arrived.first);
  }

  /// Marks one notification as read (when its banner or row is tapped).
  Future<void> markRead(AppNotification notification) async {
    if (notification.read) return;
    await _safe(() => _model.markRead([notification.id]));
  }

  /// Marks everything as read (when the notifications page is opened).
  Future<void> markAllRead() async {
    final unread = _items.where((n) => !n.read).map((n) => n.id);
    await _safe(() => _model.markRead(unread));
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('notifications: $error');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
