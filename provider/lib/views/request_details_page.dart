import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../controllers/provider_requests_controller.dart';
import '../models/order.dart';
import '../theme/order_colors.dart';
import '../widgets/location_card.dart';
import '../widgets/order_display.dart';
import '../widgets/plate_number_view.dart';
import '../widgets/request_actions.dart';
import '../widgets/app_snackbar.dart';

/// Live request details; customer contact information is not rendered here.
class RequestDetailsPage extends StatelessWidget {
  /// Takes an order id and shared controllers; creates a route returning true on accept.
  const RequestDetailsPage({
    super.key,
    required this.orderId,
    required this.controller,
    required this.addresses,
  });
  final String orderId;
  final ProviderRequestsController controller;
  final AddressController addresses;

  /// Takes [context]; returns live details or a retired-request message.
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final order = controller.availableOrder(orderId);
        return Scaffold(
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
          body: order == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(ProviderRequestsController.unavailableMessage),
                  ),
                )
              : SingleChildScrollView(
                  // Extra bottom space for the phone's navigation bar.
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
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
                      Row(
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
                      ),
                      const SizedBox(height: 16),
                      RequestInformation(
                        order: order,
                        controller: controller,
                        addresses: addresses,
                        detailed: true,
                        showHeader: false,
                      ),
                      const SizedBox(height: 20),
                      RequestActions(
                        order: order,
                        controller: controller,
                        onAccepted: () {
                          if (context.mounted) Navigator.pop(context, true);
                        },
                        onRejected: () {
                          if (context.mounted) Navigator.pop(context, false);
                        },
                        onError: (message) {
                          if (context.mounted) {
                            showAppMessage(
                              context,
                              message,
                              type: message == 'لديك طلب قيد التنفيذ. أكمله قبل قبول طلب جديد.'
                                  ? AppMessageType.warning
                                  : AppMessageType.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    ),
  );
}

/// Shared request information using customer price, plate and date formatting.
class RequestInformation extends StatelessWidget {
  /// Takes an order, controllers and detail flag; creates its information section.
  const RequestInformation({
    super.key,
    required this.order,
    required this.controller,
    required this.addresses,
    this.detailed = false,
    this.showHeader = true,
  });
  final ServiceOrder order;
  final ProviderRequestsController controller;
  final AddressController addresses;
  final bool detailed;
  final bool showHeader;

  /// Takes [context]; returns service, vehicle, addresses, distance and base price.
  @override
  Widget build(BuildContext context) {
    final towing = order.serviceCategoryId == 'towing';
    if (detailed) return _detailsLayout(towing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServiceIconTile(
                categoryId: order.serviceCategoryId,
                status: order.status,
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
                        fontWeight: FontWeight.bold,
                        color: CustomerColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.serviceOptionLabel,
                      style: const TextStyle(
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (showHeader) const SizedBox(height: 16),
        Text(
          order.vehicleTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (detailed) ...[
          const SizedBox(height: 6),
          Text(
            'لون المركبة: ${order.vehicleColor.trim().isEmpty ? 'غير محدد' : order.vehicleColor.trim()}',
            style: const TextStyle(color: CustomerColors.secondaryText),
          ),
        ],
        if (detailed) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PlateNumberView.fromStored(
              arabic: order.vehiclePlateArabic,
              latin: order.vehiclePlateLatin,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ملاحظات العميل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(order.note.trim().isEmpty ? 'لا توجد ملاحظات' : order.note),
        ],
        const SizedBox(height: 16),
        if (order.pickupLocation != null)
          LocationCard(
            pickup: order.pickupLocation!,
            dropoff: towing ? order.dropoffLocation : null,
            controller: addresses,
          )
        else
          const Text('موقع المركبة غير متوفر'),
        if (towing && order.dropoffLocation == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('الوجهة غير متوفرة'),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.near_me_outlined,
              size: 20,
              color: CustomerColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'المسافة إلى المركبة: ${controller.distanceText(order)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${towing ? 'السعر الأساسي' : 'السعر التقديري'}: '
          '${OrderFormat.price(order.estimatedPrice)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (towing)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'لا يشمل رسوم المسافة، وليس السعر النهائي.',
              style: TextStyle(color: CustomerColors.secondaryText),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          '${OrderFormat.date(order.createdAt)} · ${OrderFormat.time(order.createdAt)}',
          style: const TextStyle(
            fontSize: 13,
            color: CustomerColors.secondaryText,
          ),
        ),
      ],
    );
  }

  // Detailed information only: available-request summaries remain unchanged.
  Widget _detailsLayout(bool towing) {
    final vehicleColor = order.vehicleColor.trim();
    final note = order.note.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          title: 'معلومات المركبة',
          icon: Icons.directions_car_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                order.vehicleTitle.isEmpty
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
        ),
        const SizedBox(height: 12),
        // Reuse the same live address widget; no geocoding logic is changed.
        if (order.pickupLocation != null)
          LocationCard(
            pickup: order.pickupLocation!,
            dropoff: towing ? order.dropoffLocation : null,
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
        if (towing && order.dropoffLocation == null) ...[
          const SizedBox(height: 8),
          const Text(
            'الوجهة غير متوفرة',
            style: TextStyle(color: Color(0xFF4B5563)),
          ),
        ],
        const SizedBox(height: 12),
        _section(
          title: 'معلومات الطلب',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              _infoLine('المسافة إلى المركبة', controller.distanceText(order)),
              const Divider(height: 28, color: CustomerColors.cardBorder),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      towing ? 'السعر الأساسي' : 'السعر التقديري',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      OrderFormat.price(order.estimatedPrice),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CustomerColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              if (towing) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'لا يشمل رسوم المسافة، وليس السعر النهائي.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                ),
              ],
              const Divider(height: 28, color: CustomerColors.cardBorder),
              _infoLine(
                'تاريخ الطلب',
                '${OrderFormat.date(order.createdAt)} · ${OrderFormat.time(order.createdAt)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

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
