import 'package:flutter/material.dart';

import '../controllers/complaint_controller.dart';
import '../controllers/customer_orders_controller.dart';
import '../models/complaint.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import 'app_snackbar.dart';

const _sentMessage = 'تم إرسال الشكوى بنجاح';

/// Opens the complaint sheet and shows a success message when it was sent.
///
/// Parameters: [context] is where the sheet opens; [order] is the order
/// being complained about; [controller] sends the complaint.
/// Returns: nothing.
Future<void> showComplaintSheet({
  required BuildContext context,
  required ServiceOrder order,
  required ComplaintController controller,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true, // lets the sheet rise above the keyboard
    isDismissible: false, // a stray tap outside must not lose the text
    enableDrag: false,
    backgroundColor: CustomerColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    // The sheet opens above the page, so the right-to-left direction of the
    // page does not reach it. Set it here.
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _ComplaintSheet(order: order, controller: controller),
    ),
  );
  if (sent == true && context.mounted) {
    showAppMessage(context, _sentMessage, isError: false);
  }
}

/// VIEW: the complaint button pinned in the top bar of the order page (#30).
/// It is always visible while the order allows a complaint, so an upset
/// customer finds it without searching.
class ComplaintHelpButton extends StatefulWidget {
  /// Creates the button.
  ///
  /// Parameters: [order] is the order first shown on the page; [controller]
  /// gives the order stream and the signed-in customer's id.
  const ComplaintHelpButton({
    super.key,
    required this.order,
    required this.controller,
  });

  final ServiceOrder order;
  final CustomerOrdersController controller;

  /// Creates the button state.
  ///
  /// Parameters: none. Returns: the state object.
  @override
  State<ComplaintHelpButton> createState() => _ComplaintHelpButtonState();
}

class _ComplaintHelpButtonState extends State<ComplaintHelpButton> {
  late final ComplaintController _complaints =
      ComplaintController(uid: widget.controller.uid);

  // Own streams, created once, so the top bar follows the live order status.
  late final Stream<ServiceOrder?> _orderStream =
      widget.controller.watchOrder(widget.order.id);
  late final Stream<Complaint?> _complaintStream =
      _complaints.watchComplaint(widget.order.id);

  static const _label = 'شكوى';
  static const _alreadyPending =
      'سبق أن أرسلت شكوى على هذا الطلب وهي قيد المراجعة. لا يمكن إرسال أكثر من شكوى واحدة لكل طلب.';
  static const _alreadyResolved =
      'سبق أن أرسلت شكوى على هذا الطلب وتمت معالجتها. لا يمكن إرسال أكثر من شكوى واحدة لكل طلب.';
      
  /// Handles a tap: opens the form, or says a complaint already exists.
  ///
  /// Parameters: [order] is the live order; [hasComplaint] tells whether a
  /// complaint was already sent. Returns: nothing.
    /// Handles a tap: opens the form, or explains why a second complaint is
  /// not possible.
  ///
  /// Parameters: [order] is the live order; [complaint] is the complaint
  /// already sent for it, or null. Returns: nothing.
  void _onTap(ServiceOrder order, Complaint? complaint) {
    if (complaint != null) {
      // Tell the status of the first complaint, so the message is true.
      final message = complaint.status == ComplaintStatus.resolved
          ? _alreadyResolved
          : _alreadyPending;
      showAppMessage(context, message, type: AppMessageType.info);
      return;
    }
    showComplaintSheet(context: context, order: order, controller: _complaints);
  }

  /// Builds nothing, or the pill button.
  ///
  /// Parameters: [context] is the build context. Returns: the widget.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ServiceOrder?>(
      stream: _orderStream,
      initialData: widget.order,
      builder: (context, orderSnapshot) {
        // Keep the last known order if live updates fail.
        final order = orderSnapshot.data ?? widget.order;
        if (!_complaints.canComplain(order)) return const SizedBox.shrink();

        return StreamBuilder<Complaint?>(
          stream: _complaintStream,
          builder: (context, complaintSnapshot) {
            final complaint = complaintSnapshot.data;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: TextButton.icon(
                onPressed: () => _onTap(order, complaint),
                icon: const Icon(Icons.support_agent, size: 20),
                label: const Text(_label),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF1FC),
                  foregroundColor: CustomerColors.accent,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Releases the controller.
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void dispose() {
    _complaints.dispose();
    super.dispose();
  }
}

/// VIEW: the status card shown in the order page once a complaint was sent.
class ComplaintSection extends StatefulWidget {
  /// Creates the section.
  ///
  /// Parameters: [order] is the order shown on the page; [uid] is the
  /// signed-in customer's id.
  const ComplaintSection({super.key, required this.order, required this.uid});

  final ServiceOrder order;
  final String uid;

  /// Creates the section state.
  ///
  /// Parameters: none. Returns: the state object.
  @override
  State<ComplaintSection> createState() => _ComplaintSectionState();
}

class _ComplaintSectionState extends State<ComplaintSection> {
  late final ComplaintController _controller =
      ComplaintController(uid: widget.uid);

  // Created once, so the stream is not restarted on every rebuild.
  late final Stream<Complaint?> _complaintStream =
      _controller.watchComplaint(widget.order.id);

  /// Builds the status card, or nothing when there is no complaint.
  ///
  /// Parameters: [context] is the build context. Returns: the widget.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Complaint?>(
      stream: _complaintStream,
      builder: (context, snapshot) {
        final complaint = snapshot.data;
        if (complaint == null) return const SizedBox.shrink();
        return _ComplaintStatusCard(complaint: complaint);
      },
    );
  }

  /// Releases the controller.
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// The card shown after a complaint was sent for the order.
class _ComplaintStatusCard extends StatelessWidget {
  const _ComplaintStatusCard({required this.complaint});

  final Complaint complaint;

  static const _title = 'شكوى على هذا الطلب';
  static const _pendingLabel = 'قيد المراجعة';
  static const _resolvedLabel = 'تمت المعالجة';

  @override
  Widget build(BuildContext context) {
    final resolved = complaint.status == ComplaintStatus.resolved;
    final label = resolved ? _resolvedLabel : _pendingLabel;
    final tint = resolved ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4DB);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  _title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CustomerColors.primaryText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: resolved
                        ? AppStatusColors.success
                        : CustomerColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complaint.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: CustomerColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks the customer to confirm throwing away the text they wrote.
///
/// Parameters: [context] is where the dialog opens.
/// Returns: true when the customer chose to discard.
Future<bool> _confirmDiscard(BuildContext context) async {
  const title = 'تجاهل الشكوى؟';
  const message = 'سيتم حذف ما كتبته.';
  const keepWriting = 'متابعة الكتابة';
  const discard = 'تجاهل';

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: CustomerColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red circle with a bin, centered above the title.
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDECEC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppStatusColors.error,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: CustomerColors.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              // Two equal buttons side by side: keep writing, then discard.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CustomerColors.accent,
                        side: const BorderSide(
                          color: CustomerColors.accent,
                          width: 1.5,
                        ),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(keepWriting),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppStatusColors.error,
                        side: const BorderSide(
                          color: AppStatusColors.error,
                          width: 1.5,
                        ),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(discard),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result == true;
}

/// The bottom sheet where the customer writes the complaint.
class _ComplaintSheet extends StatefulWidget {
  const _ComplaintSheet({required this.order, required this.controller});

  final ServiceOrder order;
  final ComplaintController controller;

  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  final _text = TextEditingController();
  String? _error;

  static const _title = 'شكوى على مزود الخدمة';
  static const _fieldHint =
      'اكتب ما حدث بالتفصيل، مثل تأخر المزود أو مشكلة في الخدمة';
  static const _sendLabel = 'إرسال الشكوى';

  /// Sends the complaint; closes the sheet on success, shows the error if not.
  ///
  /// Parameters: none. Returns: nothing.
  Future<void> _send() async {
    final error = await widget.controller.submit(widget.order, _text.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = error);
    }
  }

  /// Closes the sheet, asking first if the customer already typed something.
  ///
  /// Parameters: none. Returns: nothing.
  Future<void> _requestClose() async {
    // Do not close while the complaint is being sent.
    if (widget.controller.isSending) return;
    if (_text.text.trim().isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    final discard = await _confirmDiscard(context);
    if (discard && mounted) Navigator.pop(context, false);
  }

  /// Builds the sheet content.
  ///
  /// Parameters: [context] is the build context. Returns: the widget.
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final service =
        '${order.serviceCategoryLabel} - ${order.serviceOptionLabel}';

    return PopScope(
      // The back button goes through the same "discard?" check as the X.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final sending = widget.controller.isSending;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            _title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: CustomerColors.primaryText,
                            ),
                          ),
                        ),
                        // Round close button, same size as its tap area.
                        IconButton(
                          onPressed: sending ? null : _requestClose,
                          icon: const Icon(Icons.close, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: CustomerColors.fieldFill,
                            foregroundColor: CustomerColors.primaryText,
                            fixedSize: const Size(36, 36),
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Order summary, so the customer knows which order this is.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CustomerColors.fieldFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CustomerColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: CustomerColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.vehicleTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CustomerColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _text,
                      enabled: !sending,
                      maxLines: 5,
                      minLines: 4,
                      maxLength: ComplaintController.maxLength,
                      style: const TextStyle(
                        fontSize: 15,
                        color: CustomerColors.primaryText,
                      ),
                      onChanged: (_) {
                        // Clear the old message as soon as the customer edits.
                        if (_error != null) setState(() => _error = null);
                      },
                      decoration: InputDecoration(
                        hintText: _fieldHint,
                        // Very light grey, so it reads as an empty draft.
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB8BFCC),
                        ),
                        errorText: _error,
                        filled: true,
                        fillColor: CustomerColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: CustomerColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: CustomerColors.cardBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: CustomerColors.accent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(_sendLabel),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Releases the text controller.
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
