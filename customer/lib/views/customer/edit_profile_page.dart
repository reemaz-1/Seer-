import 'package:flutter/material.dart';
 
import '../../controllers/profile_controller.dart';
import '../../core/app_colors.dart';
import '../../models/customer.dart';
 
/// VIEW: edit personal information (user story #6).
/// The email is shown but cannot be edited.
/// Pops with `true` when the changes were saved.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.controller,
    required this.customer,
  });
 
  final ProfileController controller;
  final Customer customer;
 
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}
 
class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
 
  late final _firstName = TextEditingController(text: widget.customer.firstName);
  late final _lastName = TextEditingController(text: widget.customer.lastName);
  late final _phone = TextEditingController(text: widget.customer.phone);
 
  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }
 
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
 
    final updated = widget.customer.copyWith(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: ProfileController.normalizeDigits(_phone.text.trim()),
    );
 
    final error = await widget.controller.saveProfile(updated);
    if (!mounted) return;
 
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.headerText,
        title: const Text(
          'تعديل المعلومات الشخصية',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _LabeledField(
                label: 'الاسم الأول',
                controller: _firstName,
                validator: ProfileController.validateName,
              ),
              _LabeledField(
                label: 'اسم العائلة',
                controller: _lastName,
                validator: ProfileController.validateName,
              ),
              _LabeledField(
                label: 'رقم الجوال',
                controller: _phone,
                validator: ProfileController.validatePhone,
                keyboardType: TextInputType.phone,
                hint: '05XXXXXXXX',
                ltr: true,
              ),
              _ReadOnlyField(
                label: 'البريد الإلكتروني',
                value: widget.customer.email,
                note: 'لا يمكن تغيير البريد الإلكتروني',
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final saving = widget.controller.isSaving;
                  return FilledButton(
                    onPressed: saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.accentDisabled,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'حفظ التعديلات',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.hint,
    this.ltr = false,
  });
 
  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final String? hint;
  final bool ltr; // phone numbers are typed left-to-right
 
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
 
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textDirection: ltr ? TextDirection.ltr : null,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintTextDirection: ltr ? TextDirection.ltr : null,
              filled: true,
              fillColor: AppColors.cardFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: border(AppColors.cardBorder),
              focusedBorder: border(AppColors.accent, 1.5),
              errorBorder: border(AppColors.danger),
              focusedErrorBorder: border(AppColors.danger, 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
 
/// A field the user can see but not change (used for the email).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.note,
  });
 
  final String label;
  final String value;
  final String note;
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.lock_outline, size: 18, color: AppColors.chevron),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
            child: Text(
              note,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
 