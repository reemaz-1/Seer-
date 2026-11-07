import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/customer_notification.dart';

/// CONTROLLER: owns the customer inbox, unread count and arrival callbacks.
class CustomerNotificationsController extends ChangeNotifier {
  /// Takes the signed-in uid and optional model; creates inbox state.
  CustomerNotificationsController({
    required this.uid,
    CustomerNotificationModel? model,
  }) : _model = model ?? CustomerNotificationModel();
  final String uid;
  final CustomerNotificationModel _model;
  StreamSubscription<List<CustomerNotification>>? _subscription;
  final _seen = <String>{};
  bool _loaded = false;
  bool loading = true;
  String? error;
  List<CustomerNotification> items = const [];
  void Function(CustomerNotification)? onNew;

  /// Returns the number of unread inbox events.
  int get unreadCount => items.where((item) => !item.read).length;

  /// Takes no inputs; starts or retries the inbox subscription.
  void start() {
    _subscription?.cancel();
    loading = true;
    error = null;
    _subscription = _model
        .watch(uid)
        .listen(
          (notices) {
            final fresh = notices
                .where((item) => !item.read && !_seen.contains(item.id))
                .toList();
            _seen.addAll(notices.map((item) => item.id));
            items = notices;
            loading = false;
            error = null;
            notifyListeners();
            // Restored history belongs in the inbox; announce only new arrivals.
            if (_loaded) {
              for (final item in fresh.reversed) {
                onNew?.call(item);
              }
            }
            _loaded = true;
          },
          onError: (Object _) {
            loading = false;
            error = 'تعذر تحميل الإشعارات. تحقق من الاتصال وحاول مرة أخرى.';
            notifyListeners();
          },
        );
  }

  /// Takes an event; persists read=true only if it is unread.
  Future<void> markRead(CustomerNotification item) async {
    if (!item.read) await _model.markRead(item.id);
  }

  /// Takes no inputs; cancels the inbox listener and releases state.
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
