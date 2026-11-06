import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import 'order_display.dart';

/// Title and message shown in the status banner.
class _BannerText {
  /// Creates the banner text.
  ///
  /// Parameters: the banner [title] and the [message] below it.
  const _BannerText(this.title, this.message);

  final String title;
  final String message;
}

/// Banner at the top of the order details that explains how the order
/// ended (#25).
class OrderStatusBanner extends StatelessWidget {
  /// Creates the banner.
  ///
  /// Parameters: [status] is the order's current status; [onReorder] runs
  /// when the re-request button is tapped, and the button is hidden when
  /// it is null.
  const OrderStatusBanner({super.key, required this.status, this.onReorder});

  final String status;
  final VoidCallback? onReorder;

  static const _reorderLabel = 'إعادة الطلب';

  static const Map<String, _BannerText> _texts = {
    OrderStatus.rejected: _BannerText(
      'لم يقبل أي مزود الطلب',
      'لم يتمكن أي من المزودين من قبول طلبك هذه المرة.',
    ),
    OrderStatus.autoCancelled: _BannerText(
      'بلا استجابة',
      'انتهت مهلة الانتظار دون استجابة من مزود خدمة.',
    ),
    OrderStatus.cancelled: _BannerText(
      'تم إلغاء الطلب',
      'تم إلغاء الطلب بناءً على طلبك.',
    ),
    OrderStatus.completed: _BannerText('تم إكمال الطلب', 'سعدنا بخدمتك.'),
  };

  /// Statuses that can be requested again from the banner.
  static const _reorderStatuses = {
    OrderStatus.rejected,
    OrderStatus.autoCancelled,
  };

  /// Tells whether a status has a banner.
  ///
  /// Parameters: [status] is one of the [OrderStatus] values.
  /// Returns: true for statuses that end the order.
  static bool hasMessage(String status) => _texts.containsKey(status);

  /// Builds the tinted banner with the title, message and optional button.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: the banner, or an empty box for statuses without one.
  @override
  Widget build(BuildContext context) {
    final text = _texts[status];
    if (text == null) return const SizedBox.shrink();

    final color = OrderStatusStyle.colorOf(status);
    final canReorder = onReorder != null && _reorderStatuses.contains(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OrderStatusStyle.textColorOf(status),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: CustomerColors.primaryText,
            ),
          ),
          if (canReorder) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onReorder,
              style: FilledButton.styleFrom(
                backgroundColor: CustomerColors.darkPanel,
                foregroundColor: CustomerColors.background,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text(
                _reorderLabel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
