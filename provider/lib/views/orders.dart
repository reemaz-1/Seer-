import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../controllers/provider_requests_controller.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'available_requests.dart';
import 'current_order.dart';
import 'history.dart';

/// Provider requests, accepted work and previous orders in one place.
class ProviderOrders extends StatefulWidget {
  /// Takes an optional session [authService]; creates the provider's orders tabs.
  const ProviderOrders({super.key, this.authService});
  final AuthService? authService;

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
    _tabs = TabController(length: 3, vsync: this);
    _requests = ProviderRequestsController(
      providerId: (widget.authService ?? AuthService()).currentUser?.uid ?? '',
    );
    _requests.addListener(_showError);
    _requests.start();
  }

  /// Takes app [state]; refreshes GPS on resume. Deadlines use absolute time.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requests.refreshLocation();
  }

  /// Takes no inputs; shows each controller error once after the current frame.
  void _showError() {
    final error = _requests.takeError();
    if (error == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
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
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'المتاحة'),
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
                onAccepted: () => _tabs.animateTo(1),
              ),
              const ProviderCurrentOrder(),
              const ProviderHistory(),
            ],
          ),
        ),
      ],
    ),
  );
}
