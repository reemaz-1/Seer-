import 'package:flutter_test/flutter_test.dart';
import 'package:customer/models/pricing_model.dart';
import 'package:customer/models/service_catalog.dart';

void main() {
  group('car wash service', () {
    test('has exterior, interior and full options', () {
      final category = ServiceCatalog.categoryById('carwash');
      expect(category, isNotNull);
      expect(
        category!.options.map((o) => o.id),
        ['washExterior', 'washInterior', 'washFull'],
      );
    });

    test('is priced by car size, and the others are not', () {
      for (final c in ServiceCatalog.categories) {
        expect(c.priceBySize, c.id == 'carwash');
      }
    });
  });

  group('car size', () {
    test('each car size has its own car wash price', () {
      final prices = ServicePrices.fallback();
      expect(prices.priceFor('washExterior', sizeId: VehicleSize.standard.id), 30);
      expect(prices.priceFor('washExterior'), 30);
      expect(prices.priceFor('washInterior', sizeId: VehicleSize.large.id), 35);
      expect(prices.priceFor('washFull', sizeId: VehicleSize.standard.id), 50);
      expect(prices.priceFor('washFull', sizeId: VehicleSize.large.id), 60);
    });

    test('services not priced by size ignore the size', () {
      final prices = ServicePrices.fallback();
      expect(
        prices.priceFor('activation', sizeId: VehicleSize.large.id),
        prices.basePriceFor('activation'),
      );
    });

    test('a car wash for the full wash is cheaper than both parts apart', () {
      final prices = ServicePrices.fallback();
      for (final size in VehicleSize.all) {
        final apart = prices.priceFor('washExterior', sizeId: size.id)! +
            prices.priceFor('washInterior', sizeId: size.id)!;
        expect(prices.priceFor('washFull', sizeId: size.id)!, lessThan(apart));
      }
    });

    test('ids and labels are unique', () {
      final ids = VehicleSize.all.map((s) => s.id).toSet();
      final shorts = VehicleSize.all.map((s) => s.shortLabel).toSet();
      expect(ids.length, VehicleSize.all.length);
      expect(shorts.length, VehicleSize.all.length);
      expect(VehicleSize.byId('large'), VehicleSize.large);
      expect(VehicleSize.byId('x'), isNull);
    });
  });

  group('catalog consistency', () {
    test('every option has a fallback price', () {
      for (final c in ServiceCatalog.categories) {
        for (final o in c.options) {
          expect(kFallbackServicePrices.keys, contains(o.id));
        }
      }
    });

    test('option ids are unique', () {
      final ids = [
        for (final c in ServiceCatalog.categories)
          for (final o in c.options) o.id,
      ];
      expect(ids.toSet().length, ids.length);
    });

    // Providers save their offered services by branch name, so two options
    // sharing a branch would switch on together.
    test('branch names are unique', () {
      final branches = [
        for (final c in ServiceCatalog.categories)
          for (final o in c.options) o.branch,
      ];
      expect(branches.toSet().length, branches.length);
    });
  });
}
