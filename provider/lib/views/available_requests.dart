import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../controllers/provider_requests_controller.dart';
import '../theme/order_colors.dart';
import '../widgets/order_display.dart';
import 'request_details_page.dart';

/// Available requests, refreshed when time alone passes the shared expiry.
class AvailableRequests extends StatelessWidget {
  /// Takes shared controllers and the current-tab callback; creates the list.
  const AvailableRequests({
    super.key,
    required this.controller,
    required this.addresses,
    required this.onAccepted,
  });
  final ProviderRequestsController controller;
  final AddressController addresses;
  final VoidCallback onAccepted;

  /// Takes [context]; returns the loading, empty or available-requests list.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final orders = controller.availableRequests;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'الطلبات المتاحة (${orders.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'تحديث الموقع والمسافة',
                  onPressed: controller.locating
                      ? null
                      : controller.refreshLocation,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد طلبات متاحة حالياً',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Container(
                        key: ValueKey(order.id),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CustomerColors.background,
                          border: Border.all(color: CustomerColors.cardBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                OrderStatusChip(status: order.status),
                                const Spacer(),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    controller.countdown(order),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            RequestInformation(
                              order: order,
                              controller: controller,
                              addresses: addresses,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _openDetails(context, order.id),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: const Text('عرض تفاصيل الطلب'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: CustomerColors.accent,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );

  /// Takes [context] and [orderId]; opens details and selects current after accept.
  Future<void> _openDetails(BuildContext context, String orderId) async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailsPage(
          orderId: orderId,
          controller: controller,
          addresses: addresses,
        ),
      ),
    );
    if (context.mounted && accepted == true) onAccepted();
  }
}
