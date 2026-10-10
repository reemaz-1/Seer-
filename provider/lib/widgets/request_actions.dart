import 'package:flutter/material.dart';

import '../controllers/provider_requests_controller.dart';
import '../models/order.dart';
import '../theme/order_colors.dart';

/// Two full-width response buttons with the shared deadline fill.
class RequestActions extends StatelessWidget {
  /// Takes the live order/controller and success callbacks; creates response UI.
  const RequestActions({
    super.key,
    required this.order,
    required this.controller,
    required this.onAccepted,
    required this.onRejected,
    required this.onError,
  });
  final ServiceOrder order;
  final ProviderRequestsController controller;
  final VoidCallback onAccepted;
  final VoidCallback onRejected;
  final ValueChanged<String> onError;

  /// Takes [context]; returns a timed accept button and a confirmation-based reject.
  @override
  Widget build(BuildContext context) {
    final enabled =
        controller.canRespond(order) && !controller.isBusy(order.id);
    final radius = BorderRadius.circular(14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: 'قبول الطلب، الوقت المتبقي ${controller.countdown(order)}',
          child: Material(
            color: enabled
                ? CustomerColors.accent
                : CustomerColors.secondaryText,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('accept-request'),
              onTap: enabled ? _accept : null,
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        key: const ValueKey('request-time-fill'),
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: controller.progress(order),
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (controller.isBusy(order.id))
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'قبول الطلب',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              controller.countdown(order),
                              key: const ValueKey('request-countdown'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            key: const ValueKey('reject-request'),
            onPressed: enabled ? () => _confirmReject(context) : null,
            icon: const Icon(Icons.close_rounded),
            label: const Text('رفض الطلب'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppStatusColors.error,
              side: const BorderSide(color: AppStatusColors.error),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
          ),
        ),
      ],
    );
  }

  /// Takes no inputs; awaits acceptance and notifies the still-mounted route.
  Future<void> _accept() async {
    final error = await controller.accept(order.id);
    if (error != null) {
      onError(error);
    } else {
      onAccepted();
    }
  }

  /// Takes [context]; confirms while watching expiry, then awaits rejection.
  Future<void> _confirmReject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final available = controller.availableOrder(order.id) != null;
            return AlertDialog(
              backgroundColor: CustomerColors.background,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('رفض الطلب'),
              content: Text(
                available
                    ? 'هل أنت متأكد من رفض هذا الطلب؟'
                    : ProviderRequestsController.unavailableMessage,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('تراجع'),
                ),
                FilledButton(
                  key: const ValueKey('confirm-reject'),
                  onPressed: available
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppStatusColors.error,
                  ),
                  child: const Text('نعم، رفض'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await controller.reject(order.id);
    if (error != null) {
      onError(error);
    } else {
      onRejected();
    }
  }
}
