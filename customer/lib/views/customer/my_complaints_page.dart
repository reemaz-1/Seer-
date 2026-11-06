import 'package:flutter/material.dart';

import '../../controllers/my_complaints_controller.dart';
import '../../models/complaint.dart';
import '../../theme/app_colors.dart';
import '../../widgets/complaint_status_badge.dart';
import 'my_complaint_details_page.dart';

/// VIEW: the customer's list of sent complaints, with their status.
class MyComplaintsPage extends StatefulWidget {
  const MyComplaintsPage({super.key, required this.uid});

  /// The signed-in customer's id.
  final String uid;

  @override
  State<MyComplaintsPage> createState() => _MyComplaintsPageState();
}

class _MyComplaintsPageState extends State<MyComplaintsPage> {
  late final MyComplaintsController _controller;

  // Not final, so "try again" can open a fresh stream after an error.
  late Stream<List<Complaint>> _stream;

  static const _title = 'الشكاوى المرسلة';
  static const _intro = 'تابع حالة الشكاوى التي أرسلتها، واضغط على أي شكوى لعرض تفاصيلها.';
  static const _emptyTitle = 'لا توجد شكاوى';
  static const _emptyMessage = 'يمكنك إرسال شكوى من زر «شكوى» في أعلى صفحة تفاصيل الطلب.';
  static const _errorTitle = 'تعذّر التحميل';
  static const _errorMessage = 'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
  static const _retry = 'إعادة المحاولة';

  @override
  void initState() {
    super.initState();
    _controller = MyComplaintsController(uid: widget.uid);
    _stream = _controller.watchMyComplaints();
  }

  /// Opens a new stream, used by the "try again" button.
  void _reload() {
    setState(() {
      _stream = _controller.watchMyComplaints();
    });
  }

  /// Opens the details page of [complaint].
  void _openDetails(Complaint complaint) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyComplaintDetailsPage(
          controller: _controller,
          complaint: complaint,
        ),
      ),
    );
  }

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
      body: StreamBuilder<List<Complaint>>(
        stream: _stream,
        builder: (context, snapshot) {
          // Error state: say what happened and offer to try again.
          if (snapshot.hasError) {
            return _MessageView(
              icon: Icons.wifi_off_rounded,
              title: _errorTitle,
              message: _errorMessage,
              buttonLabel: _retry,
              onPressed: _reload,
            );
          }
          // Loading state.
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: CustomerColors.accent),
            );
          }

          final complaints = snapshot.data!;

          // Empty state: explain where a complaint can be sent from.
          if (complaints.isEmpty) {
            return const _MessageView(
              icon: Icons.fact_check_outlined,
              title: _emptyTitle,
              message: _emptyMessage,
            );
          }

          // Two groups, like the admin: still open first, then done.
          final pending = MyComplaintsController.pendingOf(complaints);
          final resolved = MyComplaintsController.resolvedOf(complaints);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              const Text(
                _intro,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 18),
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                  title: MyComplaintsController.pendingLabel,
                  count: pending.length,
                ),
                for (final c in pending)
                  _ComplaintCard(complaint: c, onTap: () => _openDetails(c)),
                const SizedBox(height: 8),
              ],
              if (resolved.isNotEmpty) ...[
                _SectionHeader(
                  title: MyComplaintsController.resolvedLabel,
                  count: resolved.length,
                ),
                for (final c in resolved)
                  _ComplaintCard(complaint: c, onTap: () => _openDetails(c)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A section title with the number of complaints in it.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: CustomerColors.primaryText,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: CustomerColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One complaint in the list: the provider, the status, a short preview of
/// the text, the order and the date.
class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint, required this.onTap});

  final Complaint complaint;
  final VoidCallback onTap;

  static const _unknown = 'غير معروف';
  static const _providerRole = 'مقدم الخدمة';
  static const _seeDetails = 'عرض التفاصيل';

  // Purple is the provider colour, the same one the admin list uses.
  static const _providerBackground = Color(0xFFF1EBFB);
  static const _providerForeground = Color(0xFF6B3FA0);

  @override
  Widget build(BuildContext context) {
    final resolved = MyComplaintsController.isResolved(complaint);
    final providerName = (complaint.providerName ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: CustomerColors.fieldFill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: CustomerColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: who the complaint is about + its status.
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _providerBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.handyman_outlined,
                        size: 18,
                        color: _providerForeground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            _providerRole,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _providerForeground,
                            ),
                          ),
                          Text(
                            providerName.isEmpty ? _unknown : providerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: CustomerColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ComplaintStatusBadge(resolved: resolved),
                  ],
                ),
                const SizedBox(height: 12),
                // Short preview of what the customer wrote.
                Text(
                  complaint.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: CustomerColors.primaryText,
                  ),
                ),
                const SizedBox(height: 10),
                // Order number and service.
                Text(
                  '${MyComplaintsController.orderReference(complaint.orderId)}'
                  '  •  ${complaint.serviceLabel ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CustomerColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                // Bottom row: date on one side, "see details" on the other.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        MyComplaintsController.formatDate(complaint.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                    ),
                    const Text(
                      _seeDetails,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: CustomerColors.accent,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: CustomerColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A centered icon, title and message, with an optional button.
/// Used for the empty and error states.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: CustomerColors.secondaryText),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CustomerColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: CustomerColors.secondaryText,
              ),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: CustomerColors.accent,
                ),
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}