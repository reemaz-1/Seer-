import '../models/complaint.dart';
import '../models/complaint_model.dart';

/// CONTROLLER for the customer's "My complaints" screens.
class MyComplaintsController {
  /// Creates the controller.
  /// Parameters: [uid] is the signed-in customer's id; [model] can be
  /// injected in tests.
  MyComplaintsController({required this.uid, ComplaintModel? model})
      : _model = model ?? ComplaintModel();

  final String uid;
  final ComplaintModel _model;

  static const pendingLabel = 'قيد المراجعة';
  static const resolvedLabel = 'تمت المعالجة';
  static const _pendingMessage = 'وصلت شكواك إلى الإدارة وهي تراجعها الآن.';
  static const _resolvedMessage = 'راجعت الإدارة شكواك وتمت معالجتها.';

  /// Listens to every complaint this customer sent, newest first.
  Stream<List<Complaint>> watchMyComplaints() => _model.watchComplaintsBy(uid);

  /// Listens to one complaint of [orderId], so its status updates live.
  Stream<Complaint?> watchComplaint(String orderId) =>
      _model.watchComplaintForOrder(orderId);

  /// Returns true when the admin already resolved [complaint].
  static bool isResolved(Complaint complaint) =>
      complaint.status == ComplaintStatus.resolved;

  /// Returns the complaints that are still under review.
  static List<Complaint> pendingOf(List<Complaint> complaints) =>
      complaints.where((c) => !isResolved(c)).toList();

  /// Returns the complaints the admin already resolved.
  static List<Complaint> resolvedOf(List<Complaint> complaints) =>
      complaints.where(isResolved).toList();

  /// Returns the Arabic label of a complaint [status].
  static String statusLabel(String status) =>
      status == ComplaintStatus.resolved ? resolvedLabel : pendingLabel;

  /// Returns a short sentence that explains a complaint [status].
  static String statusMessage(String status) =>
      status == ComplaintStatus.resolved ? _resolvedMessage : _pendingMessage;

  /// Formats a date as 2026/11/03 14:05.
  /// A null date means the server has not stamped it yet (just sent).
  static String formatDate(DateTime? date) {
    if (date == null) return 'الآن';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  /// Returns the short order number: first 8 characters, upper case, with #.
  static String orderReference(String orderId) {
    final short = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    return '#${short.toUpperCase()}';
  }

  /// Formats a price with two decimals and the currency.
  static String formatPrice(num? price) =>
      price == null ? '-' : '${price.toStringAsFixed(2)} ر.س';
}