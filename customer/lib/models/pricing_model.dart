import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_catalog.dart';

/// Prices are kept in Firestore, not in the code, so the team can change them
/// without a new app release:
///
///   lookup_data (collection)
///     service_prices (document)
///       byOption: { "activation": 70, "replace": 250, ... }   // riyals
///       towingPerKm: 3
///
/// Read-only from the app, same rule as lookup_data/vehicles:
///   match /lookup_data/{doc} {
///     allow read: if request.auth != null;
///     allow write: if false;
///   }
class ServicePrices {
  const ServicePrices({
    required this.byOption,
    required this.towingPerKm,
    required this.isFallback,
  });

  /// Service option id -> base price in Saudi riyals.
  final Map<String, num> byOption;

  /// Added per kilometre for towing, once the distance is known (#76).
  final num towingPerKm;

  final bool isFallback;

  factory ServicePrices.fallback() {
    return const ServicePrices(
      byOption: kFallbackServicePrices,
      towingPerKm: kFallbackTowingPerKm,
      isFallback: true,
    );
  }

  /// null when this option has no price yet, so the UI can say so instead of
  /// showing a wrong number.
  num? basePriceFor(String optionId) => byOption[optionId];

  /// The price of an option for a car size. The car wash keeps one price per
  /// size: "washExterior" for a sedan and "washExteriorLarge" for an SUV.
  num? priceFor(String optionId, {String? sizeId}) {
    if (sizeId == VehicleSize.large.id) {
      final large = byOption['${optionId}Large'];
      if (large != null) return large;
    }
    return byOption[optionId];
  }
}

/// TODO: the team and the supervisor must confirm these numbers. They are
/// placeholders so the screens have something to show, not real market prices.
const Map<String, num> kFallbackServicePrices = {
  'activation': 70,    // تشغيل البطارية
  'replace': 250,      // تغيير البطارية
  'petrol91': 50,      // بنزين 91
  'petrol95': 55,      // بنزين 95
  'airInflate': 40,    // نفخ الإطار
  'patch': 60,         // ترقيع الإطار
  'spareChange': 70,   // تغيير الإطار الاحتياطي
  'newTire': 200,      // إطار جديد
  'regular': 150,      // سطحة عادية
  'hydraulic': 250,    // سطحة هيدروليكية
  // Car wash, sedan / small car.
  'washExterior': 30,       // غسيل خارجي
  'washInterior': 30,       // غسيل داخلي
  'washFull': 50,           // غسيل داخلي وخارجي
  // Car wash, SUV / large car.
  'washExteriorLarge': 35,
  'washInteriorLarge': 35,
  'washFullLarge': 60,
};

const num kFallbackTowingPerKm = 3;

/// Talks to the database.
class PricingModel {
  PricingModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Read once per app session, like the other lookups.
  static ServicePrices? _cached;

  Future<ServicePrices> getPrices() async {
    final cached = _cached;
    if (cached != null && !cached.isFallback) return cached;

    try {
      final doc =
          await _firestore.collection('lookup_data').doc('service_prices').get();
      final data = doc.data();

      final byOption = <String, num>{};
      final raw = data?['byOption'];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (key is String && value is num) byOption[key] = value;
        });
      }
      if (byOption.isEmpty) return ServicePrices.fallback();
      // A large-car price missing from Firestore falls back to the built-in
      // one, so an SUV never sees "to be decided".
      for (final entry in kFallbackServicePrices.entries) {
        if (entry.key.endsWith('Large')) {
          byOption.putIfAbsent(entry.key, () => entry.value);
        }
      }

      final result = ServicePrices(
        byOption: byOption,
        towingPerKm: (data?['towingPerKm'] as num?) ?? kFallbackTowingPerKm,
        isFallback: false,
      );
      _cached = result;
      return result;
    } catch (e) {
      return ServicePrices.fallback();
    }
  }
}

/// "70 ريال" — one place, so every screen writes a price the same way.
String formatPrice(num? price) {
  if (price == null) return 'يُحدد لاحقًا';
  final rounded = price.round();
  return '$rounded ريال';
}
