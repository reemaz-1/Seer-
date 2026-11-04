import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../models/complaint_model.dart';
import '../models/customer_orders_model.dart';
import '../models/order.dart';

/// CONTROLLER for sending a complaint about a provider (#30).
class ComplaintController extends ChangeNotifier {
  /// Creates the controller.
  /// Parameters: [uid] is the signed-in customer's id; [model] and
  /// [ordersModel] can be injected in tests.
  ComplaintController({
    required this.uid,
    ComplaintModel? model,
    CustomerOrdersModel? ordersModel,
  })  : _model = model ?? ComplaintModel(),
        _ordersModel = ordersModel ?? CustomerOrdersModel();

  final String uid;
  final ComplaintModel _model;
  final CustomerOrdersModel _ordersModel;

  /// True while a complaint is being sent, so the button can be disabled.
  bool isSending = false;

  /// Set when the controller is disposed, so we never notify after that.
  bool _disposed = false;

  static const minLength = 10;
  static const maxLength = 500;

    /// Order statuses that already have a provider assigned.
  static const complainableStatuses = {
    OrderStatus.accepted,
    OrderStatus.onTheWay,
    OrderStatus.arrived,
    OrderStatus.inProgress,
    OrderStatus.completed,
  };

  static const _emptyError = 'اكتب تفاصيل الشكوى قبل الإرسال.';
  static const _tooShortError = 'الشكوى قصيرة جداً، اكتب 10 أحرف على الأقل.';
  static const _tooLongError = 'الشكوى طويلة جداً، الحد الأقصى 500 حرف.';
  static const _notAllowedError = 'لا يمكن إرسال شكوى على هذا الطلب حالياً.';
  static const _alreadyExistsError = 'أرسلت شكوى على هذا الطلب مسبقاً.';
  static const _sendFailedError = 'تعذّر إرسال الشكوى. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
  static const _busyError = 'جارٍ إرسال الشكوى، انتظر قليلاً.';

  /// Checks the complaint text.
  /// Parameters: [text] is what the customer typed.
  /// Returns: null when valid, otherwise the message to show.
  String? validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return _emptyError;
    if (trimmed.length < minLength) return _tooShortError;
    if (trimmed.length > maxLength) return _tooLongError;
    return null;
  }

  /// Tells whether the complaint button should be shown for an order.
  /// Parameters: [order] is the order shown on the page.
  /// Returns: true when a provider is assigned and the status allows it.
  bool canComplain(ServiceOrder order) {
    final providerId = order.providerId;
    return providerId != null &&
        providerId.isNotEmpty &&
        complainableStatuses.contains(order.status);
  }

  /// Listens to the complaint of an order.
  /// Parameters: [orderId] is the order id.
  /// Returns: a stream with the complaint, or null when none was sent.
  Stream<Complaint?> watchComplaint(String orderId) =>
      _model.watchComplaintForOrder(orderId);

  /// Validates and sends a complaint about the order's provider.
  /// Parameters: [order] is the order being complained about; [text] is
  /// the complaint written by the customer.
  /// Returns: null when it worked, or a message to show the customer.
  Future<String?> submit(ServiceOrder order, String text) async {
    // Ignore a second tap while the first one is still sending.
    if (isSending) return _busyError;

    final error = validate(text);
    if (error != null) return error;
    if (!canComplain(order)) return _notAllowedError;

    _setSending(true);
    try {
      final providerId = order.providerId!;
      final providerName = await _loadProviderName(providerId);

      // Copy the order data now, so the admin sees it as it was.
      final complaint = Complaint(
        id: ComplaintModel.idFor(order.id),
        complainantId: uid,
        complainantType: ComplainantType.customer,
        againstId: providerId,
        orderId: order.id,
        description: text.trim(),
        status: ComplaintStatus.pending,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        providerName: providerName,
        serviceLabel:
            '${order.serviceCategoryLabel} - ${order.serviceOptionLabel}',
        vehicleTitle: order.vehicleTitle,
        orderPrice: order.finalPrice ?? order.estimatedPrice,
        orderStatus: order.status,
      );

      await _model.submit(complaint);
      return null;
    } on ComplaintAlreadyExists {
      return _alreadyExistsError;
    } catch (_) {
      return _sendFailedError;
    } finally {
      _setSending(false);
    }
  }

  /// Loads the provider's name for the snapshot.
  /// Parameters: [providerId] is the provider's user id.
  /// Returns: the name, or null if it cannot be loaded (the complaint is
  /// still sent without it).
  Future<String?> _loadProviderName(String providerId) async {
    try {
      final provider = await _ordersModel.getAssignedProvider(providerId);
      final name = provider?.fullName.trim();
      return (name == null || name.isEmpty) ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// Updates the sending flag and refreshes the screen.
  /// Parameters: [value] is the new flag. Returns: nothing.
  void _setSending(bool value) {
    isSending = value;
    if (!_disposed) notifyListeners();
  }

  /// Releases the controller.
  /// Parameters: none. Returns: nothing.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}





