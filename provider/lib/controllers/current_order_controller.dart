import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import '../models/provider_order_model.dart';

/// One step the provider can take on the current order (#44).
class OrderStep {
  const OrderStep({required this.next, required this.buttonLabel});

  /// The status the order moves to.
  final String next;

  /// The text on the action button.
  final String buttonLabel;
}

/// CONTROLLER: the current order screen (#42, #43, #44, #46).
class CurrentOrderController {
  CurrentOrderController({ProviderOrderModel? model, FirebaseAuth? auth})
    : _model = model ?? ProviderOrderModel(),
      _auth = auth ?? FirebaseAuth.instance;

  final ProviderOrderModel _model;
  final FirebaseAuth _auth;

  /// The steps shown in the progress bar, in order.
  static const List<String> progressSteps = [
    OrderStatus.onTheWay,
    OrderStatus.arrived,
    OrderStatus.inProgress,
    OrderStatus.completed,
  ];

  /// Arabic text for each status.
  static const Map<String, String> statusLabels = {
    OrderStatus.accepted: 'تم القبول',
    OrderStatus.onTheWay: 'في الطريق',
    OrderStatus.arrived: 'وصلت',
    OrderStatus.inProgress: 'جاري التنفيذ',
    OrderStatus.completed: 'مكتمل',
  };

  /// The only step allowed from each status. Completing is handled
  /// separately by [complete], because it also confirms the payment.
  static const Map<String, OrderStep> _steps = {
    OrderStatus.accepted: OrderStep(
      next: OrderStatus.onTheWay,
      buttonLabel: 'بدأت التوجه للعميل',
    ),
    OrderStatus.onTheWay: OrderStep(
      next: OrderStatus.arrived,
      buttonLabel: 'وصلت للموقع',
    ),
    OrderStatus.arrived: OrderStep(
      next: OrderStatus.inProgress,
      buttonLabel: 'بدء الخدمة',
    ),
    OrderStatus.inProgress: OrderStep(
      next: OrderStatus.completed,
      buttonLabel: 'إنهاء الخدمة',
    ),
  };

  static OrderStep? stepFor(String status) => _steps[status];

  /// How far along the progress bar the order is: -1 before the first
  /// step (just accepted), then 0 to 3.
  static int progressIndex(String status) => progressSteps.indexOf(status);

  /// The live current order of the signed-in provider; null when none.
  Stream<ServiceOrder?> watchCurrentOrder() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _model.watchCurrentOrder(uid);
  }

  /// Moves the order to its next status. Returns an error message, or null
  /// when it worked.
  Future<String?> advance(ServiceOrder order) async {
    final step = stepFor(order.status);
    if (step == null || step.next == OrderStatus.completed) {
      return 'لا يمكن تحديث حالة هذا الطلب.';
    }
    try {
      await _model.advanceStatus(
        orderId: order.id,
        from: order.status,
        to: step.next,
      );
      return null;
    } on StateError {
      return 'تغيرت حالة الطلب، تم تحديث الشاشة.';
    } catch (_) {
      return 'تعذر تحديث حالة الطلب. تحقق من الاتصال وحاول مرة أخرى.';
    }
  }

  /// Completes the order after the provider confirms they received the
  /// payment (#46). Returns an error message, or null when it worked.
  Future<String?> complete(ServiceOrder order) async {
    try {
      await _model.completeWithPayment(
        orderId: order.id,
        amount: order.estimatedPrice,
      );
      return null;
    } on StateError {
      return 'تغيرت حالة الطلب، تم تحديث الشاشة.';
    } catch (_) {
      return 'تعذر إنهاء الطلب. تحقق من الاتصال وحاول مرة أخرى.';
    }
  }
}
