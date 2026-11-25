import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/customer_orders_model.dart';
import '../models/order.dart';

/// CONTROLLER for the customer's orders pages (user stories #24-#26).
class CustomerOrdersController extends ChangeNotifier {
  /// Creates the controller.
  ///
  /// Parameters: [uid] is the signed-in customer's id; [model] can be
  /// injected in tests.
  CustomerOrdersController({
    required this.uid,
    CustomerOrdersModel? model,
  }) : _model = model ?? CustomerOrdersModel();

  final String uid;
  final CustomerOrdersModel _model;
  StreamSubscription<List<ServiceOrder>>? _subscription;

  /// Fires at the nearest expiresAt of a pending order (#21).
  Timer? _autoCancelTimer;

  /// Orders whose auto-cancel is running now, so none is sent twice.
  final Set<String> _autoCancelling = {};

  /// Small delay added to the timer so it never fires just before expiresAt.
  static const _timerMargin = Duration(milliseconds: 500);

  List<ServiceOrder> orders = [];
  bool isLoading = true;
  String? errorMessage;

  static const _loadError =
      'تعذّر تحميل الطلبات. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';

  /// Statuses of orders that are still open (waiting or being served).
  static const currentStatuses = {
    OrderStatus.scheduledPending,
    OrderStatus.scheduledAccepted,
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.onTheWay,
    OrderStatus.arrived,
    OrderStatus.inProgress,
  };

  /// Returns the open orders, newest first.
  List<ServiceOrder> get currentOrders =>
      orders.where((order) => currentStatuses.contains(order.status)).toList();

  /// Returns the completed, cancelled and rejected orders, newest first.
  List<ServiceOrder> get pastOrders =>
      orders.where((order) => !currentStatuses.contains(order.status)).toList();

  /// Starts (or restarts) listening to the customer's orders.
  ///
  /// Parameters: none.
  /// Returns: nothing; listeners are notified whenever the list, the
  /// loading state or the error message changes.
  void start() {
    _subscription?.cancel();
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription = _model.watchCustomerOrders(uid).listen(
      (result) {
        orders = result;
        _scheduleAutoCancel();
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        isLoading = false;
        errorMessage = _loadError;
        notifyListeners();
      },
    );
  }

  /// Streams one order for the details page.
  ///
  /// Parameters: [orderId] is the order document id.
  /// Returns: a stream of the order, or null once it no longer exists.
  Stream<ServiceOrder?> watchOrder(String orderId) =>
      _model.watchOrder(orderId);

  /// Loads the provider assigned to an order.
  ///
  /// Parameters: [providerId] is the provider's user id.
  /// Returns: the provider summary, or null if it cannot be found.
  Future<AssignedProvider?> getAssignedProvider(String providerId) =>
      _model.getAssignedProvider(providerId);

  /// Stops listening to Firestore and releases the controller.
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void dispose() {
    _subscription?.cancel();
    _autoCancelTimer?.cancel();
    super.dispose();
  }

  static const _cancelExpired =
      'لم يعد بالإمكان إلغاء هذا الطلب، تم تحديث الصفحة.';
  static const _cancelFailed =
      'تعذر إلغاء الطلب. تحقق من الاتصال وحاول مرة أخرى.';

  /// Tells whether the customer can cancel an order now (#20).
  ///
  /// Parameters: [order] is the order to check.
  /// Returns: true when the cancel button should be shown.
  bool canCancel(ServiceOrder order) =>
      CustomerOrdersModel.canCancel(order, DateTime.now());

  /// Returns the time left to cancel an accepted order (#20).
  ///
  /// Parameters: [order] is the order to check.
  /// Returns: the time left, or null when there is no countdown.
  Duration? cancelTimeLeft(ServiceOrder order) =>
      CustomerOrdersModel.cancelTimeLeft(order, DateTime.now());

  /// Cancels an order (#20).
  ///
  /// Parameters: [orderId] is the order to cancel.
  /// Returns: null when it worked, or a message to show the customer.
  Future<String?> cancelOrder(String orderId) async {
    try {
      await _model.cancelOrder(orderId);
      return null;
    } on StateError {
      return _cancelExpired;
    } catch (_) {
      return _cancelFailed;
    }
  }

  /// Returns how much of the cancel window is left, for the progress
  /// shown inside the cancel button (#20).
  ///
  /// Parameters: [order] is the order to check.
  /// Returns: a value from 0 to 1, or null when there is no countdown.
  double? cancelProgress(ServiceOrder order) {
    final left = cancelTimeLeft(order);
    if (left == null) return null;
    final total = CustomerOrdersModel.cancelWindow.inMilliseconds;
    return (left.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Auto-cancels expired pending orders and sets a timer for the next one
  /// (#21).
  ///
  /// Orders already past expiresAt are cancelled now, which covers a
  /// customer who closed the app and opened it later. For the others, one
  /// timer is set on the nearest expiresAt, so an open app cancels the order
  /// on time.
  ///
  /// Parameters: none. Returns: nothing.
  void _scheduleAutoCancel() {
    _autoCancelTimer?.cancel();
    _autoCancelTimer = null;

    final now = DateTime.now();
    DateTime? nextExpiry;
    for (final order in orders) {
      final expiresAt = order.status == OrderStatus.scheduledPending
          ? order.scheduledAt : order.expiresAt;
      if (!const [OrderStatus.pending, OrderStatus.scheduledPending]
              .contains(order.status) || expiresAt == null) continue;
      if (CustomerOrdersModel.isExpired(order, now)) {
        _autoCancel(order.id);
      } else if (nextExpiry == null || expiresAt.isBefore(nextExpiry)) {
        nextExpiry = expiresAt;
      }
    }
    if (nextExpiry == null) return;
    _autoCancelTimer =
        Timer(nextExpiry.difference(now) + _timerMargin, _scheduleAutoCancel);
  }

  /// Auto-cancels one order and ignores failures (#21).
  ///
  /// Parameters: [orderId] is the order to cancel.
  /// Returns: nothing. The orders stream emits the new status by itself.
  Future<void> _autoCancel(String orderId) async {
    if (!_autoCancelling.add(orderId)) return;
    try {
      await _model.autoCancelIfExpired(orderId);
    } catch (e) {
      debugPrint('autoCancel failed: $e');
    } finally {
      _autoCancelling.remove(orderId);
    }
  }
}
