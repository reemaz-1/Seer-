import 'package:flutter/material.dart';

import '../controllers/complaint_controller.dart';
import '../models/complaint.dart';
import '../models/order.dart';
import '../theme/order_colors.dart';
import 'app_snackbar.dart';
import 'order_display.dart';

const _sentMessage = 'تم إرسال الشكوى بنجاح';

/// Takes the page [context], the [order] and the [controller]; opens the
/// complaint sheet and shows a success message when it was sent.
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

/// VIEW: the complaint part of a previous order's details (#49).
/// Shows a button to complain about the customer, or the status of the
/// complaint once it was sent. Hidden when the order cannot be complained
/// about.
class ComplaintSection extends StatefulWidget {
  /// Takes the finished [order] and an optional [controller]; when no
  /// controller is given, the section creates and releases its own.
  const ComplaintSection({super.key, required this.order, this.controller});

  final ServiceOrder order;
  final ComplaintController? controller;

  @override
  State<ComplaintSection> createState() => _ComplaintSectionState();
}

class _ComplaintSectionState extends State<ComplaintSection> {
  late final ComplaintController _controller =
      widget.controller ?? ComplaintController();

  // Created once, so the stream is not restarted on every rebuild.
  late final Stream<Complaint?> _complaint = _controller.watchComplaint(
    widget.order.id,
  );

  static const _buttonLabel = 'تقديم شكوى على العميل';

  @override
  Widget build(BuildContext context) {
    if (!_controller.canComplain(widget.order)) return const SizedBox.shrink();
    return StreamBuilder<Complaint?>(
      stream: _complaint,
      builder: (context, snapshot) {
        // Wait for the first answer, so the button never flashes before
        // an existing complaint appears.
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final complaint = snapshot.data;
        if (complaint != null) return _ComplaintStatusCard(complaint: complaint);
        return OutlinedButton.icon(
          key: const ValueKey('complain-about-customer'),
          onPressed: () => showComplaintSheet(
            context: context,
            order: widget.order,
            controller: _controller,
          ),
          icon: const Icon(Icons.report_problem_outlined, size: 20),
          label: const Text(_buttonLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppStatusColors.error,
            side: const BorderSide(color: AppStatusColors.error, width: 1.5),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Only release a controller this section created itself.
    if (widget.controller == null) _controller.dispose();
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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

/// Asks the provider to confirm throwing away the text they wrote.
///
/// Parameters: [context] is where the dialog opens.
/// Returns: true when the provider chose to discard.
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

/// The bottom sheet where the provider writes the complaint.
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

  static const _title = 'شكوى على العميل';
  static const _fieldHint =
      'اكتب ما حدث بالتفصيل، مثل عدم تواجد العميل أو مشكلة في الدفع';
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

  /// Closes the sheet, asking first if the provider already typed something.
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
                    // Order summary, so the provider knows which order this is.
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
                            '${order.vehicleTitle}  ·  '
                            '${OrderFormat.reference(order.id)}',
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
                        // Clear the old message as soon as the provider edits.
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
