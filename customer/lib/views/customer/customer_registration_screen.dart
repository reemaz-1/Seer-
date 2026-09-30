import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_snackbar.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      await userCredential.user!.sendEmailVerification();

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(userCredential.user!.uid)
          .set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      showAppMessage(
        context,
        'تم إنشاء الحساب! الرجاء التحقق من بريدك الإلكتروني.',
        isError: false,
      );

      Navigator.of(context).popUntil((route) => route.isFirst);

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
      showAppMessage(context, message);
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

  // ---------- UI helpers ----------

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: CustomerColors.primaryText,
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: CustomerColors.secondaryText),
      prefixIcon: Icon(icon, color: CustomerColors.secondaryText),
      suffixIcon: suffix,
      filled: true,
      fillColor: CustomerColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _border(CustomerColors.cardBorder),
      enabledBorder: _border(CustomerColors.cardBorder),
      focusedBorder: _border(CustomerColors.accent, 1.6),
      errorBorder: _border(AppStatusColors.error),
      focusedErrorBorder: _border(AppStatusColors.error, 1.6),
    );
  }

  Widget _eyeToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: CustomerColors.secondaryText,
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor: CustomerColors.background,
        foregroundColor: CustomerColors.darkPanel,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/icon.jpg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'سير',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: CustomerColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'إنشاء حساب جديد',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: CustomerColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أنشئ حسابك لطلب المساعدة لمركبتك بسهولة.',
                  style: TextStyle(
                    fontSize: 14,
                    color: CustomerColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),

                // First + last name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('الاسم الأول'),
                          TextFormField(
                            controller: _firstNameController,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              hint: 'محمد',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال الاسم الأول';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('اسم العائلة'),
                          TextFormField(
                            controller: _lastNameController,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              hint: 'العتيبي',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال اسم العائلة';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Phone
                _fieldLabel('رقم الجوال'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    hint: '05XXXXXXXX',
                    icon: Icons.phone_outlined,
                  ),
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
                const SizedBox(height: 20),

                // Email
                _fieldLabel('البريد الإلكتروني'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                  ),
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
                const SizedBox(height: 20),

                // Password
                _fieldLabel('كلمة المرور'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    hint: '8 أحرف على الأقل',
                    icon: Icons.lock_outline,
                    suffix: _eyeToggle(
                      _obscurePassword,
                      () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
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
                const SizedBox(height: 20),

                // Confirm password
                _fieldLabel('تأكيد كلمة المرور'),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.done,
                  decoration: _fieldDecoration(
                    hint: 'أعد كتابة كلمة المرور',
                    icon: Icons.lock_outline,
                    suffix: _eyeToggle(
                      _obscureConfirm,
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
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
                const SizedBox(height: 32),

                // Submit
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomerColors.darkPanel,
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
                        : const Text(
                            'إنشاء حساب',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Back to login
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: CustomerColors.primaryText,
                      ),
                      children: [
                        const TextSpan(text: 'لديك حساب؟ '),
                        TextSpan(
                          text: 'سجّل الدخول',
                          style: const TextStyle(
                            color: CustomerColors.accent,
                            fontWeight: FontWeight.bold,
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
            ),
          ),
        ),
      ),
    );
  }
}
