import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import '../theme/app_colors.dart';

import '../services/auth_service.dart';
import 'provider_success_screen.dart';
import '../widgets/plate_number_input.dart';
import '../widgets/app_snackbar.dart';

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
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
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
  bool _plateError = false;

  final List<Map<String, dynamic>> _vehicleTypesWithIcons = [
    {'label': 'سيدان', 'icon': MdiIcons.carSide},
    {'label': 'دفع رباعي', 'icon': MdiIcons.carEstate},
    {'label': 'بيك أب', 'icon': MdiIcons.carPickup},
    {'label': 'فان', 'icon': MdiIcons.vanPassenger},
    {'label': 'سطحة', 'icon': MdiIcons.towTruck},
    {'label': 'أخرى', 'icon': MdiIcons.dotsHorizontal},
  ];

  final List<String> _vehicleBrands = [
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
    'أخرى',
  ];

  final List<String> _vehicleColors = [
    'أبيض',
    'أسود',
    'فضي',
    'رمادي',
    'برتقالي',
    'أحمر',
    'أزرق',
    'كحلي',
    'بني',
    'ذهبي',
    'بيج',
    'أخضر',
    'أخرى',
  ];

  // ============================================================
  // Services Offered — nested structure.
  //
  // كل فئة رئيسية لها id ثابت (يُستخدم بالكود وبقاعدة البيانات)
  // ولها label (النص المعروض للمستخدم)، وتحتها خيارات فرعية،
  // كل خيار له id ثابت و label معروض.
  //
  // فصل id عن label يخلي تغيير النص المعروض لاحقًا (ترجمة، تعديل
  // صياغة...) لا يكسر أي منطق أو بيانات محفوظة سابقًا في Firestore،
  // لأن الـ id هو المرجع الثابت وليس النص نفسه.
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

  // مفاتيح مركّبة بصيغة "categoryId.optionId" (مثال: "battery.activation")
  // بدل تخزين النص العربي نفسه، عشان:
  // 1) ما يصير تصادم لو تكرر نفس النص بفئتين مختلفتين.
  // 2) ثبات المرجع حتى لو تغيّر النص المعروض لاحقًا.
  final Set<String> _selectedServices = {};

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
    _modelController.dispose();
    _yearController.dispose();
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
      prefixIcon:
          icon == null ? null : Icon(icon, color: AppColors.secondaryText),
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
      // Material(type: MaterialType.transparency) يعطي أقرب Material
      // ancestor للعناصر التفاعلية (InkWell/CheckboxListTile) داخل
      // هالكرت، عشان تأثير اللمس (ripple) والخلفية يرسمهم صح.
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
          width: constraints.maxWidth,
          initialSelection: _selectedBrand,
          hintText: 'اختر الماركة',
          errorText: _brandError,
          inputDecorationTheme: _dropdownTheme(),
          dropdownMenuEntries: _vehicleBrands.map((brand) {
            return DropdownMenuEntry<String>(value: brand, label: brand);
          }).toList(),
          onSelected: (value) {
            setState(() {
              _selectedBrand = value;
              _brandError = null;
              if (value != 'أخرى') {
                _otherBrandController.clear();
              }
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
          width: constraints.maxWidth,
          initialSelection: _selectedColor,
          hintText: 'اختر اللون',
          errorText: _colorError,
          inputDecorationTheme: _dropdownTheme(),
          dropdownMenuEntries: _vehicleColors.map((color) {
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
  // يبني نسخة servicesOffered الجاهزة للحفظ في Firestore، كـ map
  // متداخل: كل فئة فيها label وقائمة options، كل خيار فيه id و
  // label و enabled (true إذا كان مختار في الفورم).
  //
  // ملاحظة: يحفظ كل الخيارات (المختارة وغير المختارة) مع enabled
  // flag، بدل ما يحفظ بس المختارة، عشان يسهل لاحقًا معرفة كل
  // الخيارات المتاحة لهذا المزود وتفعيل/تعطيل أي وحدة منها بدون
  // إعادة بناء القائمة كاملة.
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
    });

    final bool formValid = _vehicleFormKey.currentState!.validate();

    if (!formValid ||
        _selectedVehicleType == null ||
        _selectedBrand == null ||
        _selectedColor == null) {
      return false;
    }

    final plate = _plateFieldKey.currentState!.value;
    setState(() => _plateError = !plate.isValid);
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

      final Map<String, dynamic> servicesToSave =
          _buildServicesOfferedPayload();

      final verificationEmailSent = await _authService.registerProvider(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        profile: {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'nationalId': _nationalIdController.text.trim(),

          'vehicleType': vehicleType,
          'vehicleBrand': brand,
          'vehicleColor': color,
          'vehicleModel': _modelController.text.trim(),
          'vehicleYear': _yearController.text.trim(),

          'plateNumberLatin': '${plate.digits} ${plate.englishLetters}',
          'plateNumberArabic': '${plate.digits} ${plate.arabicLetters}',
          'licenseNumber': _licenseNumberController.text.trim(),

          'servicesOffered': servicesToSave,
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProviderSuccessScreen(
            verificationEmailSent: verificationEmailSent,
          ),
        ),
      );
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
                TextFormField(
                  controller: _firstNameController,
                  decoration: _fieldDecoration('محمد'),
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
                TextFormField(
                  controller: _lastNameController,
                  decoration: _fieldDecoration('العتيبي'),
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
          TextFormField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              'أدخل رقم الهوية أو الإقامة',
              icon: Icons.badge_outlined,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال رقم الهوية أو الإقامة';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        _labeled(
          'رقم الجوال',
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              '05XXXXXXXX',
              icon: Icons.phone_outlined,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال رقم الجوال';
              }
              if (value.trim().length < 9) {
                return 'الرجاء إدخال رقم جوال صحيح';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        _labeled(
          'البريد الإلكتروني',
          TextFormField(
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
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            decoration: _fieldDecoration(
              '8 أحرف على الأقل',
              icon: Icons.lock_outline,
              suffix: _eyeToggle(
                _obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال كلمة المرور';
              }
              if (value.length < 8) {
                return 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        _labeled(
          'تأكيد كلمة المرور',
          TextFormField(
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء تأكيد كلمة المرور';
              }
              if (value != _passwordController.text) {
                return 'كلمتا المرور غير متطابقتين';
              }
              return null;
            },
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
          TextFormField(
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
          TextFormField(
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
          TextFormField(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _labeled(
                'الموديل',
                TextFormField(
                  controller: _modelController,
                  decoration: _fieldDecoration('مثال: كامري'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الموديل';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'السنة',
                TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('مثال: 2023'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال السنة';
                    }
                    final year = int.tryParse(value.trim());
                    if (year == null || value.trim().length != 4) {
                      return 'الرجاء إدخال سنة صحيحة';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _fieldLabel('رقم اللوحة'),
        const Text(
          'الرجاء إدخال رقم اللوحة بنفس ترتيبه على لوحتك',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 10),
        PlateNumberField(navy: AppColors.navy, key: _plateFieldKey),
        if (_plateError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'الرجاء إدخال رقم وحرف واحد على الأقل',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        _labeled(
          'رقم الرخصة / التصريح',
          TextFormField(
            controller: _licenseNumberController,
            decoration: _fieldDecoration(
              'أدخل رقم الرخصة أو التصريح',
              icon: Icons.assignment_outlined,
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال رقم الرخصة أو التصريح';
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
