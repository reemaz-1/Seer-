import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../controllers/order_history_controller.dart';
import '../models/order.dart';
import '../theme/order_colors.dart';
import '../widgets/order_display.dart';
import 'past_order_details_page.dart';

/// The provider's previous orders (#40): completed orders and orders the
/// customer cancelled after this provider accepted them, newest first.
/// Tapping an order opens its details (#41).
class ProviderHistory extends StatefulWidget {
  /// Takes an optional [controller] and [addresses]; mainly used in tests
  /// and to share the address cache with the other tabs.
  const ProviderHistory({super.key, this.controller, this.addresses});

  final OrderHistoryController? controller;
  final AddressController? addresses;

  @override
  State<ProviderHistory> createState() => _ProviderHistoryState();
}

class _ProviderHistoryState extends State<ProviderHistory> {
  late final OrderHistoryController _controller =
      widget.controller ?? OrderHistoryController();
  late final AddressController _addresses =
      widget.addresses ?? AddressController();
  late final Stream<List<ServiceOrder>> _orders = _controller
      .watchPastOrders();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceOrder>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Message(
            icon: Icons.wifi_off_rounded,
            title: 'تعذر تحميل الطلبات السابقة',
            subtitle: 'تحقق من الاتصال وحاول مرة أخرى',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return const _Message(
            icon: Icons.history_rounded,
            title: 'لا توجد طلبات سابقة',
            subtitle: 'ستظهر هنا الطلبات المكتملة والملغاة',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _PastOrderCard(
            key: ValueKey(orders[index].id),
            order: orders[index],
            onTap: () => _openDetails(orders[index]),
          ),
        );
      },
    );
  }

  /// Takes an [order]; opens its details page (#41).
  void _openDetails(ServiceOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PastOrderDetailsPage(order: order, addresses: _addresses),
      ),
    );
  }
}

/// One previous order in the list, in the same style as the available
/// request card.
class _PastOrderCard extends StatelessWidget {
  const _PastOrderCard({super.key, required this.order, required this.onTap});

  final ServiceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final completed = OrderHistoryController.isCompleted(order);
    final finishedAt = OrderHistoryController.finishedAt(order);
    final price = completed
        ? OrderHistoryController.receivedAmount(order)
        : order.estimatedPrice;
    return Material(
      color: CustomerColors.background,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: CustomerColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ServiceIconTile(
                      categoryId: order.serviceCategoryId,
                      status: order.status,
                      size: 60,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.serviceCategoryLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CustomerColors.primaryText,
                            ),
                          ),
                          Text(
                            order.serviceOptionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CustomerColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            OrderStatusStyle.labelOf(order.status),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: OrderStatusStyle.textColorOf(order.status),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _MetaLine(
                            icon: Icons.access_time_rounded,
                            text: '${OrderFormat.date(finishedAt)}  ·  '
                                '${OrderFormat.time(finishedAt)}',
                          ),
                          const SizedBox(height: 4),
                          _MetaLine(
                            icon: Icons.receipt_long_outlined,
                            text: 'رقم الطلب ${OrderFormat.reference(order.id)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        OrderFormat.price(price),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: completed
                              ? CustomerColors.primaryText
                              : CustomerColors.secondaryText,
                          decoration: completed
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: CustomerColors.cardBorder),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'اضغط لعرض تفاصيل الطلب',
                        style: TextStyle(
                          fontSize: 12,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                    ),
                    Text(
                      'التفاصيل',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CustomerColors.accent,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: CustomerColors.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: CustomerColors.secondaryText),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: CustomerColors.secondaryText,
          ),
        ),
      ),
    ],
  );
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
                color: Color(0xFF69728C),
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
