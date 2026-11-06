import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/customer_notification.dart';

class CustomerNotificationsController extends ChangeNotifier {
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
  int get unreadCount => items.where((item) => !item.read).length;

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
            if (_loaded && fresh.isNotEmpty) onNew?.call(fresh.first);
            _loaded = true;
          },
          onError: (Object _) {
            loading = false;
            error = 'تعذر تحميل الإشعارات. تحقق من الاتصال وحاول مرة أخرى.';
            notifyListeners();
          },
        );
  }

  Future<void> markRead(CustomerNotification item) async {
    if (!item.read) await _model.markRead(item.id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
