import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/device_alerts.dart';
import '../controllers/provider_availability_controller.dart';
import '../controllers/provider_stats_controller.dart';
import '../controllers/provider_requests_controller.dart';
import '../models/order.dart';
import '../widgets/app_snackbar.dart';
import '../theme/order_colors.dart';
import '../widgets/order_display.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({
    super.key,
    this.firstName = '',
    this.authService,
    required this.onOpenRequest,
    required this.onViewAllRequests,
  });

  final String firstName;
  final AuthService? authService;
  final ValueChanged<String> onOpenRequest;
  final VoidCallback onViewAllRequests;

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  bool isAvailable = false;
  bool isLoadingAvailability = true;
  bool isSavingAvailability = false;

  late final ProviderAvailabilityController _availabilityController;
  late final ProviderRequestsController _requests;

  // Quick statistics (#36). Null until loaded; shown as 0 meanwhile.
  final ProviderStatsController _statsController = ProviderStatsController();
  ProviderStats? _stats;

  @override
  void initState() {
    super.initState();
    _availabilityController = ProviderAvailabilityController(
      widget.authService ?? AuthService(),
    );
    _requests = ProviderRequestsController(
      providerId: (widget.authService ?? AuthService()).currentUser?.uid ?? '',
    )..start();
    _loadAvailability();
    _loadStats();
  }

  @override
  void dispose() {
    _requests.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _statsController.load();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _loadAvailability() async {
    try {
      final availability = await _availabilityController.loadAvailability();
      if (!mounted) return;

      setState(() {
        isAvailable = availability;
        isLoadingAvailability = false;
      });
      // Already available from before: keep requests arriving in the background.
      if (availability) DeviceAlerts.setAvailableMode(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingAvailability = false;
      });

      showAppMessage(context, 'تعذر تحميل حالة التوفر');
    }
  }

  /// Takes [value]; saves availability and shows location/save errors to the user.
  Future<void> _changeAvailability(bool value) async {
    setState(() => isSavingAvailability = true);

    try {
      await _availabilityController.updateAvailability(value);
      if (!mounted) return;

      setState(() => isAvailable = value);

      // Notifications (#47): asked here, after the location step, so the two
      // permission dialogs never overlap. While available, the app keeps
      // listening in the background.
      if (value) await DeviceAlerts.requestPermission();
      await DeviceAlerts.setAvailableMode(value);
    } catch (error) {
      if (!mounted) return;

      if (error is StateError) {
        // Location is off or not allowed: something the provider can fix.
        showAppMessage(context, error.message.toString(),
            type: AppMessageType.warning);
      } else {
        showAppMessage(context, 'تعذر حفظ حالة التوفر');
      }
      
    } finally {
      if (mounted) {
        setState(() => isSavingAvailability = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.firstName.isEmpty
                        ? 'مرحباً بك'
                        : 'مرحباً، ${widget.firstName}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Color(0xFF0E1B33),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'جاهز لمساعدة عملائك اليوم!',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Color(0xFF69728C), fontSize: 15),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Availability Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6F5)),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Availability Switch
                Switch(
                  value: isAvailable,
                  activeThumbColor: const Color(0xFF1C63D6),
                  onChanged: isLoadingAvailability || isSavingAvailability
                      ? null
                      : _changeAvailability,
                ),

                // Availability Text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'حالة التوفر',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Color(0xFF0E1B33),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      isAvailable ? 'متاح لاستقبال الطلبات' : 'غير متاح',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Color(0xFF69728C), fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Quick Statistics Title
          const Text(
            'إحصائيات سريعة',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFF0E1B33),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star_rounded,
                  value: _stats?.rating?.toStringAsFixed(1) ?? '—',
                  label: 'التقييم',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildStatCard(
                  icon: Icons.payments_outlined,
                  value: _stats?.earningsText ?? '0',
                  label: 'صافي الأرباح (ر.س)',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildStatCard(
                  icon: Icons.receipt_long_rounded,
                  value: '${_stats?.completedToday ?? 0}',
                  label: 'طلبات اليوم',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Available Requests
          const Text(
            'الطلبات المتاحة',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFF0E1B33),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: _requests,
            builder: (context, _) {
              if (_requests.loading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final orders = _requests.availableRequests.take(3).toList();
              return Column(
                children: [
                  if (orders.isEmpty) _emptyRequestsCard(),
                  for (final order in orders) ...[
                    _requestPreviewCard(order),
                    const SizedBox(height: 10),
                  ],
                  if (orders.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: widget.onViewAllRequests,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            Text('عرض جميع الطلبات'),
                            SizedBox(width: 6),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Icon(Icons.arrow_back_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyRequestsCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE6F5)),
    ),
    child: const Column(
      children: [
        Icon(Icons.inbox_outlined, color: Color(0xFF69728C), size: 36),
        SizedBox(height: 10),
        Text(
          'لا توجد طلبات متاحة حالياً',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Color(0xFF0E1B33),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'عند توفر طلبات جديدة في منطقتك، ستظهر هنا',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF69728C), fontSize: 13),
        ),
      ],
    ),
  );

  // Customer-style summary with the original Home navigation and expiry logic.
  Widget _requestPreviewCard(ServiceOrder order) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (_requests.canRespond(order)) widget.onOpenRequest(order.id);
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: CustomerColors.cardBorder),
            borderRadius: BorderRadius.circular(18),
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
                      size: 56,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.serviceCategoryLabel,
                              style: const TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: CustomerColors.primaryText)),
                          const SizedBox(height: 2),
                          Text(order.serviceOptionLabel,
                              style: const TextStyle(fontSize: 12,
                                  color: CustomerColors.secondaryText)),
                          const SizedBox(height: 5),
                          Text(OrderStatusStyle.labelOf(order.status),
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: OrderStatusStyle.textColorOf(order.status))),
                          const SizedBox(height: 6),
                          Text('${OrderFormat.date(order.createdAt)} · ${OrderFormat.time(order.createdAt)}',
                              style: const TextStyle(fontSize: 12,
                                  color: CustomerColors.secondaryText)),
                          Text('رقم الطلب ${OrderFormat.reference(order.id)}',
                              style: const TextStyle(fontSize: 12,
                                  color: CustomerColors.secondaryText)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Match the price position in the available-requests card.
                    Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: Text(
                        OrderFormat.price(order.estimatedPrice),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CustomerColors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: CustomerColors.cardBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.near_me_outlined, size: 17,
                            color: CustomerColors.secondaryText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('المسافة إلى المركبة: ${_requests.distanceText(order)}',
                              style: const TextStyle(fontSize: 12,
                                  color: CustomerColors.secondaryText)),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(_requests.countdown(order),
                              style: const TextStyle(fontWeight: FontWeight.w700,
                                  color: CustomerColors.accent,
                                  fontFeatures: [FontFeature.tabularFigures()])),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('عرض الموقع وتفاصيل الطلب',
                              style: TextStyle(fontSize: 12,
                                  color: CustomerColors.secondaryText)),
                        ),
                        const Text('عرض التفاصيل',
                            style: TextStyle(fontWeight: FontWeight.w600,
                                color: CustomerColors.accent)),
                        const SizedBox(width: 5),
                        const Directionality(textDirection: TextDirection.ltr,
                            child: Icon(Icons.arrow_back_rounded,
                                size: 17, color: CustomerColors.accent)),
                      ],
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

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1C63D6), size: 26),

          const SizedBox(height: 8),

          Text(
            value,
            style: TextStyle(
              color: Color(0xFF0E1B33),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF69728C), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
