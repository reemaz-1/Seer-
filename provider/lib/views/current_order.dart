import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/current_order_controller.dart';
import '../controllers/address_controller.dart';
import '../controllers/complaint_controller.dart';
import '../widgets/complaint_section.dart';
import '../widgets/location_card.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/order_colors.dart';
import '../widgets/order_display.dart';
import '../widgets/plate_number_view.dart';
import '../widgets/app_snackbar.dart';
import 'route_to_customer_page.dart';

/// The order the provider is working on now (#42, #43), with the button
/// that moves it to its next status (#44) and the payment confirmation
/// when it is completed (#46).
class ProviderCurrentOrder extends StatefulWidget {
  const ProviderCurrentOrder({super.key, this.controller, this.complaints});

  final CurrentOrderController? controller;

  /// Sends complaints about the customer (#49); mainly used in tests.
  final ComplaintController? complaints;

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
  final AddressController _addresses = AddressController();
  late final ComplaintController _complaints =
      widget.complaints ?? ComplaintController();

  @override
  void dispose() {
    // Only release a controller this screen created itself.
    if (widget.complaints == null) _complaints.dispose();
    super.dispose();
  }

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
        // Complaint button, pinned above the order like the customer app.
        // Keyed by the order, so a new order gets a fresh button.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ComplaintHelpButton(
              key: ValueKey('complaint-${order.id}'),
              order: order,
              controller: _complaints,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              _serviceCard(order),
              ComplaintSection(
                key: ValueKey('complaint-status-${order.id}'),
                order: order,
                controller: _complaints,
              ),
              const SizedBox(height: 12),
              _section(
                title: 'العميل',
                children: [
                  _infoRow(
                    Icons.person_outline,
                    order.customerName.isEmpty ? 'غير متوفر' : order.customerName,
                  ),
                  const Divider(height: 22, color: AppColors.cardBorder),
                  _phoneRow(order.customerPhone),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                title: 'المركبة',
                children: [
                  _detailValueRow(
                    'المركبة',
                    order.vehicleTitle.trim().isEmpty
                        ? 'غير محددة'
                        : order.vehicleTitle,
                  ),
                  const Divider(height: 24, color: AppColors.cardBorder),
                  _detailValueRow(
                    'لون المركبة',
                    order.vehicleColor.trim().isEmpty
                        ? 'غير محدد'
                        : order.vehicleColor.trim(),
                  ),
                  const Divider(height: 24, color: AppColors.cardBorder),
                  const Text(
                    'رقم اللوحة',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PlateNumberView.fromStored(
                      arabic: order.vehiclePlateArabic,
                      latin: order.vehiclePlateLatin,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (order.pickupLocation != null) ...[
                LocationCard(
                  pickup: order.pickupLocation!,
                  dropoff: order.dropoffLocation,
                  controller: _addresses,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.alt_route),
                    label: const Text('عرض المسار إلى العميل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteToCustomerPage(
                          customerLocation: order.pickupLocation!,
                          customerName: order.customerName.isEmpty
                              ? 'العميل'
                              : order.customerName,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                _infoRow(Icons.location_on_outlined, 'الموقع غير محدد'),
              if (order.note.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _section(
                  title: 'ملاحظات العميل',
                  children: [_infoRow(Icons.notes_rounded, order.note.trim())],
                ),
              ],
              const SizedBox(height: 12),
              _section(
                title: 'السعر',
                children: [
                  _detailValueRow('السعر التقديري',
                      _priceText(order.estimatedPrice)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServiceIconTile(categoryId: order.serviceCategoryId,
                  status: order.status, size: 56),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.serviceCategoryLabel,
                      style: const TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: CustomerColors.primaryText)),
                  const SizedBox(height: 4),
                  Text(order.serviceOptionLabel,
                      style: const TextStyle(fontSize: 13,
                          color: CustomerColors.secondaryText)),
                ],
              )),
              _statusChip(order.status),
            ],
          ),
          const SizedBox(height: 16),
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

  /// A single continuous track keeps every progress circle perfectly aligned.
  Widget _progressBar(String status) {
    final int current = CurrentOrderController.progressIndex(status);
    const List<String> steps = CurrentOrderController.progressSteps;
    const double circleSize = 26;
    const double trackHeight = 3;

    return Column(
      children: [
        SizedBox(
          height: circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: circleSize / 2,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < steps.length - 1; i++)
                        Expanded(
                          child: Container(
                            height: trackHeight,
                            color: i < current
                                ? AppColors.blue
                                : AppColors.cardBorder,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Container(
                      width: circleSize,
                      height: circleSize,
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
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Text(
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
              ),
          ],
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
        color: Colors.white,
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
  Widget _detailValueRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(
          fontSize: 13, color: AppColors.secondaryText))),
      Expanded(child: Text(value, textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.navy))),
    ]),
  );

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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      // SafeArea keeps the button above the phone's navigation bar.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
          // The main answer on top and the way back under it, both across
          // the full width so they are centered.
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('نعم، استلمت'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
              ],
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
