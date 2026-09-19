import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'provider_success_screen.dart';
import 'plate_number_input.dart';


class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

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

  static const Color navy = Color(0xFF0F1B4C);

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
    {
      'label': 'سيدان',
      'icon': MdiIcons.carSide,
    },
    {
      'label': 'دفع رباعي',
      'icon': MdiIcons.carEstate,
    },
    {
      'label': 'بيك أب',
      'icon': MdiIcons.carPickup,
    },
    {
      'label': 'فان',
      'icon': MdiIcons.vanPassenger,
    },
    {
      'label': 'سطحة',
      'icon': MdiIcons.towTruck,
    },
    {
      'label': 'أخرى',
      'icon': MdiIcons.dotsHorizontal,
    },
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
    'چانجان',
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
    'بني',
    'ذهبي',
    'بيج',
    'أخضر',
    'أخرى',
  ];

  // كل خدمة رئيسية مرتبطة بقائمة خياراتها الفرعية.
  final Map<String, List<String>> _servicesWithOptions = {
    'خدمة البطارية': ['تشغيل البطارية (اشتراك)', 'تغيير البطارية'],
    'التزويد بالوقود': ['بنزين 91 (أخضر)', 'بنزين 95 (أحمر)'],
    'خدمة الإطارات': [
      'نفخ الإطار بالهواء',
      'ترقيع الإطار',
      'تغيير الإطار الاحتياطي',
      'تغيير الإطار بإطار جديد',
    ],
    'خدمة السطحة': ['سطحة عادية', 'سطحة هيدروليكية'],
  };

  final Set<String> _selectedServices = {};

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

  // Input Decoration

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: navy,
          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  // Section Card

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 16),

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
          label: const Text('نوع المركبة'),
          errorText: _vehicleTypeError,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          dropdownMenuEntries: _vehicleTypesWithIcons.map((type) {
            return DropdownMenuEntry<Map<String, dynamic>>(
              value: type,
              label: type['label'],
              leadingIcon: Icon(type['icon'], size: 20, color: navy),
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
          label: const Text('الماركة'),
          errorText: _brandError,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
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
          label: const Text('اللون'),
          errorText: _colorError,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
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
            color: isSelected ? navy.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? navy.withOpacity(0.35) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? navy : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  // Submit

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _vehicleTypeError =
          _selectedVehicleType == null ? 'الرجاء اختيار نوع المركبة' : null;
      _brandError = _selectedBrand == null ? 'الرجاء اختيار الماركة' : null;
      _colorError = _selectedColor == null ? 'الرجاء اختيار اللون' : null;
    });

    final bool formValid = _formKey.currentState!.validate();

    if (!formValid ||
        _selectedVehicleType == null ||
        _selectedBrand == null ||
        _selectedColor == null) {
      return;
    }

    final plate = _plateFieldKey.currentState!.value;
    setState(() => _plateError = !plate.isValid);
    if (!plate.isValid) {
      return;
    }

    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء اختيار خدمة واحدة على الأقل',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await userCredential.user!.sendEmailVerification();

      final String vehicleType = _selectedVehicleType?['label'] == 'أخرى'
          ? _otherVehicleTypeController.text.trim()
          : (_selectedVehicleType?['label'] ?? '');

      final String brand = _selectedBrand == 'أخرى'
          ? _otherBrandController.text.trim()
          : (_selectedBrand ?? '');

      final String color = _selectedColor == 'أخرى'
          ? _otherColorController.text.trim()
          : (_selectedColor ?? '');

      final List<String> servicesToSave = _selectedServices.toList();

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(userCredential.user!.uid)
          .set({
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

        'status': 'pending',

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ProviderSuccessScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ ما. الرجاء المحاولة مرة أخرى.';

      if (e.code == 'email-already-in-use') {
        message = 'هذا البريد الإلكتروني مسجل مسبقًا.';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جدًا.';
      } else if (e.code == 'invalid-email') {
        message = 'الرجاء إدخال بريد إلكتروني صحيح.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدث خطأ ما. الرجاء المحاولة مرة أخرى.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),

      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,

        title: const Text(
          'تسجيل مزود خدمة',
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const _AppScrollBehavior(),

          child: Form(
            key: _formKey,

            // هذا هو الـ Scroll الوحيد للفورم كاملًا
            child: ListView(
              controller: _scrollController,

              physics: const ClampingScrollPhysics(),

              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,

              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),

              children: [
                // ======================================================
                // Personal Information
                // ======================================================

                _sectionCard(
                  title: 'المعلومات الشخصية',
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: _fieldDecoration('الاسم الأول'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال الاسم الأول';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _lastNameController,
                      decoration: _fieldDecoration('اسم العائلة'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال اسم العائلة';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nationalIdController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration('رقم الهوية / الإقامة'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال رقم الهوية أو الإقامة';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDecoration('رقم الجوال'),
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

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration('البريد الإلكتروني'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال البريد الإلكتروني';
                        }

                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );

                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'الرجاء إدخال بريد إلكتروني صحيح';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _fieldDecoration('كلمة المرور'),
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

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: _fieldDecoration('تأكيد كلمة المرور'),
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
                  ],
                ),

                const SizedBox(height: 16),

                // ======================================================
                // Vehicle Details
                // ======================================================

                _sectionCard(
                  title: 'بيانات المركبة',
                  children: [
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

                    const SizedBox(height: 12),

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

                    const SizedBox(height: 12),

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

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _modelController,
                      decoration: _fieldDecoration('الموديل (مثال: كامري)'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال الموديل';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration('السنة (مثال: 2023)'),
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

                    const SizedBox(height: 12),

                    Text(
                      'رقم اللوحة',
                      style: TextStyle(fontWeight: FontWeight.bold, color: navy),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الرجاء إدخال رقم اللوحة بنفس ترتيبه على لوحتك',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    PlateNumberField(navy: navy, key: _plateFieldKey),
                    if (_plateError)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'الرجاء إدخال رقم وحرف واحد على الأقل',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: _fieldDecoration('رقم الرخصة / التصريح'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال رقم الرخصة أو التصريح';
                        }

                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ======================================================
                // Services Offered — A heading for each category, with selectable options underneath.
                // ======================================================

                _sectionCard(
                  title: 'الخدمات المقدمة',
                  children: _servicesWithOptions.entries.map((entry) {
                    final String category = entry.key;
                    final List<String> options = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: navy,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: options.map((option) {
                              final bool isSelected =
                                  _selectedServices.contains(option);

                              return _serviceChip(option, isSelected, () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedServices.remove(option);
                                  } else {
                                    _selectedServices.add(option);
                                  }
                                });
                              });
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

              // ======================================================
              // Registration button
              // ======================================================

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'إرسال طلب التسجيل',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
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