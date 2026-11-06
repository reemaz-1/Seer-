import 'package:flutter/material.dart';

import '../../controllers/customer_orders_controller.dart';
import '../../models/customer_orders_model.dart';
import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../widgets/order_display.dart';
import '../../widgets/order_status_banner.dart';
import '../../widgets/cancel_order_section.dart';
import '../../widgets/order_completed_card.dart';
import '../../widgets/order_rating_section.dart';
import '../../widgets/complaint_section.dart';
import '../../widgets/location_card.dart';
import '../../controllers/address_controller.dart';
import '../../widgets/plate_number_view.dart';
import '../../widgets/customer_order_tracking_map.dart';
import 'request_service_page.dart';

/// Shows the full details of one order and its assigned provider (#25, #26).
class OrderDetailsPage extends StatefulWidget {
  /// Creates the page.
  ///
  /// Parameters: [controller] provides the data; [initialOrder] is shown
  /// right away while live updates load.
  const OrderDetailsPage({
    super.key,
    required this.controller,
    required this.initialOrder,
  });

  final CustomerOrdersController controller;
  final ServiceOrder initialOrder;

  /// Opens the details page for an order.
  ///
  /// Parameters: [context] to navigate from, the [controller] and the
  /// [order] to show.
  /// Returns: a future that completes when the page is closed.
  static Future<void> open(
    BuildContext context, {
    required CustomerOrdersController controller,
    required ServiceOrder order,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderDetailsPage(controller: controller, initialOrder: order),
      ),
    );
  }

  /// Opens the details page when only the order id is known, for example
  /// right after the customer sends a new order. The pages between the
  /// main screen and this one are removed in the same step, so going back
  /// returns to the main screen.
  ///
  /// Parameters: [navigator] to push the page on, the customer's [uid]
  /// and the [orderId] to show.
  /// Returns: a future that completes when the page is closed.
  static Future<void> openById(
    NavigatorState navigator, {
    required String uid,
    required String orderId,
  }) {
    return navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => _OrderByIdPage(uid: uid, orderId: orderId),
      ),
      (route) => route.isFirst,
    );
  }

  /// Creates the page state.
  ///
  /// Parameters: none. Returns: the state object.
  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late final Stream<ServiceOrder?> _orderStream = widget.controller.watchOrder(
    widget.initialOrder.id,
  );

  static const _title = 'تفاصيل الطلب';
  static const _missingOrder = 'هذا الطلب لم يعد متاحاً';

  /// Builds the page and keeps it in sync with the order in Firestore.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: the page scaffold.
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CustomerColors.background,
        appBar: AppBar(
          title: const Text(
            _title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          backgroundColor: CustomerColors.background,
          foregroundColor: CustomerColors.primaryText,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            // Complaint button, pinned in the top bar (#30).
            ComplaintHelpButton(
              order: widget.initialOrder,
              controller: widget.controller,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  OrderFormat.reference(widget.initialOrder.id),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: StreamBuilder<ServiceOrder?>(
          stream: _orderStream,
          initialData: widget.initialOrder,
          builder: (context, snapshot) {
            // Keep showing the last known order if live updates fail.
            final order = snapshot.hasError
                ? widget.initialOrder
                : snapshot.data;
            if (order == null) {
              return const Center(
                child: Text(
                  _missingOrder,
                  style: TextStyle(color: CustomerColors.secondaryText),
                ),
              );
            }
            return _OrderDetailsBody(
              order: order,
              controller: widget.controller,
            );
          },
        ),
      ),
    );
  }
}

/// Scrollable content of the details page.
class _OrderDetailsBody extends StatelessWidget {
  /// Creates the body.
  ///
  /// Parameters: the [order] to show and the [controller] used to load
  /// the provider.
  const _OrderDetailsBody({required this.order, required this.controller});

  final ServiceOrder order;
  final CustomerOrdersController controller;

  static const _vehicleLabel = 'المركبة';
  static const _plateLabel = 'رقم اللوحة';
  static const _dateLabel = 'التاريخ';
  static const _timeLabel = 'الوقت';
  static const _noteLabel = 'ملاحظاتك';
  static const _estimatedPriceLabel = 'السعر التقديري';
  static const _finalPriceLabel = 'السعر النهائي';
  static final _addresses = AddressController();

  /// Builds the header, timeline, provider and order information.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: the scrolling sections with the cancel bar pinned below.
  @override
  Widget build(BuildContext context) {
    final providerId = order.providerId;
    final finalPrice = order.finalPrice;
    final note = order.note.trim();

    // Keep content and the cancel bar above system navigation.
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _OrderHeader(order: order),
                if (OrderStatusBanner.hasMessage(order.status) &&
                    order.status != OrderStatus.completed) ...[
                  const SizedBox(height: 16),
                  OrderStatusBanner(
                    status: order.status,
                    onReorder: () => RequestServicePage.reorder(
                      context,
                      uid: controller.uid,
                      order: order,
                    ),
                  ),
                ],
                if (_TrackingSection.isVisibleFor(order.status)) ...[
                  const SizedBox(height: 16),
                  _TrackingSection(order: order),
                ],
                const SizedBox(height: 16),
                if (order.status == OrderStatus.completed)
                  OrderCompletedCard(order: order)
                else
                  _OrderTimeline(order: order),
                if (providerId != null && providerId.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ProviderCard(providerId: providerId, controller: controller),
                  if (order.status == OrderStatus.completed)
                    OrderRatingSection(
                      key: ValueKey(order.id),
                      order: order,
                      uid: controller.uid,
                    ),
                  // Complaint action or existing complaint status (#30).
                  ComplaintSection(order: order, uid: controller.uid),
                ],
                if (order.pickupLocation != null) ...[
                  const SizedBox(height: 14),
                  LocationCard(
                    pickup: order.pickupLocation!,
                    dropoff: order.dropoffLocation,
                    controller: _addresses,
                  ),
                ],
                const SizedBox(height: 14),
                _InfoCard(
                  rows: [
                    _InfoRow(label: _vehicleLabel, value: order.vehicleTitle),
                    _InfoRow(
                      label: _plateLabel,
                      value: order.vehiclePlateArabic,
                    ),
                    _InfoRow(
                      label: _dateLabel,
                      value: OrderFormat.date(order.createdAt),
                    ),
                    _InfoRow(
                      label: _timeLabel,
                      value: OrderFormat.time(order.createdAt),
                    ),
                    if (note.isNotEmpty)
                      _InfoRow(label: _noteLabel, value: note),
                    _InfoRow(
                      label: _estimatedPriceLabel,
                      value: OrderFormat.price(order.estimatedPrice),
                      highlight: finalPrice == null,
                    ),
                    if (finalPrice != null)
                      _InfoRow(
                        label: _finalPriceLabel,
                        value: OrderFormat.price(finalPrice),
                        highlight: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          CancelOrderSection(order: order, controller: controller),
        ],
      ),
    );
  }
}

/// Service icon, service names and the status chip.
class _OrderHeader extends StatelessWidget {
  /// Creates the header.
  ///
  /// Parameters: [order] is the order to summarize.
  const _OrderHeader({required this.order});

  final ServiceOrder order;

  /// Builds the header.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a row with the icon tile, names and chip.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ServiceIconTile(
          categoryId: order.serviceCategoryId,
          status: order.status,
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.serviceCategoryLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.serviceOptionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        OrderStatusChip(status: order.status),
      ],
    );
  }
}

/// Tracking card in the details page (#27).
///
/// `onTheWay` uses the customer tracking widget, which owns the live map,
/// optional routing data and full-screen view. This avoids duplicated status
/// text below the map. No provider/Firestore code is changed here.
class _TrackingSection extends StatelessWidget {
  const _TrackingSection({required this.order});

  final ServiceOrder order;

  static const _visibleStatuses = {OrderStatus.accepted, OrderStatus.onTheWay};

  static bool isVisibleFor(String status) => _visibleStatuses.contains(status);

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.onTheWay && order.pickupLocation != null) {
      return CustomerOrderTrackingMap(
        orderId: order.id,
        pickupLocation: order.pickupLocation!,
      );
    }

    final onTheWay = order.status == OrderStatus.onTheWay;
    final color = OrderStatusStyle.colorOf(order.status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            color: CustomerColors.fieldFill,
            child: Center(
              child: Icon(
                onTheWay ? Icons.route_rounded : Icons.map_outlined,
                size: 48,
                color: color.withValues(alpha: 0.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  onTheWay ? 'المزود في الطريق إليك' : 'المزود يستعد للانطلاق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  onTheWay
                      ? 'بانتظار تحديد موقع المركبة لإظهار التتبع.'
                      : 'سيظهر موقع المزود مباشرة عند انطلاقه إليك.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How far a timeline step has got.
enum _StepState { done, current, upcoming, cancelled }

/// One line of the order timeline.
class _TimelineStep {
  /// Creates a step.
  ///
  /// Parameters: the step [label], its [state] and an optional [time].
  const _TimelineStep({required this.label, required this.state, this.time});

  final String label;
  final _StepState state;
  final DateTime? time;
}

/// Vertical timeline of the order's progress (#25).
class _OrderTimeline extends StatelessWidget {
  /// Creates the timeline.
  ///
  /// Parameters: [order] is the order whose progress is shown.
  const _OrderTimeline({required this.order});

  final ServiceOrder order;

  static const _sentLabel = 'تم إرسال الطلب';
  static const _waitingLabel = 'بانتظار قبول مزود خدمة';
  static const _cancelledLabel = 'تم إلغاء الطلب';
  static const _nowLabel = 'الآن';

  static const Map<String, String> _labels = {
    OrderStatus.accepted: 'تم القبول',
    OrderStatus.onTheWay: 'في الطريق إليك',
    OrderStatus.arrived: 'وصل المزود',
    OrderStatus.inProgress: 'قيد التنفيذ',
    OrderStatus.completed: 'مكتمل',
  };

  /// Builds the list of steps for the order's current status.
  ///
  /// Parameters: none.
  /// Returns: the steps in display order.
  List<_TimelineStep> _buildSteps() {
    final status = order.status;

    if (OrderStatusStyle.cancelledStatuses.contains(status)) {
      return [
        _TimelineStep(
          label: _sentLabel,
          state: _StepState.done,
          time: order.createdAt,
        ),
        const _TimelineStep(
          label: _cancelledLabel,
          state: _StepState.cancelled,
        ),
      ];
    }

    final current = OrderProgress.indexOf(status);
    final isFinished = status == OrderStatus.completed;
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: _sentLabel,
        state: _StepState.done,
        time: order.createdAt,
      ),
    ];

    if (current < 0) {
      steps.add(
        const _TimelineStep(label: _waitingLabel, state: _StepState.current),
      );
    }

    for (var i = 0; i < OrderProgress.steps.length; i++) {
      final step = OrderProgress.steps[i];
      final _StepState state;
      if (i < current || (isFinished && i == current)) {
        state = _StepState.done;
      } else if (i == current) {
        state = _StepState.current;
      } else {
        state = _StepState.upcoming;
      }
      steps.add(
        _TimelineStep(
          label: _labels[step] ?? OrderProgress.shortLabelOf(step),
          state: state,
          time: step == OrderStatus.accepted ? order.acceptedAt : null,
        ),
      );
    }
    return steps;
  }

  /// Builds the bordered card holding every step.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a card with one row per step.
  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final activeColor = OrderStatusStyle.colorOf(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isLast: i == steps.length - 1,
              activeColor: activeColor,
              nowLabel: _nowLabel,
            ),
        ],
      ),
    );
  }
}

/// One row of the timeline: a marker, a connecting line and the label.
class _TimelineRow extends StatelessWidget {
  /// Creates the row.
  ///
  /// Parameters: the [step] to draw, [isLast] to hide the connector,
  /// the [activeColor] of the order and the [nowLabel] for the current
  /// step.
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.activeColor,
    required this.nowLabel,
  });

  final _TimelineStep step;
  final bool isLast;
  final Color activeColor;
  final String nowLabel;

  static const _markerSize = 22.0;
  static const _connectorHeight = 22.0;

  /// Returns the marker color for the step's state.
  ///
  /// Parameters: none.
  /// Returns: the error color when cancelled, the active color when
  /// reached, otherwise the border color.
  Color get _markerColor {
    switch (step.state) {
      case _StepState.cancelled:
        return AppStatusColors.error;
      case _StepState.done:
      case _StepState.current:
        return activeColor;
      case _StepState.upcoming:
        return CustomerColors.cardBorder;
    }
  }

  /// Builds the marker circle for the step's state.
  ///
  /// Parameters: none.
  /// Returns: a filled circle with an icon, a ringed dot, or an outline.
  Widget _marker() {
    switch (step.state) {
      case _StepState.done:
      case _StepState.cancelled:
        return Container(
          width: _markerSize,
          height: _markerSize,
          decoration: BoxDecoration(
            color: _markerColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            step.state == _StepState.done
                ? Icons.check_rounded
                : Icons.close_rounded,
            size: 14,
            color: CustomerColors.background,
          ),
        );
      case _StepState.current:
        return Container(
          width: _markerSize,
          height: _markerSize,
          decoration: BoxDecoration(
            color: _markerColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: _markerColor.withValues(alpha: 0.2),
              width: 6,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
        );
      case _StepState.upcoming:
        return Container(
          width: _markerSize,
          height: _markerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _markerColor, width: 2),
          ),
        );
    }
  }

  /// Builds the row.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: the marker column next to the label and time.
  @override
  Widget build(BuildContext context) {
    final reached = step.state != _StepState.upcoming;
    final isCurrent = step.state == _StepState.current;
    final time = step.time;
    final trailing = isCurrent
        ? nowLabel
        : time != null
        ? OrderFormat.time(time)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _marker(),
            if (!isLast)
              Container(
                width: 2,
                height: _connectorHeight,
                color: step.state == _StepState.done
                    ? activeColor
                    : CustomerColors.cardBorder,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: _markerSize,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : reached
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isCurrent || step.state == _StepState.cancelled
                          ? _markerColor
                          : reached
                          ? CustomerColors.primaryText
                          : CustomerColors.secondaryText,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent
                          ? _markerColor
                          : CustomerColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Assigned provider section (#26). Shown only after a provider accepts.
class _ProviderCard extends StatefulWidget {
  /// Creates the section.
  ///
  /// Parameters: [providerId] is the assigned provider's user id and
  /// [controller] is used to load the provider.
  const _ProviderCard({required this.providerId, required this.controller});

  final String providerId;
  final CustomerOrdersController controller;

  /// Creates the section state.
  ///
  /// Parameters: none. Returns: the state object.
  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  late Future<AssignedProvider?> _providerFuture;

  static const _title = 'مزود الخدمة';
  static const _loadError = 'تعذّر تحميل بيانات مزود الخدمة';
  static const _noRating = 'لا يوجد تقييم بعد';
  static const _vehicleLabel = 'المركبة';
  static const _emptyValue = '—';

  /// Starts loading the provider when the section first appears.
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void initState() {
    super.initState();
    _providerFuture = widget.controller.getAssignedProvider(widget.providerId);
  }

  /// Reloads the provider if the order is assigned to someone else.
  ///
  /// Parameters: [oldWidget] is the previous configuration.
  /// Returns: nothing.
  @override
  void didUpdateWidget(covariant _ProviderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId) {
      _providerFuture = widget.controller.getAssignedProvider(
        widget.providerId,
      );
    }
  }

  /// Returns the first letter of a name for the avatar.
  ///
  /// Parameters: [name] is the provider's full name.
  /// Returns: the first character, or an empty string.
  static String _initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '' : trimmed.substring(0, 1);
  }

  /// Builds the navy container used for every state of the card.
  ///
  /// Parameters: [child] is the content inside the card.
  /// Returns: a rounded navy container.
  Widget _shell(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.darkPanel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  /// Builds the provider details once they are loaded.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a navy card with a spinner, an error or the provider info.
  @override
  Widget build(BuildContext context) {
    final mutedText = CustomerColors.background.withValues(alpha: 0.7);

    return FutureBuilder<AssignedProvider?>(
      future: _providerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _shell(
            const Center(
              child: CircularProgressIndicator(
                color: CustomerColors.background,
              ),
            ),
          );
        }

        final provider = snapshot.data;
        if (snapshot.hasError || provider == null) {
          return _shell(
            Text(_loadError, style: TextStyle(fontSize: 14, color: mutedText)),
          );
        }

        final rating = provider.rating;
        final faint = CustomerColors.background.withValues(alpha: 0.08);
        final vehicle = provider.vehicleTitle.trim();
        final color = provider.vehicleColor.trim();

        return _shell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: CustomerColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initialOf(provider.fullName),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: CustomerColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: TextStyle(fontSize: 12, color: mutedText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CustomerColors.background,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: faint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppStatusColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating == null
                              ? _noRating
                              : rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CustomerColors.background,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _vehicleLabel,
                          style: TextStyle(fontSize: 12, color: mutedText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicle.isEmpty ? _emptyValue : vehicle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CustomerColors.background,
                          ),
                        ),
                        if (color.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                size: 14,
                                color: mutedText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                color,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CustomerColors.background,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (provider.plateNumber.trim().isNotEmpty)
                    PlateNumberView.fromStored(
                      arabic: provider.plateNumber,
                      latin: provider.plateNumberLatin,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bordered card that lists label and value rows.
class _InfoCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Parameters: [rows] are the rows shown inside, top to bottom.
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  /// Builds the card with a divider between rows.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a bordered column.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: CustomerColors.fieldFill),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One label and value line inside the information card.
class _InfoRow extends StatelessWidget {
  /// Creates the row.
  ///
  /// Parameters: the [label], the [value] and whether to [highlight] the
  /// value in the accent color.
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  static const _emptyValue = '—';

  /// Builds the row.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a padded row; a dash replaces an empty value.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: CustomerColors.secondaryText,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.trim().isEmpty ? _emptyValue : value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight
                    ? CustomerColors.accent
                    : CustomerColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads an order by its id, then shows its details page.
class _OrderByIdPage extends StatefulWidget {
  /// Creates the page.
  ///
  /// Parameters: the customer's [uid] and the [orderId] to load.
  const _OrderByIdPage({required this.uid, required this.orderId});

  final String uid;
  final String orderId;

  /// Creates the page state.
  ///
  /// Parameters: none. Returns: the state object.
  @override
  State<_OrderByIdPage> createState() => _OrderByIdPageState();
}

class _OrderByIdPageState extends State<_OrderByIdPage> {
  late final CustomerOrdersController _controller = CustomerOrdersController(
    uid: widget.uid,
  );
  late final Stream<ServiceOrder?> _order = _controller.watchOrder(
    widget.orderId,
  );

  static const _missingOrder = 'هذا الطلب لم يعد متاحاً';

  /// Starts listening to the customer's orders so an expired pending order
  /// is auto-cancelled while this page is open (#21).
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  /// Releases the controller when the page closes.
  ///
  /// Parameters: none. Returns: nothing.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows a loader until the order arrives, then its details page.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: the loader, an error message, or the details page.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ServiceOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data;
        if (order != null) {
          return OrderDetailsPage(controller: _controller, initialOrder: order);
        }
        return Scaffold(
          backgroundColor: CustomerColors.background,
          appBar: AppBar(
            backgroundColor: CustomerColors.background,
            foregroundColor: CustomerColors.primaryText,
            elevation: 0,
          ),
          body: Center(
            child: snapshot.hasError
                ? const Text(
                    _missingOrder,
                    style: TextStyle(color: CustomerColors.secondaryText),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
