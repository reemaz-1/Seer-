import 'package:flutter/material.dart';

import '../controllers/complaints_controller.dart';
import '../models/complaint.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

const _pendingTint = Color(0xFFFFF4DB);
const _resolvedTint = Color(0xFFE6F4EA);
const _blueTint = Color(0xFFEAF1FC);
const _redTint = Color(0xFFFDECEC);
const _softFill = Color(0xFFF7F9FC);

/// Screens at least this wide show two columns.
const _wideFrom = 900.0;
const _maxContentWidth = 1280.0;

/// VIEW: the full details of one complaint for the admin (#55), with a
/// button to mark it as resolved.
class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final ComplaintsController _controller = ComplaintsController();

  // Created once, so the stream is not restarted on every rebuild.
  late final Stream<Complaint?> _stream =
      _controller.watchComplaint(widget.complaintId);

  bool _isResolving = false;

  static const _title = 'تفاصيل الشكوى';
  static const _missing = 'هذه الشكوى لم تعد موجودة';
  static const _loadError = 'تعذّر تحميل الشكوى. حاول مرة أخرى لاحقاً.';
  static const _resolvedMessage = 'تم تحديد الشكوى كمعالجة';

  /// Asks the admin to confirm, then marks the complaint as resolved.
  ///
  /// Parameters: none. Returns: nothing.
  Future<void> _resolve() async {
    final confirmed = await _confirmResolve();
    if (!confirmed || !mounted) return;

    setState(() => _isResolving = true);
    final error = await _controller.resolveComplaint(widget.complaintId);
    if (!mounted) return;
    setState(() => _isResolving = false);

    if (error != null) {
      showAppMessage(context, error);
    } else {
      showAppMessage(context, _resolvedMessage, isError: false);
    }
  }

  /// Shows the confirmation dialog.
  ///
  /// Parameters: none. Returns: true when the admin confirmed.
  Future<bool> _confirmResolve() async {
    const title = 'تحديد الشكوى كمعالجة؟';
    const message = 'سيظهر للعميل أن شكواه تمت معالجتها.';
    const cancel = 'إلغاء';
    const confirm = 'تأكيد';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: _resolvedTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondaryText,
                            side: const BorderSide(
                              color: AppColors.cardBorder,
                              width: 1.5,
                            ),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(confirm),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<Complaint?>(
        stream: _stream,
        builder: (context, snapshot) {
          final complaint = snapshot.data;

          Widget body;
          if (snapshot.hasError) {
            body = const Center(
              child: Text(
                _loadError,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            body = const Center(child: CircularProgressIndicator());
          } else if (complaint == null) {
            body = const Center(
              child: Text(
                _missing,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            );
          } else {
            body = _buildContent(complaint);
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.darkPanel,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(_title),
            ),
            body: body,
            // The action stays visible without scrolling.
            bottomNavigationBar: complaint == null
                ? null
                : _ActionBar(
                    complaint: complaint,
                    isResolving: _isResolving,
                    onResolve: _resolve,
                  ),
          );
        },
      ),
    );
  }

  /// Builds the summary and the cards for a loaded complaint.
  ///
  /// Parameters: [c] is the complaint. Returns: the scrollable content.
  Widget _buildContent(Complaint c) {
    final mainCard = _SectionCard(
      icon: Icons.chat_bubble_outline,
      title: 'نص الشكوى',
      divided: false,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _softFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: SelectableText(
            c.description,
            style: const TextStyle(
              fontSize: 18,
              height: 1.8,
              color: AppColors.primaryText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: 'تاريخ الإرسال',
          value: ComplaintsController.formatDate(c.createdAt),
          ltr: true,
        ),
        if (c.status == ComplaintStatus.resolved)
          _InfoRow(
            label: 'تاريخ المعالجة',
            value: ComplaintsController.formatDate(c.resolvedAt),
            ltr: true,
          ),
      ],
    );

    // Who is the customer and who is the provider depends on who complained.
    final byProvider = c.complainantType == ComplainantType.provider;
    final customerId = byProvider ? c.againstId : c.complainantId;
    final providerId = byProvider ? c.complainantId : c.againstId;

    final sideCards = <Widget>[
      _SectionCard(
        icon: Icons.receipt_long_outlined,
        title: 'الطلب',
        children: [
          _InfoRow(
            label: 'رقم الطلب',
            value: ComplaintsController.orderReference(c.orderId),
            ltr: true,
          ),
          _InfoRow(label: 'المعرّف الكامل', value: c.orderId, ltr: true),
          _InfoRow(label: 'الخدمة', value: c.serviceLabel),
          _InfoRow(label: 'المركبة', value: c.vehicleTitle),
          _InfoRow(
            label: 'السعر',
            value: ComplaintsController.formatPrice(c.orderPrice),
          ),
          _InfoRow(
            label: 'حالة الطلب وقت الشكوى',
            value: ComplaintsController.orderStatusLabel(c.orderStatus),
          ),
        ],
      ),
      _PartyCard(
        icon: Icons.person_outline,
        title: 'العميل',
        subject: 'هذا العميل',
        name: c.customerName,
        phone: c.customerPhone,
        showPhone: true,
        userId: customerId,
        isTarget: byProvider,
        controller: _controller,
      ),
      _PartyCard(
        icon: Icons.support_agent,
        title: 'مزود الخدمة',
        subject: 'هذا المزوّد',
        name: c.providerName,
        userId: providerId,
        isTarget: !byProvider,
        controller: _controller,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryHeader(complaint: c),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < _wideFrom) {
                    // Narrow screen: one column.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [mainCard, ...sideCards],
                    );
                  }
                  // Wide screen: the complaint text on the right (read first in
                  // Arabic), the details on the left.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: mainCard),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: sideCards,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top of the page: which order, who complained about whom, and the status.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.complaint});

  final Complaint complaint;

  static const _unknown = 'غير معروف';

  @override
  Widget build(BuildContext context) {
    final customer = (complaint.customerName ?? '').trim();
    final provider = (complaint.providerName ?? '').trim();

    // Who sent the complaint decides which name comes first.
    final byProvider = complaint.complainantType == ComplainantType.provider;
    final from = (byProvider ? provider : customer);
    final to = (byProvider ? customer : provider);
    final fromRole = byProvider ? 'مقدم الخدمة' : 'العميل';
    final toRole = byProvider ? 'العميل' : 'مقدم الخدمة';

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: _blueTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.report_gmailerrorred_outlined,
            color: AppColors.accent,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'شكوى على الطلب ${ComplaintsController.orderReference(complaint.orderId)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${from.isEmpty ? _unknown : from} ($fromRole)'
                '  ←  ${to.isEmpty ? _unknown : to} ($toRole)',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        _StatusChip(status: complaint.status),
      ],
    );
  }
}

/// Coloured label with the complaint status.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final resolved = status == ComplaintStatus.resolved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: resolved ? _resolvedTint : _pendingTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ComplaintsController.statusLabel(status),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: resolved ? AppColors.success : AppColors.primaryText,
        ),
      ),
    );
  }
}

/// A white card with a round icon and a title.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.divided = true,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// When true a thin line is drawn between the rows.
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (divided && i > 0) {
        rows.add(const Divider(height: 1, color: AppColors.cardBorder));
      }
      rows.add(children[i]);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _blueTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

/// One "label: value" line. [ltr] keeps numbers like phones readable.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.ltr = false});

  final String label;
  final String? value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.trim().isEmpty) ? '-' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SelectableText(
                text,
                textDirection: ltr ? TextDirection.ltr : null,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// A card for one side of the complaint (the customer or the provider).
/// It also loads how many complaints exist about this person, so the admin
/// can spot repeated complaints, whoever sent the current one.
class _PartyCard extends StatefulWidget {
  const _PartyCard({
    required this.icon,
    required this.title,
    required this.subject,
    required this.name,
    required this.userId,
    required this.isTarget,
    required this.controller,
    this.phone,
    this.showPhone = false,
  });

  final IconData icon;

  /// The card title, like "العميل".
  final String title;

  /// Used in the warning sentence, like "هذا العميل".
  final String subject;

  final String? name;
  final String? phone;

  /// True for the customer card, which also shows the phone number.
  final bool showPhone;

  /// The user id of this person (not always the same field of the complaint).
  final String userId;

  /// True when the complaint is about this person.
  final bool isTarget;

  final ComplaintsController controller;

  @override
  State<_PartyCard> createState() => _PartyCardState();
}

class _PartyCardState extends State<_PartyCard> {
  // Counts the complaints written about THIS person, not about the provider.
  late final Future<int> _countFuture =
      widget.controller.getComplaintCountAgainst(widget.userId);

  /// From this number of complaints the person is marked as repeated.
  static const _repeatedFrom = 2;

  static const _targetLabel = 'المشتكى عليه';
  static const _complainantLabel = 'مقدّم الشكوى';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final repeated = count != null && count >= _repeatedFrom;

        return _SectionCard(
          icon: widget.icon,
          title: widget.title,
          children: [
            // Red warning first, because it is the most important thing here.
            if (repeated)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _redTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لدى ${widget.subject} $count شكاوى مسجلة',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Says whether this person sent the complaint or is its target.
            _InfoRow(
              label: 'الدور في الشكوى',
              value: widget.isTarget ? _targetLabel : _complainantLabel,
            ),
            _InfoRow(label: 'الاسم', value: widget.name),
            if (widget.showPhone)
              _InfoRow(label: 'رقم الجوال', value: widget.phone, ltr: true),
            _InfoRow(label: 'المعرّف', value: widget.userId, ltr: true),
            _InfoRow(
              label: 'عدد الشكاوى عليه',
              value: loading ? '...' : (count == null ? '-' : '$count'),
            ),
          ],
        );
      },
    );
  }
}


/// The bar pinned at the bottom: the resolve button, or the resolved notice.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.complaint,
    required this.isResolving,
    required this.onResolve,
  });

  final Complaint complaint;
  final bool isResolving;
  final VoidCallback onResolve;

  static const _pendingTitle = 'هذه الشكوى قيد المراجعة';
  static const _pendingHint = 'راجع بيانات الطلب والمزوّد، ثم حدّدها كمعالجة';
  static const _resolvedTitle = 'تمت معالجة هذه الشكوى';
  static const _buttonLabel = 'تحديد كمعالجة';

  @override
  Widget build(BuildContext context) {
    final resolved = complaint.status == ComplaintStatus.resolved;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
        // A soft shadow so the bar reads as separate from the page.
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1, // the bar is only as tall as its content
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Row(
              children: [
                // Round icon, coloured by the status.
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: resolved ? _resolvedTint : _pendingTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    resolved ? Icons.check_circle : Icons.pending_actions,
                    color: resolved ? AppColors.success : AppColors.warning,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resolved ? _resolvedTitle : _pendingTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: resolved
                              ? AppColors.success
                              : AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resolved
                            ? ComplaintsController.formatDate(
                                complaint.resolvedAt,
                              )
                            : _pendingHint,
                        textDirection: resolved ? TextDirection.ltr : null,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!resolved) ...[
                  const SizedBox(width: 20),
                  FilledButton.icon(
                    onPressed: isResolving ? null : onResolve,
                    icon: isResolving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 22),
                    label: const Text(_buttonLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(0, 58),
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}