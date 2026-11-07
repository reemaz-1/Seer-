import 'package:flutter/material.dart';

import '../controllers/rating_controller.dart';
import '../models/order.dart';
import '../models/rating_model.dart';
import '../theme/app_colors.dart';

/// VIEW: feedback for a completed order with a persisted read-only result.
class OrderRatingSection extends StatefulWidget {
  /// Takes an order, owner and optional controller; creates the rating card.
  const OrderRatingSection({
    super.key,
    required this.order,
    required this.uid,
    this.controller,
  });
  final ServiceOrder order;
  final String uid;
  final RatingController? controller;

  /// Takes no inputs; creates the card state.
  @override
  State<OrderRatingSection> createState() => _OrderRatingSectionState();
}

class _OrderRatingSectionState extends State<OrderRatingSection> {
  late final RatingController _controller =
      widget.controller ?? RatingController(uid: widget.uid);
  late final _rating = _controller.watch(widget.order.id);
  int _stars = 0;
  String? _error;

  /// Takes no inputs; sends selected stars through the controller.
  Future<void> _save() async {
    setState(() => _error = null);
    final error = await _controller.submit(widget.order, _stars);
    if (mounted) setState(() => _error = error);
  }

  /// Takes no inputs; releases only a controller owned by this widget.
  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// Takes context; returns the styled card only for a completed owned order.
  @override
  Widget build(BuildContext context) {
    if (!_controller.canRate(widget.order)) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => StreamBuilder<OrderRating?>(
          stream: _rating,
          builder: (context, snapshot) {
            final submitted = _controller.hasSubmitted(widget.order.id);
            if (snapshot.connectionState == ConnectionState.waiting &&
                !submitted) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Text(
                RatingController.loadFailed,
                style: TextStyle(color: AppStatusColors.error),
              );
            }
            final saved = snapshot.data?.stars;
            final done = saved != null || submitted;
            final saving = _controller.isSending;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  done ? 'شكرًا لتقييمك!' : 'كيف كانت تجربتك مع مقدم الخدمة؟',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CustomerColors.primaryText,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        tooltip: '$star من 5',
                        onPressed: done || saving
                            ? null
                            : () => setState(() {
                                _stars = star;
                                _error = null;
                              }),
                        icon: Icon(
                          star <= (saved ?? _stars)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppStatusColors.warning,
                          size: 32,
                        ),
                      ),
                  ],
                ),
                if (done)
                  Text(
                    'تقييمك: ${saved ?? _stars} من 5',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CustomerColors.primaryText),
                  )
                else
                  FilledButton(
                    onPressed: saving || _stars == 0 ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: CustomerColors.accent,
                      foregroundColor: CustomerColors.background,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(saving ? 'جارٍ الإرسال…' : 'إرسال التقييم'),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: AppStatusColors.error),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
