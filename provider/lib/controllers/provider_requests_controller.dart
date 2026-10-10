import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order.dart';
import '../models/provider_request_model.dart';
import '../services/provider_location_service.dart';

/// CONTROLLER: live available requests, deadline ticks, GPS and user decisions.
class ProviderRequestsController extends ChangeNotifier {
  /// Takes the signed-in [providerId] and optional dependencies; creates state.
  ProviderRequestsController({
    required this.providerId,
    RequestRepository? repository,
    ProviderLocationSource? location,
    DateTime Function()? now,
  }) : _repository = repository ?? ProviderRequestModel(),
       _location = location ?? ProviderLocationService(providerId: providerId),
       _now = now ?? DateTime.now;

  final String providerId;
  final RequestRepository _repository;
  final ProviderLocationSource _location;
  final DateTime Function() _now;
  final Map<String, ServiceOrder> _orders = {};
  final Set<String> _hidden = {};
  final Set<String> _busy = {};
  StreamSubscription<List<ServiceOrder>>? _subscription;
  StreamSubscription<GeoPoint>? _positions;
  Timer? _timer;
  GeoPoint? _position;
  bool _disposed = false;
  bool _started = false;
  bool loading = true;
  bool locating = false;
  String? _error;
  static const unavailableMessage = 'هذا الطلب لم يعد متاحاً.';

  /// Takes no inputs; returns available orders sorted by their shared deadline.
  List<ServiceOrder> get availableRequests {
    final orders = _orders.values.where(canRespond).toList();
    orders.sort((a, b) {
      final comparison = a.expiresAt!.compareTo(b.expiresAt!);
      return comparison == 0 ? a.id.compareTo(b.id) : comparison;
    });
    return orders;
  }

  /// Takes no inputs; returns and consumes the next SnackBar error message.
  String? takeError() {
    final error = _error;
    _error = null;
    return error;
  }

  /// Takes an [order]; returns whether it is still eligible for this provider.
  bool canRespond(ServiceOrder order) =>
      !_hidden.contains(order.id) &&
      RequestEligibility.canRespond(order, providerId, _now());

  /// Takes [orderId]; returns the live eligible order, or null after removal.
  ServiceOrder? availableOrder(String orderId) {
    final order = _orders[orderId];
    return order != null && canRespond(order) ? order : null;
  }

  /// Takes [orderId]; returns whether a decision is already being submitted.
  bool isBusy(String orderId) => _busy.contains(orderId);

  /// Takes an [order]; returns time until expiresAt, clamped at zero.
  Duration remaining(ServiceOrder order) {
    final value = order.expiresAt?.difference(_now()) ?? Duration.zero;
    return value.isNegative ? Duration.zero : value;
  }

  /// Takes an [order]; returns its remaining fraction of the two-minute window.
  double progress(ServiceOrder order) =>
      (remaining(order).inMilliseconds /
              OrderModel.responseWindow.inMilliseconds)
          .clamp(0.0, 1.0);

  /// Takes an [order]; returns m:ss with ceiling seconds until the true expiry.
  String countdown(ServiceOrder order) {
    final seconds = (remaining(order).inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Takes an [order]; returns GPS-to-pickup kilometres with one decimal.
  String distanceText(ServiceOrder order) {
    final pickup = order.pickupLocation;
    final position = _position;
    if (pickup == null) return 'موقع المركبة غير متوفر';
    if (position == null) return 'المسافة غير متاحة';
    final km =
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          pickup.latitude,
          pickup.longitude,
        ) /
        1000;
    return '${km.toStringAsFixed(1)} كم';
  }

  /// Takes no inputs; subscribes once and starts one-second deadline refreshes.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (providerId.isEmpty) {
      loading = false;
      _error = 'سجّل الدخول لعرض الطلبات المتاحة.';
      _notify();
      return;
    }
    _subscription = _repository
        .watchCandidates(providerId)
        .listen(
          (orders) {
            if (_disposed) return;
            _orders
              ..clear()
              ..addEntries(orders.map((order) => MapEntry(order.id, order)));
            loading = false;
            _notify();
          },
          onError: (Object error) {
            if (_disposed) return;
            _orders.clear();
            loading = false;
            _error =
                'تعذر تحميل الطلبات. تحقق من الاتصال والصلاحيات وحاول مجدداً.';
            _notify();
          },
        );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    unawaited(refreshLocation());
  }

  /// Takes no inputs; refreshes GPS and starts movement updates, keeping orders
  /// usable when permission is denied. Completes after the first location fix.
  Future<void> refreshLocation() async {
    if (_disposed || locating) return;
    locating = true;
    _notify();
    try {
      final position = await _location.current();
      if (_disposed) return;
      _position = position;
      await _positions?.cancel();
      if (_disposed) return;
      _positions = _location.watch().listen(
        (position) {
          _position = position;
          _notify();
        },
        onError: (Object error) {
          _position = null;
          _error = 'تعذر تحديث موقعك. حاول تحديث المسافة مجدداً.';
          _notify();
        },
      );
    } catch (error) {
      if (_disposed) return;
      _position = null;
      _error = error is StateError
          ? error.message.toString()
          : 'تعذر تحديد موقعك. حاول تحديث المسافة مجدداً.';
    } finally {
      locating = false;
      _notify();
    }
  }

  /// Takes [orderId]; returns an Arabic error, or null after atomic acceptance.
  Future<String?> accept(String orderId) => _respond(orderId, accept: true);

  /// Takes [orderId]; returns an Arabic error, or null after atomic rejection.
  Future<String?> reject(String orderId) => _respond(orderId, accept: false);

  /// Takes [orderId] and decision [accept]; guards duplicate taps and returns
  /// an error or null. Successful/obsolete requests disappear immediately.
  Future<String?> _respond(String orderId, {required bool accept}) async {
    if (_disposed || availableOrder(orderId) == null) return unavailableMessage;
    if (!_busy.add(orderId)) return 'جاري إرسال الرد على هذا الطلب.';
    _notify();
    try {
      if (accept) {
        await _repository.accept(orderId, providerId);
      } else {
        await _repository.reject(orderId, providerId);
      }
      _hidden.add(orderId);
      return null;
    } on RequestUnavailable {
      _hidden.add(orderId);
      return unavailableMessage;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return unavailableMessage;
      return 'تعذر إرسال الرد. تحقق من الاتصال وحاول مرة أخرى.';
    } catch (_) {
      return 'تعذر إرسال الرد. تحقق من الاتصال وحاول مرة أخرى.';
    } finally {
      _busy.remove(orderId);
      _notify();
    }
  }

  /// Takes no inputs; refreshes visible state only while this controller lives.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Takes no inputs; cancels snapshots, GPS and ticks, then releases listeners.
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _positions?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
