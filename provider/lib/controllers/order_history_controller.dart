import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import '../models/provider_order_model.dart';

/// CONTROLLER: the provider's previous orders (#40) and their details (#41).
class OrderHistoryController {
  /// Takes an optional [model] and [auth]; both are created on first use,
  /// so building the controller never needs Firebase.
  OrderHistoryController({ProviderOrderModel? model, FirebaseAuth? auth})
    : _injectedModel = model,
      _injectedAuth = auth;

  ProviderOrderModel? _injectedModel;
  final FirebaseAuth? _injectedAuth;

  ProviderOrderModel get _model => _injectedModel ??= ProviderOrderModel();

  /// The live previous orders of the signed-in provider, newest first.
  /// Empty when nobody is signed in.
  Stream<List<ServiceOrder>> watchPastOrders() {
    final uid = (_injectedAuth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _model.watchPastOrders(uid).map(newestFirst);
  }

  /// Takes an [order]; returns true when it was completed by the provider.
  static bool isCompleted(ServiceOrder order) =>
      order.status == OrderStatus.completed;

  /// Takes an [order]; returns when it was completed or cancelled, or when
  /// it was requested if that time is not saved yet.
  static DateTime? finishedAt(ServiceOrder order) =>
      (isCompleted(order) ? order.completedAt : order.cancelledAt) ??
      order.createdAt;

  /// Takes [orders]; returns a new list sorted by [finishedAt], newest first.
  static List<ServiceOrder> newestFirst(List<ServiceOrder> orders) {
    final oldest = DateTime.fromMillisecondsSinceEpoch(0);
    return [...orders]..sort(
      (a, b) => (finishedAt(b) ?? oldest).compareTo(finishedAt(a) ?? oldest),
    );
  }

  /// Takes an [order]; returns the label of its last date.
  static String finishedLabel(ServiceOrder order) =>
      isCompleted(order) ? 'تاريخ الإكمال' : 'تاريخ الإلغاء';

  /// Takes an [order]; returns the amount the provider received, or null
  /// when the order was cancelled.
  static num? receivedAmount(ServiceOrder order) =>
      isCompleted(order) ? (order.finalPrice ?? order.estimatedPrice) : null;

  /// Takes an [order]; returns the payment state shown in its details.
  static String paymentText(ServiceOrder order) {
    if (!isCompleted(order)) return 'لا يوجد مبلغ، ألغى العميل الطلب';
    return order.paymentConfirmed
        ? 'تم تأكيد استلام المبلغ'
        : 'لم يتم تأكيد استلام المبلغ';
  }
}
