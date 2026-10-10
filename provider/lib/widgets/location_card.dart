import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controllers/address_controller.dart';
import '../theme/order_colors.dart';

/// Section that shows where the service is needed and, for towing, where
/// the vehicle is going.
class LocationCard extends StatelessWidget {
  /// Creates the section.
  ///
  /// Parameters: [pickup] is the vehicle location; [dropoff] is the towing
  /// destination and is hidden when null; [controller] finds the addresses.
  const LocationCard({
    super.key,
    required this.pickup,
    required this.controller,
    this.dropoff,
  });

  final GeoPoint pickup;
  final GeoPoint? dropoff;
  final AddressController controller;

  static const _pickupLabel = 'موقع المركبة';
  static const _dropoffLabel = 'الوجهة';

  /// Builds the bordered card with the locations.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a column with the card.
  @override
  Widget build(BuildContext context) {
    final destination = dropoff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CustomerColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocationRow(
                label: _pickupLabel,
                point: pickup,
                controller: controller,
              ),
              if (destination != null) ...[
                const Divider(height: 24, color: CustomerColors.cardBorder),
                _LocationRow(
                  label: _dropoffLabel,
                  point: destination,
                  controller: controller,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One location: an icon, a label and the address below it.
class _LocationRow extends StatelessWidget {
  /// Creates the row.
  ///
  /// Parameters: the row [label], the [point] to describe and the
  /// [controller] that finds its address.
  const _LocationRow({
    required this.label,
    required this.point,
    required this.controller,
  });

  final String label;
  final GeoPoint point;
  final AddressController controller;

  static const _loadingText = 'جاري تحديد العنوان...';

  /// Builds the label and loads the address.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a row with the icon and texts.
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: CustomerColors.darkPanel,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.darkPanel,
                ),
              ),
              const SizedBox(height: 4),
              FutureBuilder<String?>(
                future: controller.addressOf(point),
                builder: (context, snapshot) => Text(
                  snapshot.connectionState == ConnectionState.done
                      ? snapshot.data ?? 'تعذر تحديد العنوان حالياً'
                      : _loadingText,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
