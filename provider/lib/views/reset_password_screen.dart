import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../controllers/provider_registration_controller.dart';

// Handles a Firebase password-reset link inside the Provider app.
// The same password policy as registration is used before calling Firebase.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.code});
  final String code;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _verified = false;
  bool _complete = false;
  bool _showPassword = false;
  bool _showConfirmation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  // Checks the reset code, then checks that the email belongs to a provider
  // profile. A valid Firebase Auth email alone does not prove the app role.
  // A failed Firestore lookup blocks the reset rather than guessing the role.
  Future<void> _verify() async {
    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(widget.code);
      final profiles = await FirebaseFirestore.instance
          .collection('providers')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (!mounted) return;
      if (profiles.docs.isEmpty) {
        setState(() => _error = 'هذا البريد مرتبط بحساب عميل، وليس بحساب مزود خدمة. يجب فتح رابط الاستعادة في تطبيق العميل.');
        return;
      }
      setState(() => _verified = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.code == 'expired-action-code' || error.code == 'invalid-action-code'
          ? 'رابط إعادة التعيين غير صالح أو انتهت صلاحيته. يمكن طلب رابط جديد من صفحة تسجيل الدخول.'
          : 'تعذر التحقق من الرابط. يرجى المحاولة مرة أخرى.');
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر التحقق من نوع الحساب. يرجى التحقق من اتصال الإنترنت والمحاولة مجددًا.');
    }
  }

  // Validates the registration password policy locally. Firebase is called
  // only when the password and its confirmation both pass validation.
  Future<void> _save() async {
    if (_busy || !_verified || !_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.code,
        newPassword: _password.text,
      );
      if (mounted) setState(() => _complete = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'weak-password' || 'password-does-not-meet-requirements' =>
          'كلمة المرور لا تستوفي شروط التسجيل. يجب استيفاء المتطلبات الموضحة.',
        'expired-action-code' || 'invalid-action-code' =>
          'رابط إعادة التعيين غير صالح أو انتهت صلاحيته. يمكن طلب رابط جديد من صفحة تسجيل الدخول.',
        'network-request-failed' => 'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
        _ => 'تعذر تغيير كلمة المرور. يرجى المحاولة مرة أخرى.',
      };
      setState(() => _error = message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال. يرجى المحاولة مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  //Displays the same five live password requirements used at registration.
  Widget _requirement(String label, bool valid) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(valid ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              color: valid ? Colors.green : Colors.grey, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _requirements() {
    final password = _password.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _requirement('8 خانات على الأقل', ProviderRegistrationController.hasMinLength(password)),
      _requirement('حرف إنجليزي كبير (A-Z)', ProviderRegistrationController.hasUppercase(password)),
      _requirement('حرف إنجليزي صغير (a-z)', ProviderRegistrationController.hasLowercase(password)),
      _requirement('رقم واحد على الأقل', ProviderRegistrationController.hasNumber(password)),
      _requirement('رمز خاص مثل ! @ # \$', ProviderRegistrationController.hasSpecialChar(password)),
    ]);
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إعادة تعيين كلمة المرور')),
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: _complete
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                const SizedBox(height: 16),
                const Text('تم تغيير كلمة المرور بنجاح.'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(),
                    child: const Text('العودة لتسجيل الدخول')),
              ])
            : !_verified
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_error == null) const CircularProgressIndicator(),
                    if (_error != null) Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (_error != null) TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('العودة لتسجيل الدخول')),
                  ])
                : Form(key: _formKey, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('إنشاء كلمة مرور جديدة',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الجديدة',
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: ProviderRegistrationController.validatePassword,
                      ),
                      const SizedBox(height: 10),
                      _requirements(),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: !_showConfirmation,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirmation ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showConfirmation = !_showConfirmation),
                          ),
                        ),
                        validator: (value) => ProviderRegistrationController.validateConfirmPassword(
                            value, _password.text),
                      ),
                      if (_error != null) Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _busy ? null : _save,
                          child: Text(_busy ? 'جارٍ الحفظ...' : 'تأكيد كلمة المرور')),
                    ],
                  )),
      ),
    ))),
  );
}
