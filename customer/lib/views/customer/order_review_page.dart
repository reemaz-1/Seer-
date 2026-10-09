import 'package:flutter/material.dart';

import 'order_details_page.dart';

import '../../controllers/order_draft_controller.dart';
import '../../controllers/address_controller.dart';
import '../../theme/app_colors.dart'; 
import '../../models/pricing_model.dart';
import '../../widgets/vehicle_picker_sheet.dart';
import '../../widgets/no_provider_dialog.dart';
import '../../widgets/location_card.dart';

/// VIEW: the order details before it is sent (#17).
/// Everything here is read-only except the vehicle, which can still be
/// changed, and the confirm button sends the request.
///
/// Pops with a success message once the order has been created.
class OrderReviewPage extends StatefulWidget {
  const OrderReviewPage({super.key, required this.controller});

  final OrderDraftController controller;

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  OrderDraftController get _controller => widget.controller;
  final AddressController _addresses = AddressController();

  Future<void> _changeVehicle() async {
    final picked = await showVehiclePicker(
      context: context,
      vehicles: _controller.vehicles,
      selected: _controller.selectedVehicle,
    );
    if (picked != null) _controller.selectVehicle(picked);
  }

  Future<void> _confirm() async {
    final error = await _controller.submit();
    if (!mounted) return;

    if (error != null) {
      // #19: explain clearly instead of a short message at the bottom.
      if (_controller.noNearbyProviders) {
        await showNoProviderDialog(context);
        return;
      }
      // Any other problem (missing location, no internet...).
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final orderId = _controller.createdOrderId;
    if (orderId == null) {
      Navigator.of(context).pop('تم إرسال طلبك، جارٍ البحث عن مزود خدمة');
      return;
    }
    // Open the new order so the customer can follow it or cancel it (#20).
    final navigator = Navigator.of(context);
    OrderDetailsPage.openById(
      navigator,
      uid: _controller.uid,
      orderId: orderId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor: CustomerColors.darkPanel,
        foregroundColor: Colors.white,
        title: const Text(
          'مراجعة الطلب',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final vehicle = _controller.selectedVehicle;
            final option = _controller.selectedOption;
            final sending = _controller.isSubmitting;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Text(
                        'راجع تفاصيل الطلب قبل إرساله',
                        style: TextStyle(fontSize: 14, color: CustomerColors.secondaryText),
                      ),
                      const SizedBox(height: 16),

                      _Card(
                        title: 'الخدمة',
                        children: [
                          _Line(label: 'الخدمة', value: _controller.category?.label ?? ''),
                          _Line(label: 'النوع', value: option?.label ?? ''),
                          // #17: the customer sees the cost before confirming.
                          _Line(
                            label: 'السعر التقديري',
                            value: formatPrice(_controller.estimatedPrice),
                            emphasised: true,
                            last: !_controller.priceDependsOnDistance,
                          ),
                          if (_controller.priceDependsOnDistance)
                            const _Line(
                              label: 'رسم المسافة',
                              value: 'يُحسب بعد تحديد الموقع',
                              muted: true,
                              last: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _Card(
                        title: 'المركبة',
                        actionLabel: _controller.vehicles.length > 1 && !sending ? 'تغيير' : null,
                        onAction: _changeVehicle,
                        children: [
                          _Line(label: 'المركبة', value: vehicle?.title ?? ''),
                          _Line(label: 'اللون', value: vehicle?.color ?? ''),
                          _Line(
                            label: 'اللوحة',
                            value: vehicle?.plateNumberArabic ?? '',
                            last: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Show the same saved GPS points that will be sent to the provider.
                      if (_controller.pickupLocation != null)
                        LocationCard(
                          pickup: _controller.pickupLocation!,
                          dropoff: _controller.needsDropoff
                              ? _controller.dropoffLocation
                              : null,
                          controller: _addresses,
                        )
                      else _Card(
                        title: 'الموقع',
                        children: [
                          _Line(
                            label: 'موقع المركبة',
                            value: 'لم يُحدد بعد',
                            muted: true,
                            last: !_controller.needsDropoff,
                          ),
                          if (_controller.needsDropoff)
                            const _Line(
                              label: 'موقع التسليم',
                              value: 'لم يُحدد بعد',
                              muted: true,
                              last: true,
                            ),
                        ],
                      ),

                      if (_controller.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Card(
                          title: 'ملاحظتك',
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                _controller.note,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: CustomerColors.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: FilledButton(
                      onPressed: sending ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: CustomerColors.accent,
                        disabledBackgroundColor: CustomerColors.accent.withOpacity(0.3),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'تأكيد الطلب',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
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

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.children,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        border: Border.all(color: CustomerColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
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
                    minimumSize: const Size(48, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.muted = false,
    this.emphasised = false,
    this.last = false,
  });

  final String label;
  final String value;
  final bool muted;

  /// Used for the price, so it stands out from the other lines.
  final bool emphasised;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: CustomerColors.cardBorder)),
            ),
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
              textAlign: isRtl ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                fontSize: emphasised ? 16 : 14,
                fontWeight: emphasised ? FontWeight.w800 : FontWeight.w400,
                color: emphasised
                    ? CustomerColors.accent
                    : (muted ? CustomerColors.secondaryText : CustomerColors.secondaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
