import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/rating_model.dart';

/// Inline feedback on completed orders, with a persisted read-only result.
class OrderRatingSection extends StatefulWidget {
  const OrderRatingSection({
    super.key,
    required this.order,
    required this.uid,
    this.model,
  });
  final ServiceOrder order;
  final String uid;
  final RatingModel? model;
  @override
  State<OrderRatingSection> createState() => _OrderRatingSectionState();
}

class _OrderRatingSectionState extends State<OrderRatingSection> {
  late final RatingModel _model = widget.model ?? RatingModel();
  late final _rating = _model.watch(widget.order.id);
  int _stars = 0;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _stars == 0 || _submitted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _model.submit(
        orderId: widget.order.id,
        customerId: widget.uid,
        stars: _stars,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'تعذر إرسال التقييم. تحقق من الاتصال وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order.status != OrderStatus.completed ||
        widget.order.customerId != widget.uid ||
        widget.order.providerId == null ||
        widget.order.providerId!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<OrderRating?>(
          stream: _rating,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_submitted) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Text(
                'تعذر تحميل تقييمك. تحقق من الاتصال وأعد فتح الطلب.',
              );
            }
            final saved = snapshot.data?.stars;
            final done = saved != null || _submitted;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  done ? 'شكرًا لتقييمك!' : 'كيف كانت تجربتك مع مقدم الخدمة؟',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        tooltip: '$star من 5',
                        onPressed: done || _saving
                            ? null
                            : () => setState(() => _stars = star),
                        icon: Icon(
                          star <= (saved ?? _stars)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber.shade700,
                          size: 32,
                        ),
                      ),
                  ],
                ),
                if (done)
                  Text(
                    'تقييمك: ${saved ?? _stars} من 5',
                    textAlign: TextAlign.center,
                  )
                else
                  ElevatedButton(
                    onPressed: _saving || _stars == 0 ? null : _save,
                    child: Text(_saving ? 'جارٍ الإرسال…' : 'إرسال التقييم'),
                  ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            );
          },
        ),
      ),
    );
  }
}
