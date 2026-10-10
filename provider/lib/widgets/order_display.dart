import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/order_colors.dart';

/// Display label and colors for each order status.
class OrderStatusStyle {
  /// Takes no inputs; prevents utility instances.
  OrderStatusStyle._();

  static const _cancelledLabel = 'ملغي';

  static const Map<String, String> _labels = {
    OrderStatus.pending: 'بانتظار مزود خدمة',
    OrderStatus.accepted: 'تم القبول',
    OrderStatus.onTheWay: 'في الطريق',
    OrderStatus.arrived: 'وصل المزود',
    OrderStatus.inProgress: 'قيد التنفيذ',
    OrderStatus.completed: 'مكتمل',
    OrderStatus.cancelled: _cancelledLabel,
    OrderStatus.rejected: _cancelledLabel,
    OrderStatus.autoCancelled: _cancelledLabel,
  };

  static const _unknownLabel = 'غير معروف';

  /// Statuses that mean the order will not be served.
  static const cancelledStatuses = {
    OrderStatus.cancelled,
    OrderStatus.rejected,
    OrderStatus.autoCancelled,
  };

  /// Returns the label shown to the customer for a status.
  ///
  /// Parameters: [status] is one of the [OrderStatus] values.
  /// Returns: the matching label, or a generic one for unknown values.
  static String labelOf(String status) => _labels[status] ?? _unknownLabel;

  /// Returns the theme color used for a status.
  ///
  /// Parameters: [status] is one of the [OrderStatus] values.
  /// Returns: warning for waiting, accent for active, success for
  /// completed, error for cancelled.
  static Color colorOf(String status) {
    if (status == OrderStatus.cancelled) return CustomerColors.secondaryText;
    if (cancelledStatuses.contains(status)) return AppStatusColors.error;
    switch (status) {
      case OrderStatus.pending:
        return AppStatusColors.warning;
      case OrderStatus.accepted:
      case OrderStatus.onTheWay:
      case OrderStatus.arrived:
      case OrderStatus.inProgress:
        return CustomerColors.accent;
      case OrderStatus.completed:
        return AppStatusColors.success;
      default:
        return CustomerColors.secondaryText;
    }
  }

  /// Returns the text color used on top of a status tint.
  ///
  /// The warning color is too light for text, so waiting orders use the
  /// primary text color instead.
  ///
  /// Parameters: [status] is one of the [OrderStatus] values.
  /// Returns: a color that stays readable on the status tint.
  static Color textColorOf(String status) => status == OrderStatus.pending
      ? CustomerColors.primaryText
      : colorOf(status);

  /// Returns the light background tint for a status.
  ///
  /// Parameters: [status] is one of the [OrderStatus] values.
  /// Returns: the status color at low opacity.
  static Color tintOf(String status) => colorOf(status).withValues(alpha: 0.12);
}

/// Icon shown for each service category.
class ServiceIcons {
  /// Takes no inputs; prevents utility instances.
  ServiceIcons._();

  static const Map<String, IconData> _icons = {
    'battery': Icons.battery_charging_full_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'tires': Icons.tire_repair_rounded,
    'towing': Icons.local_shipping_rounded,
  };

  /// Returns the icon for a service category.
  ///
  /// Parameters: [categoryId] is the order's service category id.
  /// Returns: the matching icon, or a generic tool icon.
  static IconData of(String categoryId) =>
      _icons[categoryId] ?? Icons.build_rounded;
}

/// The steps an accepted order goes through, in order.
class OrderProgress {
  /// Takes no inputs; prevents utility instances.
  OrderProgress._();

  /// Steps shown in the progress bar of an order card.
  static const steps = [
    OrderStatus.accepted,
    OrderStatus.onTheWay,
    OrderStatus.arrived,
    OrderStatus.inProgress,
    OrderStatus.completed,
  ];

  static const Map<String, String> _shortLabels = {
    OrderStatus.accepted: 'تم القبول',
    OrderStatus.onTheWay: 'في الطريق',
    OrderStatus.arrived: 'وصل',
    OrderStatus.inProgress: 'قيد التنفيذ',
    OrderStatus.completed: 'مكتمل',
  };

  /// Returns the short label of a progress step.
  ///
  /// Parameters: [step] is one of [steps].
  /// Returns: the short label, or the full status label as a fallback.
  static String shortLabelOf(String step) =>
      _shortLabels[step] ?? OrderStatusStyle.labelOf(step);

  /// Returns how far an order has progressed.
  ///
  /// Parameters: [status] is the order's current status.
  /// Returns: the index of the status in [steps], or -1 when the order
  /// has not been accepted or will not be served.
  static int indexOf(String status) => steps.indexOf(status);
}

/// Text formatting for order dates, times, prices and references.
class OrderFormat {
  /// Takes no inputs; prevents utility instances.
  OrderFormat._();

  static const _morning = 'ص';
  static const _evening = 'م';
  static const _currency = 'ر.س';
  static const _priceLater = 'يحدد لاحقاً';
  static const _missingValue = '—';
  static const _referenceLength = 8;

  /// Formats a date as yyyy/MM/dd in local time.
  ///
  /// Parameters: [value] is the date, or null when not set yet.
  /// Returns: the formatted date, or a dash when [value] is null.
  static String date(DateTime? value) {
    if (value == null) return _missingValue;
    final local = value.toLocal();
    return '${local.year}/${_twoDigits(local.month)}/${_twoDigits(local.day)}';
  }

  /// Formats a time as h:mm with a morning or evening marker.
  ///
  /// Parameters: [value] is the time, or null when not set yet.
  /// Returns: the formatted time, or a dash when [value] is null.
  static String time(DateTime? value) {
    if (value == null) return _missingValue;
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? _morning : _evening;
    return '$hour:${_twoDigits(local.minute)} $period';
  }

  /// Formats a price in riyals.
  ///
  /// Parameters: [value] is the price, or null when it is not known yet.
  /// Returns: the price with its currency, or a "decided later" label.
  static String price(num? value) {
    if (value == null) return _priceLater;
    final amount = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return '$amount $_currency';
  }

  /// Builds a short reference from an order id.
  ///
  /// Parameters: [orderId] is the Firestore document id.
  /// Returns: the first characters of the id in upper case, prefixed by #.
  static String reference(String orderId) {
    final short = orderId.length > _referenceLength
        ? orderId.substring(0, _referenceLength)
        : orderId;
    return '#${short.toUpperCase()}';
  }

  /// Pads a number to two digits.
  ///
  /// Parameters: [value] is the number to pad.
  /// Returns: the number as text with a leading zero when needed.
  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

/// Small colored pill that shows an order status.
class OrderStatusChip extends StatelessWidget {
  /// Creates the chip.
  ///
  /// Parameters: [status] is one of the [OrderStatus] values.
  const OrderStatusChip({super.key, required this.status});

  final String status;

  /// Builds the chip.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a rounded label tinted with the status color.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OrderStatusStyle.tintOf(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        OrderStatusStyle.labelOf(status),
        style: TextStyle(
          color: OrderStatusStyle.textColorOf(status),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Rounded square with the icon of a service category.
class ServiceIconTile extends StatelessWidget {
  /// Creates the tile.
  ///
  /// Parameters: [categoryId] picks the icon, [status] picks the colors
  /// and [size] sets the tile's width and height.
  const ServiceIconTile({
    super.key,
    required this.categoryId,
    required this.status,
    this.size = 48,
  });

  final String categoryId;
  final String status;
  final double size;

  /// Builds the tile.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a tinted square with the service icon centered.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OrderStatusStyle.tintOf(status),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        ServiceIcons.of(categoryId),
        size: size * 0.5,
        color: OrderStatusStyle.textColorOf(status),
      ),
    );
  }
}
