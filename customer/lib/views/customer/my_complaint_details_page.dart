import 'package:flutter/material.dart';

import '../../controllers/my_complaints_controller.dart';
import '../../models/complaint.dart';
import '../../theme/app_colors.dart';

/// VIEW: the details of one complaint the customer sent. The status updates
/// by itself if the admin resolves it while this page is open.
class MyComplaintDetailsPage extends StatefulWidget {
  const MyComplaintDetailsPage({
    super.key,
    required this.controller,
    required this.complaint,
  });

  final MyComplaintsController controller;

  /// The complaint as it was in the list; shown until live data arrives.
  final Complaint complaint;

  @override
  State<MyComplaintDetailsPage> createState() => _MyComplaintDetailsPageState();
}

class _MyComplaintDetailsPageState extends State<MyComplaintDetailsPage> {
  // Created once, so the page does not re-subscribe on every rebuild.
  late final Stream<Complaint?> _stream =
      widget.controller.watchComplaint(widget.complaint.orderId);

  static const _title = 'تفاصيل الشكوى';
  static const _complaintTitle = 'نص الشكوى';
  static const _orderTitle = 'تفاصيل الطلب';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor: CustomerColors.darkPanel,
        foregroundColor: Colors.white,
        title: const Text(
          _title,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<Complaint?>(
        stream: _stream,
        initialData: widget.complaint,
        builder: (context, snapshot) {
          // Fall back to the list copy if the live data is not available.
          final complaint = snapshot.data ?? widget.complaint;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              _StatusCard(complaint: complaint),
              const SizedBox(height: 12),
              _InfoCard(
                title: _complaintTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: CustomerColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أُرسلت في ${MyComplaintsController.formatDate(complaint.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: _orderTitle,
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'مقدم الخدمة',
                      value: complaint.providerName,
                    ),
                    _DetailRow(
                      label: 'رقم الطلب',
                      value: MyComplaintsController.orderReference(
                        complaint.orderId,
                      ),
                    ),
                    _DetailRow(label: 'الخدمة', value: complaint.serviceLabel),
                    _DetailRow(label: 'المركبة', value: complaint.vehicleTitle),
                    _DetailRow(
                      label: 'السعر',
                      value: MyComplaintsController.formatPrice(
                        complaint.orderPrice,
                      ),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The big card at the top: the status, one sentence that explains it, and
/// the three steps a complaint goes through.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final resolved = MyComplaintsController.isResolved(complaint);
    final color = resolved ? AppStatusColors.success : const Color(0xFF8A5B00);
    final tint = resolved ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4DB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(
                  resolved
                      ? Icons.check_circle_outline
                      : Icons.hourglass_top_rounded,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MyComplaintsController.statusLabel(complaint.status),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MyComplaintsController.statusMessage(complaint.status),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressSteps(resolved: resolved),
          // Resolved date, shown only after the admin resolved it.
          if (resolved && complaint.resolvedAt != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: CustomerColors.cardBorder),
            const SizedBox(height: 12),
            Text(
              'تمت المعالجة في ${MyComplaintsController.formatDate(complaint.resolvedAt)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: CustomerColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How far a step has gone.
enum _StepState { done, current, todo }

/// Three steps in a row: sent, under review, resolved.
/// The finished steps are green, the current one is amber, the rest grey.
class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.resolved});

  final bool resolved;

  @override
  Widget build(BuildContext context) {
    // A complaint is always sent; the other two depend on the status.
    const sent = _StepState.done;
    final review = resolved ? _StepState.done : _StepState.current;
    final done = resolved ? _StepState.done : _StepState.todo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step(label: 'تم الإرسال', state: sent),
        _StepLine(active: review != _StepState.todo),
        _Step(label: MyComplaintsController.pendingLabel, state: review),
        _StepLine(active: done != _StepState.todo),
        _Step(label: MyComplaintsController.resolvedLabel, state: done),
      ],
    );
  }
}

/// One step: a circle and its label under it.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: state == _StepState.todo
                  ? CustomerColors.secondaryText
                  : CustomerColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the circle that matches [state].
  Widget _dot() {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppStatusColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4DB),
            shape: BoxShape.circle,
            border: Border.all(color: AppStatusColors.warning, width: 2),
          ),
          child: const Icon(
            Icons.hourglass_top_rounded,
            size: 14,
            color: Color(0xFF8A5B00),
          ),
        );
      case _StepState.todo:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: CustomerColors.cardBorder, width: 2),
          ),
        );
    }
  }
}

/// The line between two steps; green once the next step was reached.
class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      // 13 = half of the circle height, so the line is at the circle centre.
      child: Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Container(
          height: 2,
          color: active ? AppStatusColors.success : CustomerColors.cardBorder,
        ),
      ),
    );
  }
}

/// A white card with a title, used for the complaint text and the order.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: CustomerColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// One line of the order card: a grey label and its value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CustomerColors.cardBorder),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: CustomerColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '-' : text,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: CustomerColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}