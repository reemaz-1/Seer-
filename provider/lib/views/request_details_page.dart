import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../controllers/provider_requests_controller.dart';
import '../models/order.dart';
import '../theme/order_colors.dart';
import '../widgets/location_card.dart';
import '../widgets/order_display.dart';
import '../widgets/plate_number_view.dart';
import '../widgets/request_actions.dart';

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
            title: const Text('تفاصيل الطلب'),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              OrderFormat.reference(order.id),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          OrderStatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 20),
                      RequestInformation(
                        order: order,
                        controller: controller,
                        addresses: addresses,
                        detailed: true,
                      ),
                      const SizedBox(height: 24),
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
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(message)));
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
  });
  final ServiceOrder order;
  final ProviderRequestsController controller;
  final AddressController addresses;
  final bool detailed;

  /// Takes [context]; returns service, vehicle, addresses, distance and base price.
  @override
  Widget build(BuildContext context) {
    final towing = order.serviceCategoryId == 'towing';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    style: const TextStyle(color: CustomerColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          order.vehicleTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
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
}
