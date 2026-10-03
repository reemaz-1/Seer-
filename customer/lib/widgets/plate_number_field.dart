import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// Saudi plate letters: only these 17 Arabic letters are valid
// on a plate, each with a fixed Latin equivalent.
// 'ا' (plain alef) is treated as an accepted variant of 'أ'.
// ============================================================

const Map<String, String> kPlateArabicToEnglish = {
  'أ': 'A',
  'ا': 'A', // common variant typed on a normal keyboard
  'ب': 'B',
  'ح': 'J',
  'د': 'D',
  'ر': 'R',
  'س': 'S',
  'ص': 'X',
  'ط': 'T',
  'ع': 'E',
  'ق': 'G',
  'ك': 'K',
  'ل': 'L',
  'م': 'Z',
  'ن': 'N',
  'ه': 'H',
  'و': 'U',
  'ى': 'V',
};

// Reverse lookup (uppercase Latin -> canonical Arabic letter), in
// case someone types on an English keyboard.
final Map<String, String> kPlateEnglishToArabic = {
  'A': 'أ',
  'B': 'ب',
  'J': 'ح',
  'D': 'د',
  'R': 'ر',
  'S': 'س',
  'X': 'ص',
  'T': 'ط',
  'E': 'ع',
  'G': 'ق',
  'K': 'ك',
  'L': 'ل',
  'Z': 'م',
  'N': 'ن',
  'H': 'ه',
  'U': 'و',
  'V': 'ى',
};

// ============================================================
// Western <-> Eastern-Arabic digit mirroring. Typing in either
// the top (Eastern) or bottom (Western) digit row updates the
// other automatically, digit-by-digit, same order.
// ============================================================

const Map<String, String> kWesternToEasternDigits = {
  '0': '٠',
  '1': '١',
  '2': '٢',
  '3': '٣',
  '4': '٤',
  '5': '٥',
  '6': '٦',
  '7': '٧',
  '8': '٨',
  '9': '٩',
};

final Map<String, String> kEasternToWesternDigits = {
  for (final entry in kWesternToEasternDigits.entries) entry.value: entry.key,
};

// ============================================================
// Letters: same bidirectional idea as the digits. The top row
// holds the Arabic letter, the bottom row holds its English
// equivalent — and typing into EITHER row is accepted and
// mirrors into the other, so someone who only reads English can
// type the English letters directly and see the Arabic appear
// automatically above (and vice versa).
// ============================================================

// Filters a raw input string down to only valid plate letters,
// normalized to ARABIC, in order. Accepts either script.
String _filterToArabicLetters(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.characters) {
    final String upper = ch.toUpperCase();
    if (kPlateArabicToEnglish.containsKey(ch)) {
      buffer.write(ch);
    } else if (kPlateEnglishToArabic.containsKey(upper)) {
      buffer.write(kPlateEnglishToArabic[upper]);
    }
  }
  return buffer.toString();
}

// Same, but normalized to ENGLISH (uppercase). Accepts either
// script.
String _filterToEnglishLetters(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.characters) {
    final String upper = ch.toUpperCase();
    if (kPlateEnglishToArabic.containsKey(upper)) {
      buffer.write(upper);
    } else if (kPlateArabicToEnglish.containsKey(ch)) {
      buffer.write(kPlateArabicToEnglish[ch]);
    }
  }
  return buffer.toString();
}

class _ArabicLettersFormatter extends TextInputFormatter {
  final VoidCallback? onInvalidChar;
  _ArabicLettersFormatter({this.onInvalidChar});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length) return newValue;
    final result = _filterToArabicLetters(newValue.text);
    if (result.length < newValue.text.length) {
      onInvalidChar?.call();
    }
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class _EnglishLettersFormatter extends TextInputFormatter {
  final VoidCallback? onInvalidChar;
  _EnglishLettersFormatter({this.onInvalidChar});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length) return newValue;
    final result = _filterToEnglishLetters(newValue.text);
    if (result.length < newValue.text.length) {
      onInvalidChar?.call();
    }
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// Filters a raw input string down to only valid digit characters
// (Western or Eastern-Arabic), normalized to Western, in order.
String _filterToWesternDigits(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.characters) {
    if (RegExp(r'[0-9]').hasMatch(ch)) {
      buffer.write(ch);
    } else if (kEasternToWesternDigits.containsKey(ch)) {
      buffer.write(kEasternToWesternDigits[ch]);
    }
  }
  return buffer.toString();
}

// Same, but normalized to Eastern-Arabic digits.
String _filterToEasternDigits(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.characters) {
    if (kWesternToEasternDigits.containsKey(ch)) {
      buffer.write(kWesternToEasternDigits[ch]);
    } else if (kEasternToWesternDigits.containsKey(ch)) {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

class _WesternDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length) return newValue;
    final result = _filterToWesternDigits(newValue.text);
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class _EasternDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length) return newValue;
    final result = _filterToEasternDigits(newValue.text);
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ============================================================
// Public value object returned to the parent form.
// ============================================================

class PlateNumberValue {
  final String digits; // e.g. "1234" (1–4 digits)
  final String arabicLetters; // e.g. "ععه" (exactly 3 letters)
  final String englishLetters; // e.g. "EEH" (same column order)
  final bool isValid; // at least 1 digit AND exactly 3 letters

  const PlateNumberValue({
    required this.digits,
    required this.arabicLetters,
    required this.englishLetters,
    required this.isValid,
  });
}

// ============================================================
// Shared visual constants
// ============================================================

const double _kDividerWidth = 1.5;
const Color _kDividerColor = Colors.black;
const double _kTopFontSize = 20;
const double _kBottomFontSize = 18;

// ============================================================
// The plate number field widget.
// ============================================================

class PlateNumberField extends StatefulWidget {
  final Color navy;
  final ValueChanged<PlateNumberValue>? onChanged;
  final String initialDigits;
  final String initialArabicLetters;

  const PlateNumberField({
    super.key,
    required this.navy,
    this.onChanged,
    this.initialDigits = '',
    this.initialArabicLetters = '',
  });

  @override
  State<PlateNumberField> createState() => PlateNumberFieldState();
}

class PlateNumberFieldState extends State<PlateNumberField> {
  final List<TextEditingController> _digitsEasternControllers =
      List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _digitsWesternControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _digitsEasternFocusNodes =
      List.generate(4, (_) => FocusNode());
  final List<FocusNode> _digitsWesternFocusNodes =
      List.generate(4, (_) => FocusNode());
  bool _syncingDigits = false;

  final List<TextEditingController> _lettersArabicControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _lettersEnglishControllers =
      List.generate(3, (_) => TextEditingController());
  final List<FocusNode> _lettersArabicFocusNodes =
      List.generate(3, (_) => FocusNode());
  final List<FocusNode> _lettersEnglishFocusNodes =
      List.generate(3, (_) => FocusNode());
  bool _syncingLetters = false;
  String? _invalidCharError;

  void _showInvalidCharError() {
    setState(() {
      _invalidCharError = 'الحرف المدخل غير مسموح به في اللوحات السعودية';
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _invalidCharError = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      _digitsEasternControllers[i]
          .addListener(() => _onEasternDigitChanged(i));
      _digitsWesternControllers[i]
          .addListener(() => _onWesternDigitChanged(i));
    }
    for (int i = 0; i < 3; i++) {
      _lettersArabicControllers[i]
          .addListener(() => _onArabicLetterChanged(i));
      _lettersEnglishControllers[i]
          .addListener(() => _onEnglishLetterChanged(i));
    }

    final digitChars = widget.initialDigits.characters.toList();
    for (int i = 0; i < digitChars.length && i < 4; i++) {
      _digitsWesternControllers[i].text = digitChars[i];
    }

    final letterChars = widget.initialArabicLetters.characters.toList();
    for (int i = 0; i < letterChars.length && i < 3; i++) {
      _lettersArabicControllers[i].text = letterChars[i];
    }
  }

  void _onEasternDigitChanged(int i) {
    if (_syncingDigits) return;
    _syncingDigits = true;

    final eastern = _digitsEasternControllers[i].text;
    final western = kEasternToWesternDigits[eastern] ?? eastern;

    if (_digitsWesternControllers[i].text != western) {
      _digitsWesternControllers[i].text = western;
    }

    _syncingDigits = false;
    _handleChanged();
  }

  void _onWesternDigitChanged(int i) {
    if (_syncingDigits) return;
    _syncingDigits = true;

    final western = _digitsWesternControllers[i].text;
    final eastern = kWesternToEasternDigits[western] ?? western;

    if (_digitsEasternControllers[i].text != eastern) {
      _digitsEasternControllers[i].text = eastern;
    }

    _syncingDigits = false;
    _handleChanged();
  }

  void _onArabicLetterChanged(int i) {
    if (_syncingLetters) return;
    _syncingLetters = true;

    final arabic = _lettersArabicControllers[i].text;
    final english = arabic.isEmpty ? '' : (kPlateArabicToEnglish[arabic] ?? '');

    if (_lettersEnglishControllers[i].text != english) {
      _lettersEnglishControllers[i].text = english;
    }

    _syncingLetters = false;
    _handleChanged();
  }

  void _onEnglishLetterChanged(int i) {
    if (_syncingLetters) return;
    _syncingLetters = true;

    final english = _lettersEnglishControllers[i].text;
    final arabic = english.isEmpty ? '' : (kPlateEnglishToArabic[english] ?? '');

    if (_lettersArabicControllers[i].text != arabic) {
      _lettersArabicControllers[i].text = arabic;
    }

    _syncingLetters = false;
    _handleChanged();
  }

  @override
  void dispose() {
    for (final c in _digitsEasternControllers) {
      c.dispose();
    }
    for (final c in _digitsWesternControllers) {
      c.dispose();
    }
    for (final f in _digitsEasternFocusNodes) {
      f.dispose();
    }
    for (final f in _digitsWesternFocusNodes) {
      f.dispose();
    }
    for (final c in _lettersArabicControllers) {
      c.dispose();
    }
    for (final c in _lettersEnglishControllers) {
      c.dispose();
    }
    for (final f in _lettersArabicFocusNodes) {
      f.dispose();
    }
    for (final f in _lettersEnglishFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _arabicLetters =>
      _lettersArabicControllers.map((c) => c.text).join();

  String get _englishLetters =>
      _lettersEnglishControllers.map((c) => c.text).join();

  String get _digitsValue =>
      _digitsWesternControllers.map((c) => c.text).join();

  PlateNumberValue get value => PlateNumberValue(
        digits: _digitsValue,
        arabicLetters: _arabicLetters,
        englishLetters: _englishLetters,
        isValid: _digitsValue.isNotEmpty && _arabicLetters.length == 3,
      );

  void _handleChanged() {
    widget.onChanged?.call(value);
    setState(() {});
  }

  Widget _digitsTop() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < 4; i++)
          _charBox(
            controller: _digitsEasternControllers[i],
            focusNode: _digitsEasternFocusNodes[i],
            allFocusNodes: _digitsEasternFocusNodes,
            allControllers: _digitsEasternControllers,
            index: i,
            formatter: _EasternDigitsFormatter(),
            hint: '.',
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

  Widget _digitsBottom() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < 4; i++)
          _charBox(
            controller: _digitsWesternControllers[i],
            focusNode: _digitsWesternFocusNodes[i],
            allFocusNodes: _digitsWesternFocusNodes,
            allControllers: _digitsWesternControllers,
            index: i,
            formatter: _WesternDigitsFormatter(),
            hint: '0',
            fontSize: _kBottomFontSize,
            fontWeight: FontWeight.w600,
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

  Widget _charBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<FocusNode> allFocusNodes,
    required List<TextEditingController> allControllers,
    required int index,
    required TextInputFormatter formatter,
    required String hint,
    double fontSize = _kTopFontSize,
    FontWeight fontWeight = FontWeight.bold,
    TextInputType? keyboardType,
    double width = 26,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            controller.text.isEmpty &&
            index > 0) {
          allControllers[index - 1].clear();
          allFocusNodes[index - 1].requestFocus();
        }
      },
      child: SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: Colors.black,
          ),
          inputFormatters: [formatter],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
          onChanged: (v) => _handleGridInput(
            controllers: allControllers,
            focusNodes: allFocusNodes,
            index: index,
            value: v,
          ),
        ),
      ),
    );
  }

  void _handleGridInput({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required int index,
    required String value,
  }) {
    final int lastIndex = controllers.length - 1;

    if (value.length <= 1) {
      if (value.isNotEmpty && index < lastIndex) {
        focusNodes[index + 1].requestFocus();
      }
      return;
    }

    final chars = value.characters.toList();
    int cursor = index;
    for (final ch in chars) {
      if (cursor > lastIndex) break;
      controllers[cursor].text = ch;
      cursor++;
    }

    if (cursor <= lastIndex) {
      focusNodes[cursor].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Widget _lettersTop() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          for (int i = 0; i < 3; i++)
            Expanded(
              child: Center(
                child: _charBox(
                  controller: _lettersArabicControllers[i],
                  focusNode: _lettersArabicFocusNodes[i],
                  allFocusNodes: _lettersArabicFocusNodes,
                  allControllers: _lettersArabicControllers,
                  index: i,
                  formatter: _ArabicLettersFormatter(
                    onInvalidChar: _showInvalidCharError,
                  ),
                  hint: 'ا',
                  width: 34,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lettersBottom() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          for (int i = 0; i < 3; i++)
            Expanded(
              child: Center(
                child: _charBox(
                  controller: _lettersEnglishControllers[i],
                  focusNode: _lettersEnglishFocusNodes[i],
                  allFocusNodes: _lettersEnglishFocusNodes,
                  allControllers: _lettersEnglishControllers,
                  index: i,
                  formatter: _EnglishLettersFormatter(
                    onInvalidChar: _showInvalidCharError,
                  ),
                  hint: 'A',
                  fontSize: _kBottomFontSize,
                  fontWeight: FontWeight.w600,
                  width: 34,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: _kDividerWidth,
        color: _kDividerColor,
      );

  Widget _horizontalDivider() => Container(
        height: _kDividerWidth,
        color: _kDividerColor,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _invalidCharError != null
                    ? Colors.red.shade700
                    : _kDividerColor,
                width: _kDividerWidth,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 4, child: _digitsTop()),
                              _verticalDivider(),
                              Expanded(flex: 3, child: _lettersTop()),
                            ],
                          ),
                        ),
                        _horizontalDivider(),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 4, child: _digitsBottom()),
                              _verticalDivider(),
                              Expanded(flex: 3, child: _lettersBottom()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _verticalDivider(),
                  const SizedBox(
                    width: 44,
                    child: _KsaColumn(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_invalidCharError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8, left: 8),
            child: Text(
              _invalidCharError!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

// ============================================================
// Margin column: K / S / A centered vertically
// ============================================================

class _KsaColumn extends StatelessWidget {
  const _KsaColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('K', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('S', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}