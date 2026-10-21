import 'package:flutter/material.dart';

import '../widgets/blur_validated.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

import '../theme/app_colors.dart';

import '../services/auth_service.dart';
import '../controllers/provider_registration_controller.dart';
import '../widgets/plate_number_field.dart';
import '../models/service_provider.dart';
import '../widgets/app_snackbar.dart';
import '../models/lookup_model.dart';

// ============================================================
// Saudi Phone Input Formatter: accepts Arabic or Western digits, converts
// them to Western digits, forces a leading 05, and allows at most 10 digits.
// ============================================================
class ProviderSaudiPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = ProviderRegistrationController.normalizeDigits(newValue.text);

    if (text.isEmpty) return const TextEditingValue();

    if (!RegExp(r'^[0-9]+$').hasMatch(text)) return oldValue;
    if (text[0] != '0') return oldValue;
    if (text.length >= 2 && text[1] != '5') return oldValue;

    if (text.length > 10) text = text.substring(0, 10);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen> {
  // One Form per step, so "Next" only validates the fields of the
  // current step. Steps stay mounted (Visibility + maintainState),
  // so entered values and the plate field state are never lost.
  final _personalFormKey = GlobalKey<FormState>();
  final _vehicleFormKey = GlobalKey<FormState>();
  late final AuthService _authService = widget.authService ?? AuthService();

  static const int _totalSteps = 3;
  int _step = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _otherModelController = TextEditingController();
  final _otherVehicleTypeController = TextEditingController();
  final _otherBrandController = TextEditingController();
  final _otherColorController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Map<String, dynamic>? _selectedVehicleType;
  String? _selectedBrand;
  String? _selectedColor;
  String? _vehicleTypeError;
  String? _brandError;
  String? _colorError;
  final GlobalKey<PlateNumberFieldState> _plateFieldKey =
      GlobalKey<PlateNumberFieldState>();
  String? _plateError;

  final List<Map<String, dynamic>> _vehicleTypesWithIcons = [
    {'label': 'سيدان', 'icon': MdiIcons.carSide},
    {'label': 'دفع رباعي', 'icon': MdiIcons.carEstate},
    {'label': 'بيك أب', 'icon': MdiIcons.carPickup},
    {'label': 'فان', 'icon': MdiIcons.vanPassenger},
    {'label': 'سطحة', 'icon': MdiIcons.towTruck},
    {'label': 'أخرى', 'icon': MdiIcons.dotsHorizontal},
  ];

  // Brands, models and colors come from Firestore (lookup_data/vehicles),
  // shared with the customer app. The built-in copy is shown until the
  // document loads, or if it cannot be read.
  VehicleLookups _lookups = VehicleLookups.fallback();

  String? _selectedModel;
  int? _selectedYear;
  String? _modelError;
  String? _yearError;

  /// Next year down to 30 years back, newest first. Built from today's
  /// date, so it never needs editing.
  static List<int> get _yearOptions {
    final int thisYear = DateTime.now().year;
    return [for (int y = thisYear + 1; y >= thisYear - 30; y--) y];
  }

  /// [options] without any stored "أخرى", with one "أخرى" added at the end.
  static List<String> _withOther(List<String> options) => [
    for (final option in options)
      if (option != kOtherOption) option,
    kOtherOption,
  ];

  List<String> get _brandOptions => _withOther(_lookups.brands);
  List<String> get _colorOptions => _withOther(_lookups.colors);

  /// The models of the chosen brand. Empty until a brand is chosen; a
  /// typed-in brand has no list, so its model is typed too.
  List<String> get _modelOptions {
    final String? brand = _selectedBrand;
    if (brand == null) return const [];
    if (brand == kOtherOption) return const [kOtherOption];
    return _withOther(_lookups.models[brand] ?? const []);
  }

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final VehicleLookups lookups = await LookupModel().getVehicleLookups();
    if (!mounted) return;
    setState(() => _lookups = lookups);
  }

  // ============================================================
  // Services Offered — nested structure.
  //
  // Each category has a fixed id (used in code and in the database)
  // and a label (the text shown to the user), with sub-options under it;
  // each option also has a fixed id and a displayed label.
  //
  // Keeping the id separate from the label means the displayed text can
  // change later (translation, rewording...) without breaking any logic or
  // data already saved in Firestore, because the id is the stable reference.
  // ============================================================

  final Map<String, Map<String, dynamic>> _serviceCategories = {
    'battery': {
      'label': 'خدمة البطارية',
      'options': {
        'activation': 'تشغيل البطارية (اشتراك)',
        'replace': 'تغيير البطارية',
      },
    },
    'fuel': {
      'label': 'التزويد بالوقود',
      'options': {'petrol91': 'بنزين 91 (أخضر)', 'petrol95': 'بنزين 95 (أحمر)'},
    },
    'tires': {
      'label': 'خدمة الإطارات',
      'options': {
        'airInflate': 'نفخ الإطار بالهواء',
        'patch': 'ترقيع الإطار',
        'spareChange': 'تغيير الإطار الاحتياطي',
        'newTire': 'تغيير الإطار بإطار جديد',
      },
    },
    'towing': {
      'label': 'خدمة السطحة',
      'options': {'regular': 'سطحة عادية', 'hydraulic': 'سطحة هيدروليكية'},
    },
  };

  // Composite keys in the form "categoryId.optionId" (e.g. "battery.activation")
  // instead of the Arabic text itself, so that:
  // 1) the same text in two different categories never collides.
  // 2) the reference stays stable even if the displayed text changes later.
  final Set<String> _selectedServices = {};

  /// A sedan, SUV, pickup or van cannot tow, so towing is only offered for
  /// the other vehicle types.
  bool get _canTow =>
      vehicleTypeCanTow(_selectedVehicleType?['label'] as String? ?? '');

  String _optionKey(String categoryId, String optionId) =>
      '$categoryId.$optionId';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _otherModelController.dispose();
    _otherVehicleTypeController.dispose();
    _otherBrandController.dispose();
    _otherColorController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // UI helpers
  // ============================================================

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _fieldDecoration(
    String hint, {
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.secondaryText),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _border(AppColors.cardBorder),
      enabledBorder: _border(AppColors.cardBorder),
      focusedBorder: _border(AppColors.blue, 1.6),
      errorBorder: _border(Colors.red),
      focusedErrorBorder: _border(Colors.red, 1.6),
    );
  }

  InputDecorationTheme _dropdownTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _border(AppColors.cardBorder),
      enabledBorder: _border(AppColors.cardBorder),
      focusedBorder: _border(AppColors.blue, 1.6),
      errorBorder: _border(Colors.red),
      focusedErrorBorder: _border(Colors.red, 1.6),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_fieldLabel(label), field],
    );
  }

  Widget _eyeToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.secondaryText,
      ),
    );
  }

  // ---------- Live requirement checklist (password / phone / id) ----------

  Widget _requirementRow(String text, bool valid) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: valid ? Colors.green : AppColors.secondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: valid ? Colors.green : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordRequirements() {
    final String p = _passwordController.text;
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requirementRow(
            '8 خانات على الأقل',
            ProviderRegistrationController.hasMinLength(p),
          ),
          _requirementRow(
            'حرف إنجليزي كبير (A-Z)',
            ProviderRegistrationController.hasUppercase(p),
          ),
          _requirementRow(
            'حرف إنجليزي صغير (a-z)',
            ProviderRegistrationController.hasLowercase(p),
          ),
          _requirementRow(
            'رقم واحد على الأقل',
            ProviderRegistrationController.hasNumber(p),
          ),
          _requirementRow(
            'رمز خاص مثل ! @ # \$',
            ProviderRegistrationController.hasSpecialChar(p),
          ),
        ],
      ),
    );
  }

  Widget _phoneRequirements() {
    final String p = ProviderRegistrationController.normalizeDigits(
      _phoneController.text,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requirementRow('يبدأ بـ 05', p.startsWith('05')),
          _requirementRow('10 خانات فقط', p.length == 10),
        ],
      ),
    );
  }

  Widget _nationalIdRequirements() {
    final String v = ProviderRegistrationController.normalizeDigits(
      _nationalIdController.text,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_requirementRow('10 خانات فقط', v.length == 10)],
      ),
    );
  }

  // Section Card

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      // Material(type: MaterialType.transparency) gives the interactive
      // widgets in this card (InkWell/CheckboxListTile) a nearby Material
      // ancestor, so the touch ripple and background are drawn correctly.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  // Vehicle Type Dropdown

  Widget _vehicleTypeDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<Map<String, dynamic>>(
          width: constraints.maxWidth,
          initialSelection: _selectedVehicleType,
          hintText: 'اختر نوع المركبة',
          errorText: _vehicleTypeError,
          inputDecorationTheme: _dropdownTheme(),
          dropdownMenuEntries: _vehicleTypesWithIcons.map((type) {
            return DropdownMenuEntry<Map<String, dynamic>>(
              value: type,
              label: type['label'],
              leadingIcon: Icon(type['icon'], size: 20, color: AppColors.navy),
            );
          }).toList(),
          onSelected: (value) {
            setState(() {
              _selectedVehicleType = value;
              _vehicleTypeError = null;
              // Drop a towing choice if the new vehicle type cannot tow.
              if (!_canTow) {
                _selectedServices.removeWhere((k) => k.startsWith('towing.'));
              }
              if (value?['label'] != 'أخرى') {
                _otherVehicleTypeController.clear();
              }
            });
          },
        );
      },
    );
  }

  // Brand Dropdown

  Widget _brandDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          // Rebuilt when the Firestore lists arrive.
          key: ObjectKey(_lookups),
          width: constraints.maxWidth,
          initialSelection: _selectedBrand,
          hintText: 'اختر الماركة',
          menuHeight: 320,
          errorText: _brandError,
          inputDecorationTheme: _dropdownTheme(),
          dropdownMenuEntries: _brandOptions.map((brand) {
            return DropdownMenuEntry<String>(value: brand, label: brand);
          }).toList(),
          onSelected: (value) {
            setState(() {
              _selectedBrand = value;
              _brandError = null;
              if (value != kOtherOption) {
                _otherBrandController.clear();
              }
              // A new brand has its own models, so the model starts over.
              // A typed-in brand can only have a typed-in model.
              _selectedModel = value == kOtherOption ? kOtherOption : null;
              _otherModelController.clear();
              _modelError = null;
            });
          },
        );
      },
    );
  }

  // Color Dropdown

  Widget _colorDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          key: ObjectKey(_lookups),
          width: constraints.maxWidth,
          initialSelection: _selectedColor,
          hintText: 'اختر اللون',
          menuHeight: 320,
          errorText: _colorError,
          inputDecorationTheme: _dropdownTheme(),
          dropdownMenuEntries: _colorOptions.map((color) {
            return DropdownMenuEntry<String>(value: color, label: color);
          }).toList(),
          onSelected: (value) {
            setState(() {
              _selectedColor = value;
              _colorError = null;
              if (value != 'أخرى') {
                _otherColorController.clear();
              }
            });
          },
        );
      },
    );
  }

  // Model Dropdown

  Widget _modelDropdown() {
    final List<String> options = _modelOptions;
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          // Rebuilt when the brand or the Firestore lists change, so the
          // list and the selection always belong to the chosen brand.
          key: ValueKey((_selectedBrand, _lookups)),
          width: constraints.maxWidth,
          enabled: options.isNotEmpty,
          initialSelection: _selectedModel,
          hintText: _selectedBrand == null
              ? 'اختر الماركة أولاً'
              : 'اختر الموديل',
          menuHeight: 320,
          errorText: _modelError,
          inputDecorationTheme: _dropdownTheme(),
          dropdownMenuEntries: options.map((model) {
            return DropdownMenuEntry<String>(value: model, label: model);
          }).toList(),
          onSelected: (value) {
            setState(() {
              _selectedModel = value;
              _modelError = null;
              if (value != kOtherOption) {
                _otherModelController.clear();
              }
            });
          },
        );
      },
    );
  }

  // Year Dropdown

  Widget _yearDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<int>(
          width: constraints.maxWidth,
          initialSelection: _selectedYear,
          hintText: 'اختر سنة الصنع',
          errorText: _yearError,
          inputDecorationTheme: _dropdownTheme(),
          menuHeight: 320,
          dropdownMenuEntries: _yearOptions.map((year) {
            return DropdownMenuEntry<int>(value: year, label: '$year');
          }).toList(),
          onSelected: (value) {
            setState(() {
              _selectedYear = value;
              _yearError = null;
            });
          },
        );
      },
    );
  }

  // Service option chip — uses InkWell (not GestureDetector) so it
  // integrates correctly with the ancestor Scrollable's gesture
  // arena. A raw GestureDetector here was the cause of scrolling
  // getting stuck: it competed with the ListView's drag recognizer,
  // especially with mouse input (Android emulator on desktop).
  Widget _serviceChip(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.navy.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected
                  ? AppColors.navy.withValues(alpha: 0.35)
                  : AppColors.cardBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.navy : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Builds the servicesOffered value ready to save in Firestore, as a nested
  // map: each category has a label and a list of options, and each option
  // has an id, a label and enabled (true when it was picked in the form).
  //
  // Note: it saves every option (picked or not) with an enabled flag,
  // instead of only the picked ones, so it is easy later to see all the
  // options for this provider and turn any of them on or off without
  // rebuilding the whole list.
  // ============================================================

  Map<String, dynamic> _buildServicesOfferedPayload() {
    final Map<String, dynamic> payload = {};

    _serviceCategories.forEach((categoryId, categoryData) {
      final String categoryLabel = categoryData['label'] as String;
      final Map<String, String> options = Map<String, String>.from(
        categoryData['options'] as Map,
      );

      payload[categoryId] = {
        'label': categoryLabel,
        'options': options.entries.map((optionEntry) {
          final String optionId = optionEntry.key;
          final String optionLabel = optionEntry.value;

          return {
            'id': optionId,
            'label': optionLabel,
            'enabled': _selectedServices.contains(
              _optionKey(categoryId, optionId),
            ),
          };
        }).toList(),
      };
    });

    return payload;
  }

  // ============================================================
  // Step validation — same rules and messages as before, just
  // split per step.
  // ============================================================

  bool _validatePersonal() {
    return _personalFormKey.currentState!.validate();
  }

  bool _validateVehicle() {
    setState(() {
      _vehicleTypeError = _selectedVehicleType == null
          ? 'الرجاء اختيار نوع المركبة'
          : null;
      _brandError = _selectedBrand == null ? 'الرجاء اختيار الماركة' : null;
      _colorError = _selectedColor == null ? 'الرجاء اختيار اللون' : null;
      _modelError = _selectedModel == null ? 'الرجاء اختيار الموديل' : null;
      _yearError = _selectedYear == null ? 'الرجاء اختيار سنة الصنع' : null;
    });

    final bool formValid = _vehicleFormKey.currentState!.validate();

    if (!formValid ||
        _selectedVehicleType == null ||
        _selectedBrand == null ||
        _selectedColor == null ||
        _selectedModel == null ||
        _selectedYear == null) {
      return false;
    }

    final plate = _plateFieldKey.currentState!.value;
    setState(() => _plateError = plateErrorMessage(plate));
    return plate.isValid;
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _scrollToTop();
  }

  void _goNext() {
    FocusScope.of(context).unfocus();
    if (_step == 0 && !_validatePersonal()) return;
    if (_step == 1 && !_validateVehicle()) return;
    _goToStep(_step + 1);
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_step > 0) _goToStep(_step - 1);
  }

  // Submit

  Future<void> _submitForm() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    // Re-check earlier steps before sending, and jump back to
    // whichever step has a problem.
    if (!_validatePersonal()) {
      _goToStep(0);
      return;
    }
    if (!_validateVehicle()) {
      _goToStep(1);
      return;
    }

    if (_selectedServices.isEmpty) {
      showAppMessage(context, 'الرجاء اختيار خدمة واحدة على الأقل');

      return;
    }

    final plate = _plateFieldKey.currentState!.value;

    setState(() {
      _isLoading = true;
    });

    try {
      final String vehicleType = _selectedVehicleType?['label'] == 'أخرى'
          ? _otherVehicleTypeController.text.trim()
          : (_selectedVehicleType?['label'] ?? '');

      final String brand = _selectedBrand == 'أخرى'
          ? _otherBrandController.text.trim()
          : (_selectedBrand ?? '');

      final String color = _selectedColor == 'أخرى'
          ? _otherColorController.text.trim()
          : (_selectedColor ?? '');

      final String model = _selectedModel == kOtherOption
          ? _otherModelController.text.trim()
          : (_selectedModel ?? '');

      final Map<String, dynamic> servicesToSave =
          _buildServicesOfferedPayload();

      await _authService.registerProvider(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        profile: {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': ProviderRegistrationController.normalizeDigits(
            _phoneController.text.trim(),
          ),
          'nationalId': ProviderRegistrationController.normalizeDigits(
            _nationalIdController.text.trim(),
          ),

          'vehicleType': vehicleType,
          'vehicleBrand': brand,
          'vehicleColor': color,
          'vehicleModel': model,
          'vehicleYear': '$_selectedYear',

          'plateNumberLatin': '${plate.digits} ${plate.englishLetters}',
          'plateNumberArabic': '${plate.digits} ${plate.arabicLetters}',
          'licenseNumber': _licenseNumberController.text.trim(),

          'servicesOffered': servicesToSave,
        },
      );

      if (!mounted) return;

      // AuthGate replaces the signed-out navigator with verification.
    } on AuthException catch (error) {
      if (!mounted) return;

      showAppMessage(context, error.message);
    } catch (e) {
      if (!mounted) return;

      showAppMessage(context, 'حدث خطأ ما. الرجاء المحاولة مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // Header + step indicator
  // ============================================================

  Widget _header() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon/icon.jpg',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تسجيل مزود خدمة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'أكمل بياناتك لإرسال طلب الانضمام.',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(_totalSteps, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: EdgeInsetsDirectional.only(
                  end: i < _totalSteps - 1 ? 6 : 0,
                ),
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.blue : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'الخطوة ${_step + 1} من $_totalSteps',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Step 1 — Personal information
  // ============================================================

  Widget _personalStep() {
    return _sectionCard(
      title: 'المعلومات الشخصية',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _labeled(
                'الاسم الأول',
                BlurTextFormField(
                  controller: _firstNameController,
                  decoration: _fieldDecoration(''),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الاسم الأول';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'اسم العائلة',
                BlurTextFormField(
                  controller: _lastNameController,
                  decoration: _fieldDecoration(''),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال اسم العائلة';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _labeled(
          'رقم الهوية / الإقامة',
          BlurTextFormField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              'أدخل رقم الهوية أو الإقامة',
              icon: Icons.badge_outlined,
            ),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => setState(() {}),
            validator: ProviderRegistrationController.validateNationalId,
          ),
        ),
        _nationalIdRequirements(),
        const SizedBox(height: 16),
        _labeled(
          'رقم الجوال',
          BlurTextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              '05XXXXXXXX',
              icon: Icons.phone_outlined,
            ),
            textInputAction: TextInputAction.next,
            inputFormatters: [ProviderSaudiPhoneInputFormatter()],
            onChanged: (_) => setState(() {}),
            validator: ProviderRegistrationController.validatePhone,
          ),
        ),
        _phoneRequirements(),
        const SizedBox(height: 16),
        _labeled(
          'البريد الإلكتروني',
          BlurTextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              'example@email.com',
              icon: Icons.email_outlined,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال البريد الإلكتروني';
              }
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'الرجاء إدخال بريد إلكتروني صحيح';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        _labeled(
          'كلمة المرور',
          BlurTextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              '',
              icon: Icons.lock_outline,
              suffix: _eyeToggle(
                _obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            validator: ProviderRegistrationController.validatePassword,
          ),
        ),
        _passwordRequirements(),
        const SizedBox(height: 16),
        _labeled(
          'تأكيد كلمة المرور',
          BlurTextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              'أعد كتابة كلمة المرور',
              icon: Icons.lock_outline,
              suffix: _eyeToggle(
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) =>
                ProviderRegistrationController.validateConfirmPassword(
                  value,
                  _passwordController.text,
                ),
          ),
        ),
        const SizedBox(height: 20),

        // Back to login, shown on the first step only.
        Center(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
              children: [
                const TextSpan(text: 'لديك حساب؟ '),
                TextSpan(
                  text: 'سجّل الدخول',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.blue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Step 2 — Vehicle details
  // ============================================================

  Widget _vehicleStep() {
    return _sectionCard(
      title: 'بيانات المركبة',
      children: [
        _fieldLabel('نوع المركبة'),
        _vehicleTypeDropdown(),
        if (_selectedVehicleType?['label'] == 'أخرى') ...[
          const SizedBox(height: 12),
          BlurTextFormField(
            controller: _otherVehicleTypeController,
            decoration: _fieldDecoration('حدد نوع المركبة'),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (_selectedVehicleType?['label'] == 'أخرى' &&
                  (value == null || value.trim().isEmpty)) {
                return 'الرجاء تحديد نوع المركبة';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        _fieldLabel('الماركة'),
        _brandDropdown(),
        if (_selectedBrand == 'أخرى') ...[
          const SizedBox(height: 12),
          BlurTextFormField(
            controller: _otherBrandController,
            decoration: _fieldDecoration('حدد الماركة'),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (_selectedBrand == 'أخرى' &&
                  (value == null || value.trim().isEmpty)) {
                return 'الرجاء تحديد الماركة';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        _fieldLabel('اللون'),
        _colorDropdown(),
        if (_selectedColor == 'أخرى') ...[
          const SizedBox(height: 12),
          BlurTextFormField(
            controller: _otherColorController,
            decoration: _fieldDecoration('حدد اللون'),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (_selectedColor == 'أخرى' &&
                  (value == null || value.trim().isEmpty)) {
                return 'الرجاء تحديد اللون';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        _fieldLabel('الموديل'),
        _modelDropdown(),
        if (_selectedModel == kOtherOption) ...[
          const SizedBox(height: 12),
          BlurTextFormField(
            controller: _otherModelController,
            decoration: _fieldDecoration('حدد الموديل'),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (_selectedModel == kOtherOption &&
                  (value == null || value.trim().isEmpty)) {
                return 'الرجاء تحديد الموديل';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        _fieldLabel('سنة الصنع'),
        _yearDropdown(),
        const SizedBox(height: 16),
        _fieldLabel('رقم اللوحة'),
        const Text(
          'الرجاء إدخال رقم اللوحة بنفس ترتيبه على لوحتك',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _plateError == null
                  ? Colors.transparent
                  : Colors.red.shade700,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PlateNumberField(
            navy: AppColors.navy,
            key: _plateFieldKey,
            // Hide the red plate error as soon as the user edits the plate.
            onChanged: (_) {
              if (_plateError != null) setState(() => _plateError = null);
            },
          ),
        ),
        if (_plateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 14, left: 14),
            child: Text(
              _plateError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        _labeled(
          'رقم الرخصة / التصريح',
          BlurTextFormField(
            controller: _licenseNumberController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              'أدخل رقم الرخصة أو التصريح',
              icon: Icons.assignment_outlined,
            ),
            textInputAction: TextInputAction.done,
            // License numbers are exactly 10 digits.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) {
                return 'الرجاء إدخال رقم الرخصة أو التصريح';
              }
              if (v.length != 10) {
                return 'رقم الرخصة يجب أن يكون 10 أرقام بالضبط';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Step 3 — Services offered
  // ============================================================

  Widget _servicesStep() {
    return _sectionCard(
      title: 'الخدمات المقدمة',
      children: [
        const Text(
          'اختر الخدمات اللي تقدمها (خدمة واحدة على الأقل).',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 16),
        ..._serviceCategories.entries.map((categoryEntry) {
          final String categoryId = categoryEntry.key;
          final Map<String, dynamic> categoryData = categoryEntry.value;
          final String categoryLabel = categoryData['label'] as String;
          final Map<String, String> options = Map<String, String>.from(
            categoryData['options'] as Map,
          );

          if (categoryId == 'towing' && !_canTow) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'خدمة السطحة غير متاحة لنوع مركبتك.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.entries.map((optionEntry) {
                    final String optionId = optionEntry.key;
                    final String optionLabel = optionEntry.value;
                    final String key = _optionKey(categoryId, optionId);
                    final bool isSelected = _selectedServices.contains(key);

                    return _serviceChip(optionLabel, isSelected, () {
                      setState(() {
                        if (isSelected) {
                          _selectedServices.remove(key);
                        } else {
                          _selectedServices.add(key);
                        }
                      });
                    });
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // Bottom navigation buttons
  // ============================================================

  Widget _bottomBar() {
    final bool isLastStep = _step == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('السابق', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (isLastStep ? _submitForm : _goNext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isLastStep ? 'إرسال طلب التسجيل' : 'التالي',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back (app bar arrow or Android back) goes to the previous
      // step; only leaves the screen from step 1.
      canPop: !_isLoading && _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isLoading) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: !_isLoading,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.navy,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: IgnorePointer(
          ignoring: _isLoading,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const _AppScrollBehavior(),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          const SizedBox(height: 20),
                          _stepIndicator(),
                          const SizedBox(height: 16),
                          Visibility(
                            visible: _step == 0,
                            maintainState: true,
                            child: Form(
                              key: _personalFormKey,
                              child: _personalStep(),
                            ),
                          ),
                          Visibility(
                            visible: _step == 1,
                            maintainState: true,
                            child: Form(
                              key: _vehicleFormKey,
                              child: _vehicleStep(),
                            ),
                          ),
                          Visibility(
                            visible: _step == 2,
                            maintainState: true,
                            child: _servicesStep(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Scroll Behavior

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
