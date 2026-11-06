import 'package:flutter/material.dart';

import '../controllers/complaints_controller.dart';
import '../models/complaint.dart';
import '../theme/app_colors.dart';
import 'complaint_detail_screen.dart';

/// VIEW: the list of complaints in the admin dashboard (#54).
class AdminComplaints extends StatefulWidget {
  const AdminComplaints({super.key});

  @override
  State<AdminComplaints> createState() => _AdminComplaintsState();
}

class _AdminComplaintsState extends State<AdminComplaints> {
  final ComplaintsController _controller = ComplaintsController();

  // Created once, so the list is not reloaded on every rebuild.
  late final Stream<List<Complaint>> _stream = _controller.getComplaintsList();

  static const _title = 'الشكاوى';
  static const _pendingTitle = 'قيد المراجعة';
  static const _resolvedTitle = 'تمت المعالجة';
  static const _empty = 'لا توجد شكاوى حالياً';
  static const _loadError = 'تعذّر تحميل الشكاوى. حاول مرة أخرى لاحقاً.';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: StreamBuilder<List<Complaint>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  _loadError,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              );
            }

            final complaints = snapshot.data ?? [];

            // Two groups, like the users page: still open first, then done.
            final pending = complaints
                .where((c) => c.status != ComplaintStatus.resolved)
                .toList();
            final resolved = complaints
                .where((c) => c.status == ComplaintStatus.resolved)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Text(
                        _title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Counter, so the admin knows how many there are.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${complaints.length}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (complaints.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        _empty,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // PENDING SECTION: the ones that still need the admin.
                        if (pending.isNotEmpty) ...[
                          _SectionHeader(
                            title: _pendingTitle,
                            count: pending.length,
                          ),
                          ...pending.map((c) => _ComplaintCard(complaint: c)),
                          const SizedBox(height: 12),
                        ],
                        // RESOLVED SECTION.
                        if (resolved.isNotEmpty) ...[
                          _SectionHeader(
                            title: _resolvedTitle,
                            count: resolved.length,
                          ),
                          ...resolved.map((c) => _ComplaintCard(complaint: c)),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One complaint in the list: who complained about whom, the status and a
/// short preview of the text.
class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  static const _unknown = 'غير معروف';
  static const _customerRole = 'العميل';
  static const _providerRole = 'مقدم الخدمة';
  static const _against = 'على';

  // One colour per role, so the admin recognises them at a glance.
  static const _customerBackground = Color(0xFFEAF1FC);
  static const _customerForeground = Color(0xFF1F5FBF);
  static const _providerBackground = Color(0xFFF1EBFB);
  static const _providerForeground = Color(0xFF6B3FA0);

  /// Builds the coloured label of one side; [isCustomer] picks the role.
  Widget _buildParty({required bool isCustomer, required String? name}) {
    final text = (name ?? '').trim();
    return _PartyChip(
      role: isCustomer ? _customerRole : _providerRole,
      name: text.isEmpty ? _unknown : text,
      icon: isCustomer ? Icons.person_outline : Icons.handyman_outlined,
      background: isCustomer ? _customerBackground : _providerBackground,
      foreground: isCustomer ? _customerForeground : _providerForeground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = complaint.status == ComplaintStatus.resolved;

    // Who submitted the complaint decides which side comes first.
    final byProvider = complaint.complainantType == ComplainantType.provider;

    final customerChip = _buildParty(
      isCustomer: true,
      name: complaint.customerName,
    );
    final providerChip = _buildParty(
      isCustomer: false,
      name: complaint.providerName,
    );

    // The complainant is first (right side in RTL), then the one it is about.
    final complainantChip = byProvider ? providerChip : customerChip;
    final againstChip = byProvider ? customerChip : providerChip;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintDetailScreen(complaintId: complaint.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Who complained about whom, as two coloured labels.
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        complainantChip,
                        const Text(
                          _against,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        againstChip,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(resolved: resolved, status: complaint.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${ComplaintsController.orderReference(complaint.orderId)}'
                '  •  ${complaint.serviceLabel ?? '-'}'
                '  •  ${ComplaintsController.formatDate(complaint.createdAt)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                complaint.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured label showing the complaint status.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.resolved, required this.status});

  final bool resolved;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolved ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4DB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ComplaintsController.statusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: resolved ? AppColors.success : AppColors.primaryText,
        ),
      ),
    );
  }
}

/// A small coloured label for one side of the complaint: its role
/// (customer / provider) in small text, and the name under it.
class _PartyChip extends StatelessWidget {
  const _PartyChip({
    required this.role,
    required this.name,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String role;
  final String name;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Small role label, so it is clear who is who.
              Text(
                role,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              // The person's name.
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A section title with the number of complaints in it, like the users page.
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
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}