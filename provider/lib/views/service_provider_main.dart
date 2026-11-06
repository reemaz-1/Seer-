import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'provider_profile_screen.dart';
import '../services/auth_service.dart';
import 'home.dart';
import 'notifications.dart';
import 'orders.dart';
import '../controllers/notification_controller.dart';
import '../models/app_notification.dart';
import '../widgets/notification_banner.dart';
import '../services/device_alerts.dart';
import '../controllers/current_order_controller.dart';
import '../models/order.dart';
import '../services/active_order_tracking_service.dart';

class ServiceProviderMain extends StatefulWidget {
  const ServiceProviderMain({super.key, this.authService, this.firstName = ''});
  final AuthService? authService;
  final String firstName;

  @override
  State<ServiceProviderMain> createState() => _ServiceProviderMainState();
}

class _ServiceProviderMainState extends State<ServiceProviderMain>
    with WidgetsBindingObserver {
  int selectedIndex = 0;

  // Owns one GPS sharing service for the entire signed-in provider session.
  // It survives navigation among Home, Orders and Profile.
  final ActiveOrderTrackingService _tracking = ActiveOrderTrackingService();
  StreamSubscription<ServiceOrder?>? _trackingOrderSubscription;
  Timer? _trackingOrderRetryTimer;
  int _orderStreamFailures = 0;

  // In-app notifications (#47): live list, bell badge and banner.
  NotificationController? _notifications;

  /// Changes each time a notification opens the orders tab, so the tab is
  /// rebuilt on "available requests" even if another sub-tab was open.
  int _ordersVisit = 0;
  String? _requestedDetailsId;

  /// False while the app is in the background or the screen is locked.
  bool _inForeground = true;

  /// A request that arrived while in the background; its banner is shown
  /// when the provider comes back, if it can still be answered.
  AppNotification? _missedWhileAway;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    String uid = '';
    try {
      uid = (widget.authService ?? AuthService()).currentUser?.uid ?? '';
    } catch (_) {
      uid = '';
    }
    if (uid.isNotEmpty) {
      _notifications = NotificationController(providerId: uid)
        ..onNew = _onNewNotification
        ..start();

      _watchTrackingOrder();
    }
  }

  // Firestore may end the order watcher after an authentication or network
  // failure. Reattach it with bounded backoff rather than leaving GPS without
  // a working status observer. Security rules still reject writes after arrival.
  void _watchTrackingOrder() {
    if (!mounted || _trackingOrderSubscription != null) return;
    _trackingOrderRetryTimer?.cancel();
    _trackingOrderRetryTimer = null;
    _trackingOrderSubscription = CurrentOrderController()
        .watchCurrentOrder()
        .listen(
      (order) {
        _orderStreamFailures = 0;
        unawaited(_tracking.syncOrder(order));
      },
      onError: (Object error) {
        debugPrint('Tracking order watcher error: $error');
        _trackingOrderSubscription = null;
        // Fail closed: without a reliable order-state watcher, do not keep
        // sharing the provider's GPS. Recovery will restart the trip only if
        // the refreshed order is still onTheWay and owned by this provider.
        unawaited(_tracking.syncOrder(null));
        _scheduleOrderWatchRetry();
      },
      cancelOnError: true,
    );
  }

  void _scheduleOrderWatchRetry() {
    if (!mounted || (_trackingOrderRetryTimer?.isActive ?? false)) return;
    _orderStreamFailures++;
    final shift = (_orderStreamFailures - 1).clamp(0, 5).toInt();
    final seconds = (1 << shift).clamp(2, 60).toInt();
    _trackingOrderRetryTimer = Timer(Duration(seconds: seconds), () {
      _trackingOrderRetryTimer = null;
      _watchTrackingOrder();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    _tracking.setAppForeground(_inForeground);
    if (!_inForeground) return;
    // Reconnect immediately when the user resumes instead of waiting out
    // a previous transient-error timer.
    if (_trackingOrderSubscription == null) {
      _watchTrackingOrder();
    }
    final missed = _missedWhileAway;
    _missedWhileAway = null;
    if (missed != null &&
        (missed.isActive(DateTime.now()) || missed.isCancellation)) {
      // The system notification already made its sound.
      _showBanner(missed, withSound: false);
    }
  }

  /// New request or cancelled order: a banner while the app is open, a
  /// system notification (status bar and lock screen) while it is in the
  /// background.
  void _onNewNotification(AppNotification notification) {
    if (_inForeground) {
      _showBanner(notification);
      return;
    }
    _missedWhileAway = notification;
    DeviceAlerts.showSystemNotification(
      title: notification.title,
      body: notification.body,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationBanner.hide();
    // Leaving the main screen (e.g. logging out) ends availability mode.
    DeviceAlerts.setAvailableMode(false);
    _notifications?.dispose();
    _trackingOrderRetryTimer?.cancel();
    unawaited(_trackingOrderSubscription?.cancel());
    _tracking.dispose();
    super.dispose();
  }

  void _showBanner(AppNotification notification, {bool withSound = true}) {
    if (!mounted) return;
    NotificationBanner.show(
      context,
      title: notification.title,
      body: notification.body,
      withSound: withSound,
      onTap: () {
        _notifications?.markRead(notification);
        // A cancelled order has nothing left to open.
        if (!notification.isCancellation) _openAvailableRequests();
      },
    );
  }

  /// Closes any pushed page and opens Orders on "available requests".
  void _openAvailableRequests() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _requestedDetailsId = null;
      selectedIndex = 1;
      _ordersVisit++;
    });
  }

  void _openRequestDetails(String orderId) {
    if (!mounted) return;
    setState(() {
      _requestedDetailsId = orderId;
      selectedIndex = 1;
      _ordersVisit++;
    });
  }

  Future<void> _openNotifications() async {
    final openRequests = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProviderNotifications(controller: _notifications),
      ),
    );
    if (openRequests == true) _openAvailableRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),

      // Index 1 opens the combined Orders screen.
      body: selectedIndex == 0
          ? ProviderHome(
    firstName: widget.firstName,
    authService: widget.authService,
    onOpenRequest: _openRequestDetails,
    onViewAllRequests: _openAvailableRequests,
  )
          : selectedIndex == 1
          ? ProviderOrders(
              key: ValueKey(_ordersVisit),
              authService: widget.authService,
              initialOrderId: _requestedDetailsId,
            )
          : ProviderProfileScreen(authService: widget.authService),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4FA),
        elevation: 0,
        centerTitle: true,
        leadingWidth: 130,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.firstName.isEmpty
                  ? 'مرحباً بك'
                  : 'مرحباً، ${widget.firstName}',
              style: const TextStyle(
                color: Color(0xFF0E1B33),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        title: const Text(
          'سَيْر',
          style: TextStyle(
            color: Color(0xFF0E1B33),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            // The app is right to left, so the end side is the left edge.
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C63D6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    iconSize: 20,
                    onPressed: _openNotifications,
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Red badge with the unread count.
                if (_notifications != null)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: AnimatedBuilder(
                      animation: _notifications!,
                      builder: (context, _) {
                        final count = _notifications!.unreadCount;
                        if (count == 0) return const SizedBox.shrink();
                        return IgnorePointer(
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: const Color(0xFFF1F4FA),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: const Color(0xFFF1F4FA),
        // SafeArea keeps the tabs above the phone's navigation bar.
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            child: GNav(
              backgroundColor: Colors.transparent,
              color: const Color(0xFF69728C),
              activeColor: const Color(0xFF1C63D6),
              tabBackgroundColor: const Color(0xFFDCE6F5),
              padding: const EdgeInsets.all(16),
              gap: 8,
              selectedIndex: selectedIndex,
              onTabChange: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              tabs: const [
                GButton(icon: Icons.home_rounded, text: 'الرئيسية'),
                GButton(icon: Icons.receipt_long_rounded, text: 'الطلبات'),
                GButton(icon: Icons.person_rounded, text: 'الحساب'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
