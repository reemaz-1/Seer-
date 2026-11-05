import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../models/complaint_model.dart';
import '../models/order.dart';

/// CONTROLLER for sending a complaint about a customer (#49).
class ComplaintController extends ChangeNotifier {
  /// Takes an optional [uid], [model] and [auth], mainly used in tests.
  /// When [uid] is not given, the signed-in provider's id is used.
  ComplaintController({String? uid, ComplaintModel? model, FirebaseAuth? auth})
    : _model = model ?? ComplaintModel(),
      _currentUid = uid != null
          ? (() => uid)
          : (() => (auth ?? FirebaseAuth.instance).currentUser?.uid ?? '');

  final ComplaintModel _model;

  /// Reads the provider's id when needed, so Firebase is only used then.
  final String Function() _currentUid;

  /// The signed-in provider's id, or an empty text when nobody is signed in.
  String get uid => _currentUid();

  /// True while a complaint is being sent, so the button can be disabled.
  bool isSending = false;

  bool _disposed = false;

  static const minLength = 10;
  static const maxLength = 500;

  /// The finished orders a provider can complain about: completed ones, and
  /// ones the customer cancelled after this provider accepted them.
  static const complainableStatuses = {
    OrderStatus.completed,
    OrderStatus.cancelled,
  };

  static const emptyError = 'اكتب تفاصيل الشكوى قبل الإرسال.';
  static const tooShortError = 'الشكوى قصيرة جداً، اكتب 10 أحرف على الأقل.';
  static const tooLongError = 'الشكوى طويلة جداً، الحد الأقصى 500 حرف.';
  static const notAllowedError = 'لا يمكن إرسال شكوى على هذا الطلب.';
  static const alreadyExistsError = 'أرسلت شكوى على هذا الطلب مسبقاً.';
  static const sendFailedError =
      'تعذّر إرسال الشكوى. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
  static const busyError = 'جارٍ إرسال الشكوى، انتظر قليلاً.';

  /// Takes the [text] the provider typed; returns null when it is valid,
  /// otherwise the message to show.
  String? validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return emptyError;
    if (trimmed.length < minLength) return tooShortError;
    if (trimmed.length > maxLength) return tooLongError;
    return null;
  }

  /// Takes an [order]; returns true when this provider served it and it is
  /// finished, so a complaint about the customer can be sent.
  bool canComplain(ServiceOrder order) =>
      uid.isNotEmpty &&
      order.providerId == uid &&
      order.customerId.isNotEmpty &&
      complainableStatuses.contains(order.status);

  /// Takes an [orderId]; returns a live stream with the provider's complaint
  /// on it, or null when none was sent.
  Stream<Complaint?> watchComplaint(String orderId) =>
      _model.watchComplaintForOrder(orderId);

  /// Takes the [order] and the complaint [text]; validates and sends it.
  /// Returns null when it worked, or a message to show the provider.
  Future<String?> submit(ServiceOrder order, String text) async {
    // Ignore a second tap while the first one is still sending.
    if (isSending) return busyError;

    final error = validate(text);
    if (error != null) return error;
    if (!canComplain(order)) return notAllowedError;

    _setSending(true);
    try {
      // Copy the order data now, so the admin sees it as it was.
      final complaint = Complaint(
        id: ComplaintModel.idFor(order.id),
        complainantId: uid,
        complainantType: ComplainantType.provider,
        againstId: order.customerId,
        orderId: order.id,
        description: text.trim(),
        status: ComplaintStatus.pending,
        customerName: _orNull(order.customerName),
        customerPhone: _orNull(order.customerPhone),
        providerName: await _loadOwnName(),
        serviceLabel:
            '${order.serviceCategoryLabel} - ${order.serviceOptionLabel}',
        vehicleTitle: _orNull(order.vehicleTitle),
        orderPrice: order.finalPrice ?? order.estimatedPrice,
        orderStatus: order.status,
      );
      await _model.submit(complaint);
      return null;
    } on ComplaintAlreadyExists {
      return alreadyExistsError;
    } catch (_) {
      return sendFailedError;
    } finally {
      _setSending(false);
    }
  }

  /// Takes no inputs; returns the provider's own name, or null if it cannot
  /// be loaded (the complaint is still sent without it).
  Future<String?> _loadOwnName() async {
    try {
      return await _model.providerName(uid);
    } catch (_) {
      return null;
    }
  }

  /// Takes a [value]; returns it trimmed, or null when it is empty.
  static String? _orNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  void _setSending(bool value) {
    isSending = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
