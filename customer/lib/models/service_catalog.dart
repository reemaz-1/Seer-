/// The service menu (#12) and the options inside each service (#13).
///
/// Ported from the provider app's `service_provider.dart` so both apps use the
/// SAME ids. The provider stores which options it offers in `servicesOffered`
/// using these option ids, and matching a request to a provider (#18) compares
/// them, so an id must never be changed on one side only.
class ServiceOption {
  const ServiceOption({
    required this.id,
    required this.label,
    required this.branch,
  });

  /// Matches the provider app, e.g. 'activation', 'petrol91', 'newTire'.
  final String id;

  /// What the customer reads.
  final String label;

  /// The Arabic branch name the provider app keeps in `activeBranches`.
  final String branch;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.options,
    this.description = '',
    this.priceBySize = false,
  });

  /// 'battery' | 'fuel' | 'tires' | 'towing' | 'carwash'
  final String id;

  /// Full name, used as the page title.
  final String label;

  /// Short name, used on the home grid.
  final String shortLabel;

  final List<ServiceOption> options;

  /// One short line on the home page saying what the service covers.
  final String description;

  /// True when the price depends on the size of the car (car wash), so the
  /// request page asks for it and adds [ServicePrices.largeVehicleExtra].
  final bool priceBySize;
}

/// The car sizes a customer can pick for services priced by size.
///
/// Only two sizes, to keep the choice simple. The id is what the AI tool and
/// the code use; the labels are what the customer and the provider read.
class VehicleSize {
  const VehicleSize({
    required this.id,
    required this.label,
    required this.shortLabel,
  });

  final String id;

  /// Shown to the customer when choosing.
  final String label;

  /// Added to the option name in the order, e.g. "غسيل خارجي - دفع رباعي".
  final String shortLabel;

  static const standard = VehicleSize(
    id: 'standard',
    label: 'سيدان / صغيرة',
    shortLabel: 'سيدان',
  );
  static const large = VehicleSize(
    id: 'large',
    label: 'دفع رباعي / كبيرة',
    shortLabel: 'دفع رباعي',
  );

  static const List<VehicleSize> all = [standard, large];

  static VehicleSize? byId(String? id) {
    for (final size in all) {
      if (size.id == id) return size;
    }
    return null;
  }
}

class ServiceCatalog {
  ServiceCatalog._();

  static const List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'battery',
      label: 'خدمة البطارية',
      shortLabel: 'البطارية',
      description: 'تشغيل البطارية أو تغييرها في مكانك',
      options: [
        ServiceOption(id: 'activation', label: 'تشغيل البطارية (اشتراك)', branch: 'شحن'),
        ServiceOption(id: 'replace', label: 'تغيير البطارية', branch: 'تبديل'),
      ],
    ),
    ServiceCategory(
      id: 'fuel',
      label: 'التزويد بالوقود',
      shortLabel: 'الوقود',
      description: 'بنزين 91 أو 95 إلى سيارتك',
      options: [
        ServiceOption(id: 'petrol91', label: 'بنزين 91 (أخضر)', branch: '٩١'),
        ServiceOption(id: 'petrol95', label: 'بنزين 95 (أحمر)', branch: '٩٥'),
      ],
    ),
    ServiceCategory(
      id: 'tires',
      label: 'خدمة الإطارات',
      shortLabel: 'الإطارات',
      description: 'نفخ أو ترقيع أو تغيير الإطار',
      options: [
        ServiceOption(id: 'airInflate', label: 'نفخ الإطار بالهواء', branch: 'نفخ'),
        ServiceOption(id: 'patch', label: 'ترقيع الإطار', branch: 'تصليح'),
        ServiceOption(id: 'spareChange', label: 'تغيير الإطار الاحتياطي', branch: 'تبديل احتياطي'),
        ServiceOption(id: 'newTire', label: 'تغيير الإطار بإطار جديد', branch: 'تركيب جديد'),
      ],
    ),
    ServiceCategory(
      id: 'towing',
      label: 'خدمة السطحة',
      shortLabel: 'السطحة',
      description: 'نقل السيارة إلى وجهتك',
      options: [
        ServiceOption(id: 'regular', label: 'سطحة عادية', branch: 'عادية'),
        ServiceOption(id: 'hydraulic', label: 'سطحة هيدروليكية', branch: 'هيدروليك'),
      ],
    ),
    ServiceCategory(
      id: 'carwash',
      label: 'غسيل السيارة',
      shortLabel: 'غسيل السيارة',
      description: 'تنظيف سيارتك دون مغادرة موقعك',
      priceBySize: true,
      options: [
        ServiceOption(id: 'washExterior', label: 'غسيل خارجي', branch: 'خارجي'),
        ServiceOption(id: 'washInterior', label: 'غسيل داخلي', branch: 'داخلي'),
        ServiceOption(id: 'washFull', label: 'غسيل داخلي وخارجي', branch: 'داخلي وخارجي'),
      ],
    ),
  ];

  /// Towing is the only service that also needs a drop-off location (#16).
  static const String towingId = 'towing';

  static ServiceCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  static ServiceOption? optionById(String categoryId, String optionId) {
    final category = categoryById(categoryId);
    if (category == null) return null;
    for (final option in category.options) {
      if (option.id == optionId) return option;
    }
    return null;
  }
}
