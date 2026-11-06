import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/customer_push_gateway.dart';

/// Serializes logout, account switches and token rotation on one installation.
/// A notification tap is accepted only for the current, role-checked customer.
class CustomerPushController {
  CustomerPushController({required this.gateway, required this.onOpen});
  final CustomerPushGateway gateway;
  final void Function(PushOrderOpen) onOpen;
  String? _desiredUid;
  String? _uid;
  String? _token;
  StreamSubscription<String>? _tokens;
  StreamSubscription<PushOrderOpen>? _opens;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  bool ready = false;

  Future<void> _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      try {
        await action();
      } catch (_) {
        ready = false;
        // Do not log tokens or private notification payloads.
        debugPrint('Customer push registration is unavailable.');
      }
    });
    return _queue;
  }

  bool _current(String uid) => !_disposed && _desiredUid == uid && _uid == uid;
  void _open(PushOrderOpen message) {
    if (!_disposed && _uid == _desiredUid && message.recipientId == _uid) {
      onOpen(message);
    }
  }

  Future<void> setUser(String? uid) {
    if (_disposed || !gateway.supported) return Future.value();
    _desiredUid = uid;
    return _enqueue(() async {
      if (_uid == uid || _disposed || _desiredUid != uid) return;
      await _detach();
      if (uid == null || _disposed || _desiredUid != uid) return;
      _uid = uid;
      _tokens = gateway.tokenRefresh.listen((token) {
        _enqueue(() async {
          if (!_current(uid)) return;
          final old = _token;
          await gateway.register(token, uid, previousToken: old);
          if (_current(uid)) {
            _token = token;
            ready = true;
          }
        });
      });
      _opens = gateway.opened.listen(_open);
      // Consume cold-start navigation even if token registration needs retry.
      final initial = await gateway.initialOpen();
      if (initial != null) _open(initial);
      await _register(uid);
    });
  }

  Future<void> _register(String uid) async {
    if (!_current(uid) || !await gateway.requestPermission()) return;
    final token = await gateway.getToken();
    if (token == null || !_current(uid)) return;
    await gateway.register(token, uid, previousToken: _token);
    if (_current(uid)) {
      _token = token;
      ready = true;
    }
  }

  /// Retry a previously unavailable registration after returning to the app.
  Future<void> retry() => _enqueue(() async {
    final uid = _uid;
    if (!ready && uid != null && _current(uid)) await _register(uid);
  });

  Future<void> _detach() async {
    await _tokens?.cancel();
    await _opens?.cancel();
    _tokens = null;
    _opens = null;
    final hadUser = _uid != null;
    _uid = null;
    _token = null;
    ready = false;
    // Invalidating the installation token works even after Auth signed out;
    // stale server registrations then fail delivery and are removed by FCM.
    if (hadUser) {
      try {
        await gateway.deleteToken();
      } catch (_) {
        debugPrint('Customer push token cleanup will need retry.');
      }
    }
  }

  Future<void> dispose() {
    _disposed = true;
    _desiredUid = null;
    return _enqueue(_detach);
  }
}
