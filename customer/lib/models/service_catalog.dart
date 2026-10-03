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
  });

  /// 'battery' | 'fuel' | 'tires' | 'towing'
  final String id;

  /// Full name, used as the page title.
  final String label;

  /// Short name, used on the home grid.
  final String shortLabel;

  final List<ServiceOption> options;
}

class ServiceCatalog {
  ServiceCatalog._();

  static const List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'battery',
      label: 'خدمة البطارية',
      shortLabel: 'البطارية',
      options: [
        ServiceOption(id: 'activation', label: 'تشغيل البطارية (اشتراك)', branch: 'شحن'),
        ServiceOption(id: 'replace', label: 'تغيير البطارية', branch: 'تبديل'),
      ],
    ),
    ServiceCategory(
      id: 'fuel',
      label: 'التزويد بالوقود',
      shortLabel: 'الوقود',
      options: [
        ServiceOption(id: 'petrol91', label: 'بنزين 91 (أخضر)', branch: '٩١'),
        ServiceOption(id: 'petrol95', label: 'بنزين 95 (أحمر)', branch: '٩٥'),
      ],
    ),
    ServiceCategory(
      id: 'tires',
      label: 'خدمة الإطارات',
      shortLabel: 'الإطارات',
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
      options: [
        ServiceOption(id: 'regular', label: 'سطحة عادية', branch: 'عادية'),
        ServiceOption(id: 'hydraulic', label: 'سطحة هيدروليكية', branch: 'هيدروليك'),
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
