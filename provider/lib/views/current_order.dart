import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/current_order_controller.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

/// The order the provider is working on now (#42, #43), with the button
/// that moves it to its next status (#44) and the payment confirmation
/// when it is completed (#46).
class ProviderCurrentOrder extends StatefulWidget {
  const ProviderCurrentOrder({super.key, this.controller});

  final CurrentOrderController? controller;

  @override
  State<ProviderCurrentOrder> createState() => _ProviderCurrentOrderState();
}

class _ProviderCurrentOrderState extends State<ProviderCurrentOrder> {
  late final CurrentOrderController _controller =
      widget.controller ?? CurrentOrderController();
  late final Stream<ServiceOrder?> _order = _controller.watchCurrentOrder();

  /// True while a status update is being saved, so the button cannot be
  /// pressed twice.
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ServiceOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Message(
            icon: Icons.wifi_off_rounded,
            title: 'تعذر تحميل الطلب',
            subtitle: 'تحقق من الاتصال وحاول مرة أخرى',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final order = snapshot.data;
        if (order == null) {
          return const _Message(
            icon: Icons.assignment_outlined,
            title: 'لا يوجد طلب حالي',
            subtitle: 'ستظهر تفاصيل الطلب هنا عند قبول طلب جديد',
          );
        }
        return _orderDetails(order);
      },
    );
  }

  // ---------------- Layout ----------------

  Widget _orderDetails(ServiceOrder order) {
    final step = CurrentOrderController.stepFor(order.status);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              _serviceCard(order),
              const SizedBox(height: 12),
              _section(
                title: 'العميل',
                children: [
                  _infoRow(
                    Icons.person_outline,
                    order.customerName.isEmpty ? 'غير متوفر' : order.customerName,
                  ),
                  _phoneRow(order.customerPhone),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                title: 'المركبة',
                children: [
                  _infoRow(Icons.directions_car_outlined, order.vehicleTitle),
                  _infoRow(
                    Icons.pin_outlined,
                    '${order.vehiclePlateArabic}   ${order.vehiclePlateLatin}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                title: 'الموقع',
                children: [
                  _infoRow(
                    Icons.location_on_outlined,
                    _locationText(order.pickupLocation),
                  ),
                  if (order.dropoffLocation != null)
                    _infoRow(
                      Icons.flag_outlined,
                      'التسليم: ${_locationText(order.dropoffLocation)}',
                    ),
                ],
              ),
              if (order.note.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _section(
                  title: 'ملاحظة العميل',
                  children: [_infoRow(Icons.notes_rounded, order.note.trim())],
                ),
              ],
              const SizedBox(height: 12),
              _section(
                title: 'السعر',
                children: [
                  _infoRow(
                    Icons.payments_outlined,
                    _priceText(order.estimatedPrice),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (step != null) _actionBar(order, step),
      ],
    );
  }

  Widget _serviceCard(ServiceOrder order) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.serviceCategoryLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              _statusChip(order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.serviceOptionLabel,
            style: const TextStyle(fontSize: 14, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 20),
          _progressBar(order.status),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBorder,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        CurrentOrderController.statusLabels[status] ?? status,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.blue,
        ),
      ),
    );
  }

  /// Four steps: reached ones are filled blue, the rest are grey.
  Widget _progressBar(String status) {
    final int current = CurrentOrderController.progressIndex(status);
    const List<String> steps = CurrentOrderController.progressSteps;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= current
                                ? AppColors.blue
                                : AppColors.cardBorder),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? AppColors.blue : Colors.white,
                        border: Border.all(
                          color: i <= current
                              ? AppColors.blue
                              : AppColors.cardBorder,
                          width: 2,
                        ),
                      ),
                      child: i <= current
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == steps.length - 1
                            ? Colors.transparent
                            : (i < current
                                ? AppColors.blue
                                : AppColors.cardBorder),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrentOrderController.statusLabels[steps[i]] ?? steps[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: i <= current
                        ? AppColors.navy
                        : AppColors.secondaryText,
                    fontWeight:
                        i == current ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  /// The customer's number with a button that opens the phone dialer.
  Widget _phoneRow(String phone) {
    if (phone.isEmpty) return _infoRow(Icons.phone_outlined, 'غير متوفر');
    return Row(
      children: [
        const Icon(Icons.phone_outlined, size: 20, color: AppColors.secondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: AppColors.navy),
          ),
        ),
        TextButton.icon(
          onPressed: () => _call(phone),
          icon: const Icon(Icons.call, size: 18),
          label: const Text('اتصال'),
          style: TextButton.styleFrom(foregroundColor: AppColors.blue),
        ),
      ],
    );
  }

  Widget _actionBar(ServiceOrder order, OrderStep step) {
    final bool completes = step.next == OrderStatus.completed;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _saving
              ? null
              : () => completes ? _complete(order) : _advance(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: completes ? AppColors.success : AppColors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(step.buttonLabel, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  // ---------------- Actions ----------------

  Future<void> _advance(ServiceOrder order) async {
    setState(() => _saving = true);
    final String? error = await _controller.advance(order);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) showAppMessage(context, error);
  }

  /// Asks the provider to confirm they received the payment, then completes
  /// the order (#46).
  Future<void> _complete(ServiceOrder order) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد استلام المبلغ'),
          content: Text(
            order.estimatedPrice == null
                ? 'هل استلمت المبلغ من العميل؟'
                : 'هل استلمت مبلغ ${_priceText(order.estimatedPrice)} من العميل؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('نعم، استلمت'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final String? error = await _controller.complete(order);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showAppMessage(context, error);
    } else {
      showAppMessage(context, 'تم إنهاء الطلب وتأكيد الدفع', isError: false);
    }
  }

  Future<void> _call(String phone) async {
    bool opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      showAppMessage(context, 'تعذر فتح الاتصال على هذا الجهاز');
    }
  }

  // ---------------- Formatting ----------------

  /// The location as coordinates, or a placeholder when the customer has
  /// not set one. Locations are saved as GeoPoint (#15, #16).
  static String _locationText(GeoPoint? location) {
    if (location == null) return 'الموقع غير محدد';
    // \u2066 and \u2069 keep the numbers left-to-right on the Arabic screen.
    return '\u2066${location.latitude.toStringAsFixed(5)}, '
        '${location.longitude.toStringAsFixed(5)}\u2069';
  }

  static String _priceText(num? price) {
    if (price == null) return 'غير محدد';
    final String text = price == price.roundToDouble()
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return '$text ريال';
  }
}

/// Centered icon, title and subtitle for the empty and error states.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF9AA4B8)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF9AA4B8)),
            ),
          ],
        ),
      ),
    );
  }
}
