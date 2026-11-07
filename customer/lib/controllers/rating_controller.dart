import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/rating_model.dart';

/// CONTROLLER: validates customer ratings and translates persistence failures.
class RatingController extends ChangeNotifier {
  /// Takes the signed-in [uid] and optional model; creates rating state.
  RatingController({required this.uid, RatingModel? model})
    : _model = model ?? RatingModel();

  final String uid;
  final RatingModel _model;
  bool isSending = false;
  bool _disposed = false;
  final _submitted = <String>{};

  static const invalidStars = 'اختر تقييمًا من نجمة إلى خمس نجوم.';
  static const notEligible = 'يمكن تقييم مقدم الخدمة بعد اكتمال طلبك فقط.';
  static const alreadyRated = 'سبق أن قيّمت هذا الطلب.';
  static const providerMissing = 'تعذر العثور على مقدم الخدمة.';
  static const sendFailed =
      'تعذر إرسال التقييم. تحقق من الاتصال وحاول مرة أخرى.';
  static const loadFailed =
      'تعذر تحميل تقييمك. تحقق من الاتصال وأعد فتح الطلب.';
  static const busy = 'جارٍ إرسال التقييم، انتظر قليلاً.';

  /// Takes an order; returns whether this customer may rate its provider.
  bool canRate(ServiceOrder order) =>
      order.customerId == uid &&
      order.status == OrderStatus.completed &&
      (order.providerId?.isNotEmpty ?? false);

  /// Takes an order id; returns its saved rating stream.
  Stream<OrderRating?> watch(String orderId) => _model.watch(orderId);

  /// Takes an order id; returns whether this controller already submitted it.
  bool hasSubmitted(String orderId) => _submitted.contains(orderId);

  /// Takes an order and stars; returns null on success or an Arabic message.
  Future<String?> submit(ServiceOrder order, int stars) async {
    if (_disposed) return sendFailed;
    if (isSending) return busy;
    if (stars < 1 || stars > 5) return invalidStars;
    if (!canRate(order)) return notEligible;
    if (hasSubmitted(order.id)) return alreadyRated;
    isSending = true;
    notifyListeners();
    try {
      await _model.submit(orderId: order.id, customerId: uid, stars: stars);
      _submitted.add(order.id);
      return null;
    } on RatingException catch (error) {
      return switch (error.reason) {
        RatingFailure.invalidStars => invalidStars,
        RatingFailure.notEligible => notEligible,
        RatingFailure.alreadyRated => alreadyRated,
        RatingFailure.providerMissing => providerMissing,
      };
    } catch (_) {
      return sendFailed;
    } finally {
      isSending = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Takes no inputs; prevents notifications after the view is disposed.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
