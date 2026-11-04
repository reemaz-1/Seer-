import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../controllers/order_history_controller.dart';
import '../models/order.dart';
import '../theme/order_colors.dart';
import '../widgets/location_card.dart';
import '../widgets/order_display.dart';
import '../widgets/plate_number_view.dart';

/// The details of one previous order (#41): the service, customer, vehicle,
/// location, dates and payment. A finished order no longer changes, so the
/// page shows the order it was opened with.
class PastOrderDetailsPage extends StatelessWidget {
  /// Takes the finished [order] and the [addresses] used to show its location.
  const PastOrderDetailsPage({
    super.key,
    required this.order,
    required this.addresses,
  });

  final ServiceOrder order;
  final AddressController addresses;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: CustomerColors.background,
        foregroundColor: CustomerColors.primaryText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                OrderFormat.reference(order.id),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 13,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _header(),
            const SizedBox(height: 16),
            _section(
              title: 'العميل',
              icon: Icons.person_outline,
              child: _infoLine(
                'اسم العميل',
                order.customerName.trim().isEmpty
                    ? 'غير متوفر'
                    : order.customerName.trim(),
              ),
            ),
            const SizedBox(height: 12),
            _vehicleSection(),
            const SizedBox(height: 12),
            if (order.pickupLocation != null)
              LocationCard(
                pickup: order.pickupLocation!,
                dropoff: order.dropoffLocation,
                controller: addresses,
              )
            else
              _section(
                title: 'موقع المركبة',
                icon: Icons.location_on_outlined,
                child: const Text(
                  'موقع المركبة غير متوفر',
                  style: TextStyle(color: CustomerColors.primaryText),
                ),
              ),
            const SizedBox(height: 12),
            _datesSection(),
            const SizedBox(height: 12),
            _paymentSection(),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      ServiceIconTile(
        categoryId: order.serviceCategoryId,
        status: order.status,
        size: 52,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.serviceCategoryLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CustomerColors.primaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              order.serviceOptionLabel,
              style: const TextStyle(
                fontSize: 13,
                color: CustomerColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
      OrderStatusChip(status: order.status),
    ],
  );

  Widget _vehicleSection() {
    final vehicleColor = order.vehicleColor.trim();
    final note = order.note.trim();
    return _section(
      title: 'معلومات المركبة',
      icon: Icons.directions_car_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            order.vehicleTitle.trim().isEmpty
                ? 'المركبة غير محددة'
                : order.vehicleTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CustomerColors.primaryText,
            ),
          ),
          const SizedBox(height: 14),
          _infoLine(
            'لون المركبة',
            vehicleColor.isEmpty ? 'غير محدد' : vehicleColor,
          ),
          const Divider(height: 28, color: CustomerColors.cardBorder),
          const Text(
            'رقم اللوحة',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PlateNumberView.fromStored(
              arabic: order.vehiclePlateArabic,
              latin: order.vehiclePlateLatin,
            ),
          ),
          const Divider(height: 28, color: CustomerColors.cardBorder),
          const Text(
            'ملاحظات العميل',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 6),
          Text(
            note.isEmpty ? 'لا توجد ملاحظات' : note,
            style: const TextStyle(
              fontSize: 15,
              color: CustomerColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _datesSection() => _section(
    title: 'التواريخ',
    icon: Icons.schedule_rounded,
    child: Column(
      children: [
        _infoLine('تاريخ الطلب', _dateTime(order.createdAt)),
        const Divider(height: 28, color: CustomerColors.cardBorder),
        _infoLine('تاريخ القبول', _dateTime(order.acceptedAt)),
        const Divider(height: 28, color: CustomerColors.cardBorder),
        _infoLine(
          OrderHistoryController.finishedLabel(order),
          _dateTime(
            OrderHistoryController.isCompleted(order)
                ? order.completedAt
                : order.cancelledAt,
          ),
        ),
      ],
    ),
  );

  Widget _paymentSection() {
    final completed = OrderHistoryController.isCompleted(order);
    final towing = order.serviceCategoryId == 'towing';
    return _section(
      title: 'الدفع',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _infoLine(
            towing ? 'السعر الأساسي' : 'السعر التقديري',
            OrderFormat.price(order.estimatedPrice),
          ),
          if (completed) ...[
            const Divider(height: 28, color: CustomerColors.cardBorder),
            _infoLine(
              'المبلغ المستلم',
              OrderFormat.price(OrderHistoryController.receivedAmount(order)),
              emphasize: true,
            ),
          ],
          const Divider(height: 28, color: CustomerColors.cardBorder),
          _infoLine('حالة الدفع', OrderHistoryController.paymentText(order)),
        ],
      ),
    );
  }

  /// Takes a [value]; returns its date and time, or a dash when not saved.
  static String _dateTime(DateTime? value) => value == null
      ? '—'
      : '${OrderFormat.date(value)} · ${OrderFormat.time(value)}';

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: CustomerColors.cardBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: CustomerColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _infoLine(String label, String value, {bool emphasize = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 4,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 5,
        child: Text(
          value,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            color: CustomerColors.primaryText,
          ),
        ),
      ),
    ],
  );
}
