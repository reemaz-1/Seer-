import 'package:cloud_firestore/cloud_firestore.dart';

/// Shown at the end of every brand and model dropdown. Picking it opens a
/// text field so the customer can type a value the list does not have.
const String kOtherOption = 'أخرى';

/// The dropdown lists both apps share: vehicle brands, models per brand,
/// and colors. Stored in Firestore so they can be changed without a new
/// app release:
///
///   lookup_data (collection)
///     vehicles (document)
///       brands: ["تويوتا", "هيونداي", ...]
///       colors: ["أبيض", "أسود", ...]
///       models: { "تويوتا": ["كامري", "كورولا", ...], "كيا": [...] }
///
/// Security Rules should let any signed-in user READ it and let no one
/// write it from the app:
///   match /lookup_data/{doc} {
///     allow read: if request.auth != null;
///     allow write: if false;
///   }
class VehicleLookups {
  const VehicleLookups({
    required this.brands,
    required this.colors,
    required this.models,
    required this.isFallback,
  });

  final List<String> brands;
  final List<String> colors;

  /// Brand -> its models. A brand that is missing here simply has no
  /// suggestions, and the customer types the model under "أخرى".
  final Map<String, List<String>> models;

  /// true when the lists came from the built-in copy below, because
  /// Firestore could not be read or the document is missing.
  final bool isFallback;

  factory VehicleLookups.fallback() {
    return const VehicleLookups(
      brands: kFallbackVehicleBrands,
      colors: kFallbackVehicleColors,
      models: kFallbackVehicleModels,
      isFallback: true,
    );
  }
}

/// Used when Firestore is unreachable, so the customer can still add a
/// vehicle. Keep in step with the shared document.
const List<String> kFallbackVehicleBrands = [
  'تويوتا',
  'هيونداي',
  'كيا',
  'نيسان',
  'فورد',
  'شيفروليه',
  'لكزس',
  'هوندا',
  'مازدا',
  'ميتسوبيشي',
  'إم جي',
  'جيلي',
  'شانجان',
  'بي واي دي',
  kOtherOption,
];

const List<String> kFallbackVehicleColors = [
  'أبيض',
  'أسود',
  'فضي',
  'رمادي',
  'أزرق',
  'أحمر',
  'بني',
  'بيج',
  'أخضر',
  'ذهبي',
  kOtherOption,
];

const Map<String, List<String>> kFallbackVehicleModels = {
  'تويوتا': ['كامري', 'كورولا', 'لاندكروزر', 'برادو', 'هايلكس', 'يارس', 'راف فور', 'أفالون', 'إنوفا'],
  'هيونداي': ['النترا', 'سوناتا', 'أكسنت', 'توسان', 'سنتافي', 'كريتا', 'H1'],
  'كيا': ['سيراتو', 'أوبتيما', 'سبورتاج', 'سورنتو', 'ريو', 'كارنفال', 'بيجاس'],
  'نيسان': ['التيما', 'صني', 'باترول', 'إكس تريل', 'نافارا', 'ماكسيما'],
  'فورد': ['تورس', 'إكسبلورر', 'F-150', 'إيدج', 'موستانج'],
  'شيفروليه': ['ماليبو', 'كابرس', 'تاهو', 'سوبربان', 'ترافيرس', 'كروز'],
  'لكزس': ['ES', 'LS', 'RX', 'LX', 'NX', 'GX'],
  'هوندا': ['أكورد', 'سيفيك', 'CR-V', 'بايلوت', 'HR-V'],
  'مازدا': ['مازدا 3', 'مازدا 6', 'CX-5', 'CX-9', 'CX-30'],
  'ميتسوبيشي': ['لانسر', 'باجيرو', 'أوتلاندر', 'أتراج', 'L200'],
  'إم جي': ['MG5', 'MG6', 'ZS', 'RX5', 'HS'],
  'جيلي': ['إمجراند', 'كولراي', 'أزكارا', 'توجيلا'],
  'شانجان': ['إيدو', 'ألسفين', 'CS35', 'CS75'],
  'بي واي دي': ['سونغ', 'هان', 'تانغ', 'سيل'],
};

/// Talks to the database.
class LookupModel {
  LookupModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Read once per app session: these lists change rarely, and re-reading
  /// them on every form would cost a Firestore read each time.
  static VehicleLookups? _cached;

  Future<VehicleLookups> getVehicleLookups() async {
    final cached = _cached;
    if (cached != null && !cached.isFallback) return cached;

    try {
      final doc = await _firestore.collection('lookup_data').doc('vehicles').get();
      final data = doc.data();

      final brands = _stringList(data?['brands']);
      final colors = _stringList(data?['colors']);
      final models = _modelsMap(data?['models']);

      // An empty or missing list would leave the customer with an empty
      // dropdown, so fall back to the built-in copy for that list.
      final result = VehicleLookups(
        brands: brands.isEmpty ? kFallbackVehicleBrands : brands,
        colors: colors.isEmpty ? kFallbackVehicleColors : colors,
        models: models.isEmpty ? kFallbackVehicleModels : models,
        isFallback: brands.isEmpty && colors.isEmpty && models.isEmpty,
      );
      _cached = result;
      return result;
    } catch (e) {
      return VehicleLookups.fallback();
    }
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  static Map<String, List<String>> _modelsMap(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, List<String>>{};
    value.forEach((key, models) {
      if (key is! String) return;
      final list = _stringList(models);
      if (list.isNotEmpty) result[key.trim()] = list;
    });
    return result;
  }
}
