import 'package:flutter/material.dart';

import '../../controllers/vehicle_controller.dart';
import '../../theme/app_colors.dart'; 
import '../../models/lookup_model.dart';
import '../../models/vehicle.dart';
import '../../widgets/plate_number_field.dart';

/// VIEW: add a vehicle (#7), or edit (#9) / delete (#10) an existing one.
/// Pops with a success message to show, or null if nothing changed.
///
/// Brand, model and color are dropdowns. Each ends with "أخرى", which opens a
/// text field so a value missing from the list never blocks the customer.
/// The model list depends on the chosen brand.
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
  final _plateKey = GlobalKey<PlateNumberFieldState>();
  late final _controller = VehicleController(uid: widget.uid);
  final _years = VehicleController.yearOptions;

  bool get _isEdit => widget.vehicle != null;

  // Each dropdown keeps what was picked, plus what was typed if that was "أخرى".
  String? _brand;
  final _brandOther = TextEditingController();
  String? _model;
  final _modelOther = TextEditingController();
  String? _color;
  final _colorOther = TextEditingController();
  int? _year;

  late final (String, String) _initialPlate = widget.vehicle == null
      ? ('', '')
      : VehicleController.splitPlate(widget.vehicle!.plateNumberArabic);

  /// The plate is a custom widget, not a FormField, so its error is kept here.
  String? _plateError;

  @override
  void initState() {
    super.initState();
    _loadThenFill();
  }

  @override
  void dispose() {
    _brandOther.dispose();
    _modelOther.dispose();
    _colorOther.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The dropdowns can only be filled once the shared lists are known, so the
  /// form waits for them and then puts the saved vehicle into the fields.
  Future<void> _loadThenFill() async {
    await _controller.loadLookups();
    if (!mounted) return;

    final vehicle = widget.vehicle;
    if (vehicle == null) return;

    final brand = _split(vehicle.brand, _controller.brandOptions(null));
    final color = _split(vehicle.color, _controller.colorOptions(null));

    setState(() {
      _brand = brand.$1;
      _brandOther.text = brand.$2;
      _color = color.$1;
      _colorOther.text = color.$2;
      _year = _years.contains(vehicle.year) ? vehicle.year : null;

      final model = _split(vehicle.model, _modelOptions);
      _model = model.$1;
      _modelOther.text = model.$2;
    });
  }

  /// A saved value either matches an option, or becomes "أخرى" plus text.
  static (String?, String) _split(String saved, List<String> options) {
    if (saved.isEmpty) return (null, '');
    if (options.contains(saved)) return (saved, '');
    return (kOtherOption, saved);
  }

  /// The models of the chosen brand. A typed-in brand has no list of its own,
  /// so the model is typed as well.
  List<String> get _modelOptions {
    if (_brand == null) return const [];
    if (_brand == kOtherOption) return const [kOtherOption];
    return _controller.modelOptions(_brand);
  }

  String _valueOf(String? selection, TextEditingController other) =>
      selection == kOtherOption ? other.text.trim() : (selection ?? '');

  // ---------------- Actions ----------------

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final plate = _plateKey.currentState!.value;
    final plateError = VehicleController.validatePlate(
      digits: plate.digits,
      arabicLetters: plate.arabicLetters,
    );
    setState(() => _plateError = plateError);

    final formOk = _formKey.currentState!.validate();
    if (!formOk || plateError != null) return;

    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? '', // empty id = new vehicle
      brand: _valueOf(_brand, _brandOther),
      model: _valueOf(_model, _modelOther),
      year: _year!,
      color: _valueOf(_color, _colorOther),
      plateNumberArabic: VehicleController.buildPlate(
        digits: plate.digits,
        letters: plate.arabicLetters,
      ),
      plateNumberLatin: VehicleController.buildPlate(
        digits: plate.digits,
        letters: plate.englishLetters,
      ),
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
            style: TextButton.styleFrom(foregroundColor: AppStatusColors.error),
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
    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor:CustomerColors.darkPanel,
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'تعديل المركبة' : 'إضافة مركبة',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.isLoadingLookups) {
              return const Center(
                child: CircularProgressIndicator(color: CustomerColors.accent),
              );
            }
            return Form(key: _formKey, child: _fields());
          },
        ),
      ),
    );
  }

  Widget _fields() {
    final saving = _controller.isSaving;
    final brandIsOther = _brand == kOtherOption;
    final modelIsOther = _model == kOtherOption;
    final colorIsOther = _color == kOtherOption;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _FieldLabel('الشركة المصنعة'),
        _dropdown(
          value: _brand,
          options: _controller.brandOptions(_brand),
          hint: 'اختر الشركة',
          enabled: !saving,
          validator: VehicleController.validateBrand,
          onChanged: (value) => setState(() {
            _brand = value;
            if (value != kOtherOption) _brandOther.clear();
            // The models belong to the old brand, so start that field again.
            _model = null;
            _modelOther.clear();
          }),
        ),
        if (brandIsOther) ...[
          const SizedBox(height: 10),
          _otherField(
            controller: _brandOther,
            hint: 'اكتب اسم الشركة المصنعة',
            enabled: !saving,
          ),
        ],
        const SizedBox(height: 16),

        const _FieldLabel('الطراز'),
        _dropdown(
          // A new FormField per brand, so the old model is not left showing.
          key: ValueKey('model-$_brand'),
          value: _model,
          options: _modelOptions,
          hint: _brand == null ? 'اختر الشركة المصنعة أولاً' : 'اختر الطراز',
          enabled: !saving && _brand != null,
          validator: VehicleController.validateModelSelection,
          onChanged: (value) => setState(() {
            _model = value;
            if (value != kOtherOption) _modelOther.clear();
          }),
        ),
        if (modelIsOther) ...[
          const SizedBox(height: 10),
          _otherField(
            controller: _modelOther,
            hint: 'اكتب طراز المركبة',
            enabled: !saving,
          ),
        ],
        const SizedBox(height: 16),

        const _FieldLabel('سنة الصنع'),
        DropdownButtonFormField<int>(
          initialValue: _year,
          items: [
            for (final y in _years) DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: saving ? null : (value) => setState(() => _year = value),
          validator: VehicleController.validateYear,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          hint: const Text('اختر السنة'),
          menuMaxHeight: 320,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          style: _inputStyle(context),
          decoration: _decoration(),
        ),
        const SizedBox(height: 16),

        const _FieldLabel('لون المركبة'),
        _dropdown(
          value: _color,
          options: _controller.colorOptions(_color),
          hint: 'اختر اللون',
          enabled: !saving,
          validator: VehicleController.validateColor,
          onChanged: (value) => setState(() {
            _color = value;
            if (value != kOtherOption) _colorOther.clear();
          }),
        ),
        if (colorIsOther) ...[
          const SizedBox(height: 10),
          _otherField(
            controller: _colorOther,
            hint: 'اكتب لون المركبة',
            enabled: !saving,
          ),
        ],
        const SizedBox(height: 16),

        const _FieldLabel('لوحة المركبة'),
        // The same widget the provider app uses, so both apps read and write
        // plates identically.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _plateError == null ? CustomerColors.cardBorder : AppStatusColors.error,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PlateNumberField(
            key: _plateKey,
            navy: CustomerColors.darkPanel,
            initialDigits: _initialPlate.$1,
            initialArabicLetters: _initialPlate.$2,
            // Clears the error as soon as the customer fixes it.
            onChanged: (_) {
              if (_plateError != null) setState(() => _plateError = null);
            },
          ),
        ),
        if (_plateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 14, left: 14),
            child: Text(
              _plateError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
            ),
          ),
        const SizedBox(height: 28),

        FilledButton(
          onPressed: saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: CustomerColors.accent,
            disabledBackgroundColor: CustomerColors.accent.withOpacity(0.3),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
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
              foregroundColor: AppStatusColors.error,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dropdown({
    Key? key,
    required String? value,
    required List<String> options,
    required String hint,
    required bool enabled,
    required FormFieldValidator<String> validator,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: enabled ? onChanged : null,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      hint: Text(hint),
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(12),
      dropdownColor: Colors.white,
      style: _inputStyle(context),
      decoration: _decoration(),
    );
  }

  /// The text field shown after "أخرى" is picked.
  Widget _otherField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: VehicleController.validateCustomValue,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      textInputAction: TextInputAction.next,
      style: _inputStyle(context),
      decoration: _decoration(hint: hint),
    );
  }

  TextStyle _inputStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontSize: 15,
            color: CustomerColors.primaryText,
          );

  InputDecoration _decoration({String? hint}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA1B0)),
      errorMaxLines: 2,
      filled: true,
      fillColor: CustomerColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(CustomerColors.cardBorder),
      disabledBorder: border(CustomerColors.cardBorder),
      focusedBorder: border(CustomerColors.accent, 1.5),
      errorBorder: border(AppStatusColors.error),
      focusedErrorBorder: border(AppStatusColors.error, 1.5),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CustomerColors.secondaryText,
        ),
      ),
    );
  }
}
