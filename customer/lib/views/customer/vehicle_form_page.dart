import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/vehicle_controller.dart';
import '../../core/app_colors.dart';
import '../../models/vehicle.dart';

/// VIEW: add a vehicle (#7), or edit (#9) / delete (#10) an existing one.
/// Pops with a success message to show, or null if nothing changed.
class VehicleFormPage extends StatefulWidget {
  const VehicleFormPage({super.key, required this.uid, this.vehicle});

  final String uid;

  /// null = add a new vehicle, otherwise edit this one.
  final Vehicle? vehicle;

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = VehicleController(uid: widget.uid);
  final _years = VehicleController.yearOptions;

  bool get _isEdit => widget.vehicle != null;

  late final (String, String) _initialPlate = widget.vehicle == null
      ? ('', '')
      : VehicleController.splitPlate(widget.vehicle!.plateNumber);

  late final _brand = TextEditingController(text: widget.vehicle?.brand ?? '');
  late final _model = TextEditingController(text: widget.vehicle?.model ?? '');
  late final _plateLetters = TextEditingController(text: _initialPlate.$1);
  late final _plateDigits = TextEditingController(text: _initialPlate.$2);
  late int? _year =
      _years.contains(widget.vehicle?.year) ? widget.vehicle!.year : null;

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _plateLetters.dispose();
    _plateDigits.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------- Actions ----------------

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? '', // empty id = new vehicle
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      year: _year!,
      plateNumber: VehicleController.buildPlate(_plateLetters.text, _plateDigits.text),
    );

    final error = await _controller.saveVehicle(vehicle);
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
      return;
    }
    Navigator.of(context).pop(_isEdit ? 'تم حفظ التعديلات' : 'تمت إضافة المركبة');
  }

  Future<void> _delete() async {
    final vehicle = widget.vehicle!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المركبة'),
        content: Text('هل تريد حذف ${vehicle.title}؟ لا يمكن التراجع عن الحذف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('حذف المركبة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await _controller.deleteVehicle(vehicle);
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
      return;
    }
    Navigator.of(context).pop('تم حذف المركبة');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final inputStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: 15,
          color: AppColors.textPrimary,
        );
    final plateStyle = inputStyle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.headerText,
        title: Text(
          _isEdit ? 'تعديل المركبة' : 'إضافة مركبة',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final saving = _controller.isSaving;

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const _FieldLabel('الشركة المصنعة'),
                  TextFormField(
                    controller: _brand,
                    enabled: !saving,
                    validator: VehicleController.validateBrand,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    style: inputStyle,
                    decoration: _decoration(hint: 'مثال: تويوتا'),
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel('الطراز'),
                  TextFormField(
                    controller: _model,
                    enabled: !saving,
                    validator: VehicleController.validateModel,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    style: inputStyle,
                    decoration: _decoration(hint: 'مثال: كامري'),
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel('سنة الصنع'),
                  DropdownButtonFormField<int>(
                    initialValue: _year,
                    items: [
                      for (final y in _years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: saving ? null : (value) => setState(() => _year = value),
                    validator: VehicleController.validateYear,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    hint: const Text('اختر السنة'),
                    menuMaxHeight: 320,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: Colors.white,
                    style: inputStyle,
                    decoration: _decoration(),
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel('لوحة المركبة'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('الحروف (بالإنجليزية)', small: true),
                            TextFormField(
                              controller: _plateLetters,
                              enabled: !saving,
                              validator: VehicleController.validatePlateLetters,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                _UpperCaseFormatter(),
                                LengthLimitingTextInputFormatter(3),
                              ],
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: plateStyle,
                              decoration: _decoration(hint: 'ABD'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('الأرقام', small: true),
                            TextFormField(
                              controller: _plateDigits,
                              enabled: !saving,
                              validator: VehicleController.validatePlateDigits,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
                                LengthLimitingTextInputFormatter(4),
                              ],
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: plateStyle,
                              decoration: _decoration(hint: '1234'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  FilledButton(
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
                        : Text(
                            _isEdit ? 'حفظ التعديلات' : 'إضافة المركبة',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),

                  if (_isEdit) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text(
                        'حذف المركبة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA1B0), letterSpacing: 0),
      errorMaxLines: 2,
      filled: true,
      fillColor: AppColors.cardFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(AppColors.cardBorder),
      disabledBorder: border(AppColors.cardBorder),
      focusedBorder: border(AppColors.accent, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 12 : 13,
          fontWeight: small ? FontWeight.w500 : FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Turns "abd" into "ABD" while typing.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
