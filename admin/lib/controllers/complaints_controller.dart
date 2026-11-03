import '../models/complaint.dart';
import '../models/complaints_model.dart';

/// CONTROLLER for the admin complaints screens (#54, #55).
class ComplaintsController {
  /// Creates the controller; [model] can be injected in tests.
  ComplaintsController({ComplaintsModel? model})
      : _model = model ?? ComplaintsModel();

  final ComplaintsModel _model;

  static const _pendingLabel = 'قيد المراجعة';
  static const _resolvedLabel = 'تمت المعالجة';

  /// Arabic names of the order statuses, as the customer app shows them.
  static const _orderStatusLabels = {
    'pending': 'بانتظار مزود خدمة',
    'accepted': 'تم قبول الطلب',
    'onTheWay': 'في الطريق',
    'arrived': 'وصل المزود',
    'inProgress': 'قيد التنفيذ',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
    'rejected': 'مرفوض',
    'autoCancelled': 'ملغي تلقائياً',
  };

    /// Story #54: all complaints, newest first.
  Stream<List<Complaint>> getComplaintsList() => _model.streamAll();

  /// Story #55: one complaint.
  Future<Complaint?> getComplaintDetails(String id) => _model.fetchById(id);

  /// Story #55: how many complaints exist about a provider.
  Future<int> getProviderComplaintCount(String providerId) =>
      _model.countAgainst(providerId);

static const _staleError = 'هذه الشكوى عولجت مسبقاً أو لم تعد موجودة.';
  static const _resolveFailedError =
      'تعذّر تحديث حالة الشكوى. تحقق من الاتصال وحاول مرة أخرى.';

  /// Story #55: follows one complaint live.
  Stream<Complaint?> watchComplaint(String id) => _model.watchById(id);

  /// Story #55: marks a complaint as resolved.
  ///
  /// Parameters: [id] is the complaint document id.
  /// Returns: null when it worked, or a message to show the admin.
  Future<String?> resolveComplaint(String id) async {
    try {
      await _model.markResolved(id);
      return null;
    } on StateError {
      return _staleError;
    } catch (_) {
      return _resolveFailedError;
    }
  }
  
  /// Returns the Arabic label of a complaint status.
  ///
  /// Parameters: [status] is a [ComplaintStatus] value.
  static String statusLabel(String status) =>
      status == ComplaintStatus.resolved ? _resolvedLabel : _pendingLabel;

  /// Returns the Arabic label of an order status (unknown values are shown
  /// as they are).
  ///
  /// Parameters: [status] is an order status, or null when unknown.
  static String orderStatusLabel(String? status) {
    if (status == null || status.isEmpty) return '-';
    return _orderStatusLabels[status] ?? status;
  }

  /// Formats a date as 2026/11/03 14:05.
  ///
  /// Parameters: [date] is the date, or null while the server time is pending.
  /// Returns: the text, or "-" when there is no date yet.
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

   /// Returns the short order number shown to people, like the customer app.
  ///
  /// Parameters: [orderId] is the Firestore order id.
  /// Returns: the first 8 characters in upper case, prefixed by #.
  static String orderReference(String orderId) {
    final short = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    return '#${short.toUpperCase()}';
  }

  /// Formats a price with two decimals and the currency.
  ///
  /// Parameters: [price] is the amount, or null when unknown.
  static String formatPrice(num? price) =>
      price == null ? '-' : '${price.toStringAsFixed(2)} ر.س';
}