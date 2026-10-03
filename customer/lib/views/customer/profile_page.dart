import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/profile_controller.dart';
import '../../theme/app_colors.dart'; 
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import 'edit_profile_page.dart';
import 'vehicle_form_page.dart';
import 'vehicles_page.dart';

/// VIEW: customer profile (user story #5) + entry points to edit (#6),
/// vehicles (#7–#10) and logout (#3).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.uid});

  final String uid;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _controller = ProfileController();

  @override
  void initState() {
    super.initState();
    _controller.load(widget.uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------- Actions ----------------

  Future<void> _openEdit(Customer customer) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(controller: _controller, customer: customer),
      ),
    );
    if (saved == true && mounted) {
      _showMessage('تم حفظ التعديلات');
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await _confirm(
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من حسابك؟',
      confirmLabel: 'تسجيل الخروج',
      danger: true,
    );
    if (!ok) return;

    debugPrint('🔴 logout button pressed, calling signOut...');

    try {
      await _controller.logout().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('🔴 signOut TIMED OUT after 8 seconds');
          throw Exception('انتهت المهلة — signOut علّق أكثر من 8 ثواني');
        },
      );
      debugPrint('🟢 signOut finished successfully');
    } catch (e) {
      debugPrint('🔴 signOut threw an error: $e');
      if (mounted) _showMessage('خطأ: $e');
      return;
    }

    if (!mounted) return;
  }

  Future<void> _openVehicles() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehiclesPage(uid: widget.uid)),
    );
    _controller.refreshVehicles(widget.uid);
  }

  /// Pass a vehicle to edit it, or nothing to add a new one.
  Future<void> _openVehicleForm([Vehicle? vehicle]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VehicleFormPage(uid: widget.uid, vehicle: vehicle),
      ),
    );
    if (message == null || !mounted) return;
    _controller.refreshVehicles(widget.uid);
    _showMessage(message);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? AppStatusColors.error : CustomerColors.accent,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar icons on the navy header
      child: Scaffold(
        backgroundColor: CustomerColors.background,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final customer = _controller.customer;

            if (customer == null) {
              if (_controller.errorMessage != null) {
                return _ErrorView(
                  message: _controller.errorMessage!,
                  onRetry: () => _controller.load(widget.uid),
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: CustomerColors.accent),
              );
            }

            return RefreshIndicator(
              color: CustomerColors.accent,
              onRefresh: () => _controller.load(widget.uid),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _Header(customer: customer),
                  Transform.translate(
                    offset: const Offset(0, 0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: Column(
                        children: [
                          _SectionCard(
                            title: 'المعلومات الشخصية',
                            actionLabel: 'تعديل',
                            onAction: () => _openEdit(customer),
                            child: Column(
                              children: [
                                _FieldRow(label: 'الاسم الأول', value: customer.firstName),
                                _FieldRow(label: 'اسم العائلة', value: customer.lastName),
                                _FieldRow(label: 'رقم الجوال', value: customer.phone, ltr: true),
                                _FieldRow(
                                  label: 'البريد الإلكتروني',
                                  value: customer.email,
                                  ltr: true,
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'مركباتي',
                            actionLabel: 'إدارة',
                            onAction: _openVehicles,
                            child: _VehiclesList(
                              vehicles: _controller.vehicles,
                              onTapVehicle: (vehicle) => _openVehicleForm(vehicle),
                              onAdd: () => _openVehicleForm(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            child: Column(
                              children: [
                                _ActionRow(
                                  icon: Icons.logout,
                                  label: 'تسجيل الخروج',
                                  danger: true,
                                  showDivider: false,
                                  onTap: _confirmLogout,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// Small private widgets used only by this page
// ============================================================

class _Header extends StatelessWidget {
  const _Header({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      color: CustomerColors.darkPanel,
      padding: EdgeInsets.fromLTRB(18, topInset + 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CustomerColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  customer.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final Widget child;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: CustomerColors.fieldFill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: CustomerColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Row(
            children: [
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: CustomerColors.primaryText,
                ),
              ),
              const Spacer(),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: CustomerColors.accent,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        child,
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.ltr = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool ltr;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: CustomerColors.cardBorder)),
            )
          : null,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CustomerColors.primaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: isRtl ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: CustomerColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclesList extends StatelessWidget {
  const _VehiclesList({
    required this.vehicles,
    required this.onTapVehicle,
    required this.onAdd,
  });

  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onTapVehicle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'أضف مركبتك لتتمكن من طلب الخدمات لها',
              style: TextStyle(fontSize: 13, color: CustomerColors.secondaryText),
            ),
          ),
        for (var i = 0; i < vehicles.length; i++)
          _VehicleTile(
            vehicle: vehicles[i],
            showDivider: i < vehicles.length - 1,
            onTap: () => onTapVehicle(vehicles[i]),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'إضافة مركبة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: CustomerColors.accent,
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: Color(0xFFC7CEDC), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.onTap,
    this.showDivider = true,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: CustomerColors.cardBorder)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CustomerColors.darkPanel,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model} ${vehicle.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'لوحة ${vehicle.plateNumberArabic}',
                    style: const TextStyle(fontSize: 12, color: CustomerColors.secondaryText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: CustomerColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppStatusColors.error : CustomerColors.primaryText;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: CustomerColors.cardBorder)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger ? AppStatusColors.error.withOpacity(0.12) : CustomerColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            if (!danger) const Icon(Icons.chevron_right, color: CustomerColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: CustomerColors.secondaryText),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: CustomerColors.secondaryText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: CustomerColors.accent),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}