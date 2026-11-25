import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../controllers/address_controller.dart';
import '../controllers/current_order_controller.dart';
import '../controllers/provider_requests_controller.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'available_requests.dart';
import 'current_order.dart';
import 'history.dart';
import 'request_details_page.dart';
import 'scheduled_orders.dart';
import '../widgets/app_snackbar.dart';

/// Provider requests, accepted work and previous orders in one place.
class ProviderOrders extends StatefulWidget {
  /// Takes an optional session [authService]; creates the provider's orders tabs.
  const ProviderOrders({
    super.key,
    this.authService,
    this.initialOrderId,
    this.openCurrentIfActive = false,
  });
  final AuthService? authService;
  final String? initialOrderId;

  /// When true, opens on "current" if the provider has an accepted order,
  /// and stays on "available" if not. Used when opened from the bottom bar.
  final bool openCurrentIfActive;

  /// Takes no inputs; returns state owning the live request subscription.
  @override
  State<ProviderOrders> createState() => _ProviderOrdersState();
}

class _ProviderOrdersState extends State<ProviderOrders>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;
  late final ProviderRequestsController _requests;
  final AddressController _addresses = AddressController();

  /// Takes no inputs; binds request state to the authenticated provider.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 4, vsync: this);
    _requests = ProviderRequestsController(
      providerId: (widget.authService ?? AuthService()).currentUser?.uid ?? '',
    );
    _requests.addListener(_showError);
    _requests.start();
    if (widget.initialOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialDetails());
    } else if (widget.openCurrentIfActive) {
      _openCurrentIfActive();
    }
  }

  /// Takes no inputs; moves to the "current" tab when the provider already
  /// has an accepted order. Stays on "available" when there is none, when
  /// the check fails, or when the provider already picked another tab.
  Future<void> _openCurrentIfActive() async {
    try {
      final order = await CurrentOrderController()
          .watchCurrentOrder()
          .first
          .timeout(const Duration(seconds: 5));
      if (!mounted || order == null || _tabs.index != 0) return;
      _tabs.index = 2;
    } catch (_) {
      // Keep "available" open if the order cannot be read.
    }
  }

  Future<void> _openInitialDetails() async {
    final id = widget.initialOrderId;
    if (!mounted || id == null) return;
    // Notification deep links for advance bookings belong to the scheduled tab.
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(id).get();
      if (!mounted) return;
      if (doc.data()?['scheduledAt'] != null) {
        _tabs.animateTo(1);
        return;
      }
    } catch (_) {
      // Preserve the existing immediate-request deep link if lookup fails.
    }
    if (!mounted) return;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RequestDetailsPage(
          orderId: id,
          controller: _requests,
          addresses: _addresses,
        ),
      ),
    );
    if (mounted && accepted == true) _tabs.animateTo(2);
  }

  /// Takes app [state]; refreshes GPS on resume. Deadlines use absolute time.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requests.refreshLocation();
  }

  /// Takes no inputs; shows each controller error once after the current frame.
  void _showError() {
    final isLocation = _requests.lastErrorIsLocation;
    final error = _requests.takeError();
    if (error == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showAppMessage(
          context,
          error,
          type: isLocation ? AppMessageType.warning : AppMessageType.error,
        );      
      }
    });
  }

  /// Takes no inputs; cancels snapshots, timers and tab animation ownership.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requests.removeListener(_showError);
    _requests.dispose();
    _tabs.dispose();
    super.dispose();
  }

  /// Takes [context]; returns three Arabic tabs and their existing/new views.
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.cardBorder,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.secondaryText,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'المتاحة'),
              Tab(text: 'المجدولة'),
              Tab(text: 'الحالية'),
              Tab(text: 'السابقة'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              AvailableRequests(
                controller: _requests,
                addresses: _addresses,
                onAccepted: () => _tabs.animateTo(2),
              ),
              ScheduledOrders(controller: _requests,
                onStarted: () => _tabs.animateTo(2)),
              const ProviderCurrentOrder(),
              ProviderHistory(addresses: _addresses),
            ],
          ),
        ),
      ],
    ),
  );
}
