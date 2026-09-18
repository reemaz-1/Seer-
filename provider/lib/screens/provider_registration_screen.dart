import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

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
  final _plateNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _otherVehicleTypeController = TextEditingController();
  final _otherBrandController = TextEditingController();
  final _otherServiceController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  static const Color navy = Color(0xFF0F1B4C);

  Map<String, dynamic>? _selectedVehicleType;
  String? _selectedBrand;
  String? _vehicleTypeError;
  String? _brandError;

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

  final List<String> _availableServices = [
    'خدمة البطارية',
    'التزويد بالوقود',
    'خدمة الإطارات',
    'سطحة نقل',
    'أخرى',
  ];

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
    _plateNumberController.dispose();
    _licenseNumberController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _otherVehicleTypeController.dispose();
    _otherBrandController.dispose();
    _otherServiceController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // Input Decoration
  // ============================================================

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

  // ============================================================
  // Section Card
  // ============================================================

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
      // ancestor للـ CheckboxListTile داخل هالكرت، عشان تأثير اللمس
      // (ripple) والخلفية يرسمهم صح، ويشيل تحذير:
      // "ListTile background color or ink splashes may be invisible."
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

  // ============================================================
  // Vehicle Type Dropdown
  // ============================================================

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

  // ============================================================
  // Brand Dropdown
  // ============================================================

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

  // ============================================================
  // Submit
  // ============================================================

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _vehicleTypeError =
          _selectedVehicleType == null ? 'الرجاء اختيار نوع المركبة' : null;
      _brandError = _selectedBrand == null ? 'الرجاء اختيار الماركة' : null;
    });

    final bool formValid = _formKey.currentState!.validate();

    if (!formValid || _selectedVehicleType == null || _selectedBrand == null) {
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

      final List<String> servicesToSave = _selectedServices.map((service) {
        if (service == 'أخرى') {
          return _otherServiceController.text.trim();
        }

        return service;
      }).toList();

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
        'vehicleModel': _modelController.text.trim(),
        'vehicleYear': _yearController.text.trim(),

        'plateNumber': _plateNumberController.text.trim(),

        'licenseNumber': _licenseNumberController.text.trim(),

        'servicesOffered': servicesToSave,

        'status': 'pending',

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب التسجيل! سيتم مراجعته من قبل الإدارة.',
          ),
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

  // ============================================================
  // BUILD
  // ============================================================

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
                // المعلومات الشخصية
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
                // بيانات المركبة
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

                    TextFormField(
                      controller: _plateNumberController,
                      decoration: _fieldDecoration('رقم اللوحة'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال رقم اللوحة';
                        }

                        return null;
                      },
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
                // الخدمات المقدمة
                // ======================================================

                _sectionCard(
                  title: 'الخدمات المقدمة',
                  children: [
                    ..._availableServices.map(
                      (service) {
                        final bool isSelected =
                            _selectedServices.contains(service);

                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(service),
                          activeColor: navy,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedServices.add(service);
                              } else {
                                _selectedServices.remove(service);

                                if (service == 'أخرى') {
                                  _otherServiceController.clear();
                                }
                              }
                            });
                          },
                        );
                      },
                    ),

                    if (_selectedServices.contains('أخرى')) ...[
                      const SizedBox(height: 4),

                      TextFormField(
                        controller: _otherServiceController,
                        decoration: _fieldDecoration('حدد الخدمة الأخرى'),
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (_selectedServices.contains('أخرى') &&
                              (value == null || value.trim().isEmpty)) {
                            return 'الرجاء تحديد الخدمة';
                          }

                          return null;
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ======================================================
                // زر التسجيل
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

// ============================================================
// Scroll Behavior
// ============================================================

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