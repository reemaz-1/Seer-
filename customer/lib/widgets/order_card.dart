import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import 'order_display.dart';

/// Card that summarizes one order in the orders list (#24).
class OrderCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Parameters: [order] is the order to show; [onTap] runs when the card
  /// is tapped; [onReorder] runs when the re-request button is tapped, and
  /// the button is hidden when it is null.
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onReorder,
  });

  final ServiceOrder order;
  final VoidCallback onTap;
  final VoidCallback? onReorder;

  static const _iconSize = 72.0;
  static const _referenceLabel = 'رقم الطلب';
  static const _detailsLabel = 'التفاصيل';
  static const _reorderLabel = 'إعادة الطلب';

  static const Map<String, String> _hints = {
    OrderStatus.pending: 'نبحث عن أقرب مزود خدمة متاح لك',
    OrderStatus.rejected: 'اعتذر جميع المزودين عن قبول الطلب.',
    OrderStatus.autoCancelled: 'انتهت مهلة الانتظار دون رد من مزودي الخدمة.',
    OrderStatus.cancelled: 'تم إلغاء الطلب بناءً على طلبك.',
  };

  /// Statuses that can be requested again from the card.
  static const _reorderStatuses = {
    OrderStatus.rejected,
    OrderStatus.autoCancelled,
  };

  /// Builds the card with the order summary on top and the actions below.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a tappable bordered card.
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
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
              _summary(),
              const Divider(height: 1, color: CustomerColors.cardBorder),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the top part: service icon, names, status, date, reference
  /// and price.
  ///
  /// Parameters: none.
  /// Returns: a padded row.
  Widget _summary() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ServiceIconTile(
            categoryId: order.serviceCategoryId,
            status: order.status,
            size: _iconSize,
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
                _InfoItem(
                  icon: Icons.access_time_rounded,
                  text:
                      '${OrderFormat.date(order.createdAt)}  ·  '
                      '${OrderFormat.time(order.createdAt)}',
                ),
                const SizedBox(height: 4),
                _InfoItem(
                  icon: Icons.receipt_long_outlined,
                  text: '$_referenceLabel ${OrderFormat.reference(order.id)}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 56),
            child: Text(
              OrderFormat.price(order.finalPrice ?? order.estimatedPrice),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CustomerColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the bottom part: the progress bar for accepted orders, a short
  /// hint, and either the re-request button or a details link.
  ///
  /// Parameters: none.
  /// Returns: a padded column.
  Widget _footer() {
    final hint = _hints[order.status];
    final canReorder =
        onReorder != null && _reorderStatuses.contains(order.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (OrderProgress.indexOf(order.status) >= 0 &&
              order.status != OrderStatus.completed) ...[
            _ProgressBar(status: order.status),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  hint ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ),
              if (canReorder) _reorderButton() else _detailsLink(),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the navy button that requests the same service again.
  ///
  /// Parameters: none.
  /// Returns: a filled button.
  Widget _reorderButton() {
    return FilledButton.icon(
      onPressed: onReorder,
      style: FilledButton.styleFrom(
        backgroundColor: CustomerColors.darkPanel,
        foregroundColor: CustomerColors.background,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.replay_rounded, size: 18),
      label: const Text(
        _reorderLabel,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Builds the "details" text with a chevron.
  ///
  /// Parameters: none.
  /// Returns: a compact row.
  Widget _detailsLink() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _detailsLabel,
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
    );
  }
}

/// Five-segment bar that shows how far an accepted order has gone.
class _ProgressBar extends StatelessWidget {
  /// Creates the bar.
  ///
  /// Parameters: [status] is the order's current status.
  const _ProgressBar({required this.status});

  final String status;

  /// Builds the segments and their labels.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a column with the segments above the step labels.
  @override
  Widget build(BuildContext context) {
    final current = OrderProgress.indexOf(status);
    final activeColor = OrderStatusStyle.colorOf(status);
    final steps = OrderProgress.steps;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? activeColor
                        : CustomerColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < steps.length; i++)
              Text(
                OrderProgress.shortLabelOf(steps[i]),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                  color: i == current
                      ? activeColor
                      : i < current
                      ? CustomerColors.primaryText
                      : CustomerColors.secondaryText,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Icon followed by a short piece of text.
class _InfoItem extends StatelessWidget {
  /// Creates the item.
  ///
  /// Parameters: [icon] to show and the [text] next to it.
  const _InfoItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  /// Builds the icon and text in a row.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a compact row.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: CustomerColors.secondaryText),
        const SizedBox(width: 6),
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
}
