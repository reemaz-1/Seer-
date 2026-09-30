import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';

/// Log In screen — works for both apps; pass [role] to pick the
/// matching color theme (Customer = Icon Navy, Provider = Fleet Blue).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final AppRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.logIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('اكتب بريدك الإلكتروني أولاً ثم اضغط "نسيت كلمة المرور".');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      showAppMessage(context, 'تم إرسال رابط إعادة التعيين إلى بريدك.',
          isError: false);
          
    } on AuthException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message, {bool isError = true}) {
    if (!mounted) return;
    showAppMessage(context, message, isError: isError);
  }

  bool get _isCustomer => widget.role == AppRole.customer;

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCustomer ? 'مرحباً بعودتك' : 'سجّل الدخول';
    final subtitle = _isCustomer
        ? 'سجّل الدخول لطلب المساعدة لمركبتك.'
        : 'سجّل الدخول لمتابعة طلبات الخدمة الخاصة بك.';
    final brandLabel = _isCustomer ? 'سير' : 'سير لمزودي الخدمة';

    return Theme(
      data: AppTheme.of(widget.role),
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          Text(
                            brandLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        title,
                        style: textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 36),
                      _fieldLabel(context, 'البريد الإلكتروني'),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'أدخل بريدك الإلكتروني';
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'صيغة البريد الإلكتروني غير صحيحة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _fieldLabel(context, 'كلمة المرور'),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'أدخل كلمة المرور';
                          }
                          if (value.length < 8) {
                            return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleForgotPassword,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
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
                                  'تسجيل الدخول',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: _isCustomer
                                    ? 'ليس لديك حساب؟ '
                                    : 'مزود خدمة جديد؟ ',
                              ),
                              TextSpan(
                                text: 'سجّل الآن',
                                style: TextStyle(
                                  color: _isCustomer
                                      ? CustomerColors.accent
                                      : ProviderColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: (TapGestureRecognizer()
                                  ..onTap = _isLoading
                                      ? null
                                      : () {
                                          Navigator.of(context)
                                              .pushNamed('/register');
                                        }),
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
        },
      ),
    );
  }
}
