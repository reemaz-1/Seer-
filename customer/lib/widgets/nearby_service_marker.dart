import 'package:flutter/material.dart';

/// A consistent, service-specific marker for the SEER #78 pickup map.
/// Does not display a provider's name, phone number or vehicle plate.
class NearbyServiceMarker extends StatelessWidget {
  const NearbyServiceMarker({
    super.key,
    required this.categoryId,
    required this.optionId,
  });

  final String categoryId;
  final String optionId;

  @override
  Widget build(BuildContext context) {
    final symbol = switch (categoryId) {
      'tires' => Icons.tire_repair_rounded,
      'battery' => Icons.battery_charging_full_rounded,
      'fuel' => Icons.local_gas_station_rounded,
      'towing' => Icons.local_shipping_rounded,
      'carwash' => Icons.local_car_wash_rounded,
      _ => Icons.handyman_rounded,
    };

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2E7D32), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x290E1B33),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: categoryId == 'fuel'
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_gas_station_rounded,
                      size: 17,
                      color: Color(0xFF22324D),
                    ),
                    Text(
                      optionId == 'petrol95' ? '95' : '91',
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                )
              : Icon(symbol, size: 22, color: const Color(0xFF22324D)),
        ),
      ),
    );
  }
}
