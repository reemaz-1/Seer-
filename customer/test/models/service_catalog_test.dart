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
