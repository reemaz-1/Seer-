import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/pricing_model.dart';
import '../theme/app_colors.dart';

/// VIEW: the suggested service card shown in the AI chat (piece 4).
///
/// It shows what the assistant suggests (vehicle, service, price and note)
/// and a button that opens the request form filled with it, so the customer
/// can change anything before sending. If the order was already sent from the
/// chat, it shows a button that opens the order instead.
class OrderSummaryCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Parameters: [message] is the chat message that holds the suggestion and
  /// its state; [onRequest] opens the request form; [onViewOrder] opens the
  /// order once it was sent.
  const OrderSummaryCard({
    super.key,
    required this.message,
    required this.onRequest,
    required this.onViewOrder,
  });

  final ChatMessage message;
  final VoidCallback onRequest;
  final VoidCallback onViewOrder;

  static const _title = 'الخدمة المقترحة';
  static const _cancelledLabel = 'أُلغي هذا الاقتراح';
  static const _sentLabel = 'تم إرسال الطلب';
  static const _requestLabel = 'اطلب الخدمة';
  static const _requestHint = 'تقدر تعدّل التفاصيل قبل الإرسال';
  static const _viewLabel = 'عرض الطلب';

  /// Builds the card for the state of the suggestion.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: the card, faded when the suggestion was cancelled.
  @override
  Widget build(BuildContext context) {
    final summary = message.summary;
    if (summary == null) return const SizedBox.shrink();
    final state = message.summaryState;

    return Opacity(
      opacity: state == SummaryState.cancelled ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: CustomerColors.fieldFill,
          border: Border.all(color: CustomerColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(state),
            const SizedBox(height: 4),
            _line('المركبة', summary.vehicle.title),
            _line(
              'الخدمة',
              '${summary.categoryLabel} - ${summary.optionLabel}',
            ),
            _line(
              'السعر التقديري',
              formatPrice(summary.estimatedPrice),
              emphasised: true,
            ),
            if (summary.priceDependsOnDistance)
              _line('رسوم المسافة', 'تُحسب بعد تحديد الموقع', muted: true),
            if (summary.note.isNotEmpty) _line('ملاحظة', summary.note),
            if (state == SummaryState.waiting) ..._requestActions(),
            if (state == SummaryState.sent) ..._sentActions(),
          ],
        ),
      ),
    );
  }

  /// Builds the title and the state of the card.
  ///
  /// Parameters: [state] is where the suggestion is in its life.
  /// Returns: a row with the title and, when needed, the state label.
  Widget _header(SummaryState state) {
    final label = switch (state) {
      SummaryState.waiting => null,
      SummaryState.cancelled => _cancelledLabel,
      SummaryState.sent => _sentLabel,
    };
    return Row(
      children: [
        const Text(
          _title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: CustomerColors.primaryText,
          ),
        ),
        const Spacer(),
        if (label != null)
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: state == SummaryState.cancelled
                  ? CustomerColors.secondaryText
                  : CustomerColors.accent,
            ),
          ),
      ],
    );
  }

  /// Builds one label and value line.
  ///
  /// Parameters: the [label], the [value], and whether to show it
  /// [emphasised] (price) or [muted] (a note about the price).
  /// Returns: a padded row.
  Widget _line(
    String label,
    String value, {
    bool emphasised = false,
    bool muted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: emphasised ? 16 : 14,
                fontWeight: emphasised ? FontWeight.w800 : FontWeight.w400,
                color: emphasised
                    ? CustomerColors.accent
                    : (muted
                          ? CustomerColors.secondaryText
                          : CustomerColors.primaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the button that opens the request form.
  ///
  /// Parameters: none.
  /// Returns: the hint and the request button.
  List<Widget> _requestActions() {
    return [
      const SizedBox(height: 8),
      const Text(
        _requestHint,
        style: TextStyle(fontSize: 12, color: CustomerColors.secondaryText),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: onRequest,
        style: FilledButton.styleFrom(
          backgroundColor: CustomerColors.accent,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          _requestLabel,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    ];
  }

  /// Builds the button that opens the order after it was sent from the chat.
  ///
  /// Parameters: none.
  /// Returns: the button, or nothing when the order id is not known.
  List<Widget> _sentActions() {
    final orderId = message.orderId;
    if (orderId == null || orderId.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: onViewOrder,
        style: FilledButton.styleFrom(
          backgroundColor: CustomerColors.darkPanel,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text(
          _viewLabel,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ];
  }
}
