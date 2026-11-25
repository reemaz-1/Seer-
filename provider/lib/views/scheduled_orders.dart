import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controllers/provider_requests_controller.dart';
import '../models/order.dart';
import '../models/provider_order_model.dart';
import '../theme/order_colors.dart';
import '../widgets/order_display.dart';

/// Scheduled bookings live alongside existing orders; no second order system.
class ScheduledOrders extends StatefulWidget {
  const ScheduledOrders({super.key, required this.controller, required this.onStarted});
  final ProviderRequestsController controller;
  final VoidCallback onStarted;

  @override
  State<ScheduledOrders> createState() => _ScheduledOrdersState();
}

class _ScheduledOrdersState extends State<ScheduledOrders> {
  final ProviderOrderModel _orders = ProviderOrderModel();
  String? busy;
  String? error;

  Future<void> _perform(String orderId, Future<void> Function() action,
      {bool started = false}) async {
    setState(() { busy = orderId; error = null; });
    try {
      await action();
      if (mounted && started) widget.onStarted();
    } catch (e) {
      if (mounted) setState(() => error = e is StateError
          ? e.message.toString() : 'تعذر تحديث الحجز، حاول مجددًا');
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  String _appointment(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${local.day}/${local.month}/${local.year}  $hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'ص' : 'م'}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders')
          .where('providerId', isEqualTo: widget.controller.providerId)
          .snapshots(),
      builder: (context, snapshot) {
        final accepted = (snapshot.data?.docs ?? [])
            .map((doc) => ServiceOrder.fromMap(doc.id, doc.data()))
            .where((o) => o.status == OrderStatus.scheduledAccepted).toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
        final pending = widget.controller.scheduledRequests;
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل الحجوزات المجدولة'));
        }
        return ListView(padding: const EdgeInsets.all(18), children: [
          if (error != null)
            Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red))),
          const Text('حجوزاتي المقبولة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          if (accepted.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد حجوزات مقبولة')),
          for (final order in accepted) _card(order, accepted: true),
          const SizedBox(height: 20),
          Text('طلبات مجدولة متاحة (${pending.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          if (pending.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد طلبات مجدولة متاحة')),
          for (final order in pending) _card(order, accepted: false),
        ]);
      },
    ),
  );

  Widget _card(ServiceOrder order, {required bool accepted}) {
    final start = order.scheduledAt!;
    final canStart = !DateTime.now().isBefore(start.subtract(const Duration(hours: 12)));
    final isBusy = busy == order.id || widget.controller.isBusy(order.id);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      color: CustomerColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CustomerColors.cardBorder)),
      child: Padding(padding: const EdgeInsets.all(15), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.calendar_month_outlined, color: CustomerColors.accent),
            const SizedBox(width: 7),
            Text(accepted ? 'حجز مؤكد' : 'طلب حجز مجدول',
              style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            OrderStatusChip(status: order.status),
          ]),
          const SizedBox(height: 10),
          Text('${order.serviceCategoryLabel} - ${order.serviceOptionLabel}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('موعد الوصول: ${_appointment(start)}'),
          Text('المركبة: ${order.vehicleTitle}'),
          if (order.pickupLocation != null)
            Text('موقع المركبة: ${order.pickupLocation!.latitude.toStringAsFixed(5)}, ${order.pickupLocation!.longitude.toStringAsFixed(5)}'),
          if (accepted) ...[
            Text('العميل: ${order.customerName}'),
            if (order.customerPhone.isNotEmpty)
              SelectableText('هاتف العميل: ${order.customerPhone}'),
            if (order.note.isNotEmpty) Text('ملاحظة: ${order.note}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isBusy || !canStart ? null : () => _perform(order.id,
                () => _orders.beginScheduledJourney(order.id,
                    widget.controller.providerId), started: true),
              icon: const Icon(Icons.directions_car_outlined),
              label: Text(canStart ? 'بدأت التوجه للعميل' : 'يتاح التوجه قبل الموعد بـ12 ساعة'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: isBusy ? null : () => _perform(order.id, () async {
                final result = await widget.controller.accept(order.id);
                if (result != null) throw StateError(result);
              }),
              child: const Text('قبول الحجز'),
            ),
            OutlinedButton(
              onPressed: isBusy ? null : () => _perform(order.id, () async {
                final result = await widget.controller.reject(order.id);
                if (result != null) throw StateError(result);
              }),
              child: const Text('رفض الطلب'),
            ),
          ],
        ],
      )),
    );
  }
}
