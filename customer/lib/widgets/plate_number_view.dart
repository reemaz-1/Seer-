import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'plate_number_field.dart';

/// Read-only Saudi plate, drawn like the plate input in registration:
/// Eastern digits and Arabic letters on top, Western digits and Latin
/// letters below, and the KSA column on the side.
class PlateNumberView extends StatelessWidget {
  /// Creates the plate.
  ///
  /// Parameters: [digits] in Western form, the [arabicLetters] and the
  /// matching [englishLetters].
  const PlateNumberView({
    super.key,
    required this.digits,
    required this.arabicLetters,
    required this.englishLetters,
  });

  /// Builds a plate from the strings saved in Firestore.
  ///
  /// Both strings are saved as `"<digits> <letters>"`, so they are split at
  /// the first space. Missing Latin letters are derived from the Arabic
  /// ones with the shared plate letter table.
  ///
  /// Parameters: [arabic] is the saved Arabic plate and [latin] the saved
  /// Latin plate (may be empty).
  /// Returns: a [PlateNumberView] ready to display.
  factory PlateNumberView.fromStored({
    Key? key,
    required String arabic,
    String latin = '',
  }) {
    final arabicParts = _split(arabic);
    final latinParts = _split(latin);

    final digits = _toWesternDigits(
      latinParts.$1.isNotEmpty ? latinParts.$1 : arabicParts.$1,
    );
    final arabicLetters = arabicParts.$2.replaceAll(' ', '');
    final englishLetters = latinParts.$2.isNotEmpty
        ? latinParts.$2.replaceAll(' ', '').toUpperCase()
        : arabicLetters.characters
            .map((ch) => kPlateArabicToEnglish[ch] ?? '')
            .join();

    return PlateNumberView(
      key: key,
      digits: digits,
      arabicLetters: arabicLetters,
      englishLetters: englishLetters,
    );
  }

  final String digits;
  final String arabicLetters;
  final String englishLetters;

  static const _ksa = ['K', 'S', 'A'];
  static const _dividerWidth = 1.2;
  static const _ksaWidth = 20.0;
  static const _cellPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 3);

  /// Splits a saved plate into its digits and letters.
  ///
  /// Parameters: [value] is the saved plate text.
  /// Returns: a record of (digits, letters); empty strings when missing.
  static (String, String) _split(String value) {
    final trimmed = value.trim();
    final space = trimmed.indexOf(' ');
    if (space < 0) return (trimmed, '');
    return (trimmed.substring(0, space), trimmed.substring(space + 1).trim());
  }

  /// Converts Eastern Arabic digits to Western digits.
  ///
  /// Parameters: [value] may mix both digit forms.
  /// Returns: the same digits in Western form.
  static String _toWesternDigits(String value) => value.characters
      .map((ch) => kEasternToWesternDigits[ch] ?? ch)
      .join();

  /// Converts Western digits to Eastern Arabic digits.
  ///
  /// Parameters: [value] is the digits in Western form.
  /// Returns: the same digits in Eastern Arabic form.
  static String _toEasternDigits(String value) => value.characters
      .map((ch) => kWesternToEasternDigits[ch] ?? ch)
      .join();

  /// Takes the characters of a plate part and a [count]; returns exactly
  /// [count] characters, padded with empty cells, so both rows line up.
  static List<String> _padded(List<String> chars, int count) =>
      [for (var i = 0; i < count; i++) i < chars.length ? chars[i] : ''];

  /// Builds one cell of the plate.
  ///
  /// Parameters: [text] to show and its font [size].
  /// Returns: a centered, padded text.
  Widget _cell(String text, double size) {
    return Padding(
      padding: _cellPadding,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: CustomerColors.primaryText,
          ),
        ),
      ),
    );
  }

  /// Builds a thin dividing line.
  ///
  /// Parameters: [vertical] picks the line direction.
  /// Returns: a sized colored box.
  Widget _divider({required bool vertical}) {
    return Container(
      width: vertical ? _dividerWidth : null,
      height: vertical ? null : _dividerWidth,
      color: CustomerColors.primaryText,
    );
  }

  /// Takes no inputs; returns the line between the digits and the letters,
  /// stretched to the full height of its row.
  Widget _columnDivider() => TableCell(
    verticalAlignment: TableCellVerticalAlignment.fill,
    child: _divider(vertical: true),
  );

  /// Builds the plate.
  ///
  /// Every character has its own column in a [Table], so the Arabic and
  /// Latin rows always line up and never read in opposite directions.
  ///
  /// Parameters: [context] is the build context.
  /// Returns: a bordered white plate laid out left to right.
  @override
  Widget build(BuildContext context) {
    const line = BorderSide(
      color: CustomerColors.primaryText,
      width: _dividerWidth,
    );
    final digitChars = digits.characters.toList();
    final arabicChars = arabicLetters.characters.toList();
    final englishChars = englishLetters.characters.toList();
    final digitCount = digitChars.length;
    final letterCount = arabicChars.length > englishChars.length
        ? arabicChars.length
        : englishChars.length;
    // Letters are entered from right to left, so the first letter is drawn
    // on the right.
    final arabicRow = _padded(arabicChars, letterCount).reversed.toList();
    final englishRow = _padded(englishChars, letterCount).reversed.toList();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: CustomerColors.background,
          border: Border.all(
            color: CustomerColors.primaryText,
            width: _dividerWidth,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One column per character, laid out like the plate input:
              // digits from left to right and letters from right to left, so
              // every Eastern digit sits above its Western digit and every
              // Arabic letter above its Latin letter.
              Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: {
                  digitCount: const FixedColumnWidth(_dividerWidth),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: const TableBorder(horizontalInside: line),
                children: [
                  TableRow(
                    children: [
                      for (final digit in digitChars)
                        _cell(_toEasternDigits(digit), 15),
                      _columnDivider(),
                      for (final letter in arabicRow)
                        _cell(letter, 15),
                    ],
                  ),
                  TableRow(
                    children: [
                      for (final digit in digitChars) _cell(digit, 12),
                      _columnDivider(),
                      for (final letter in englishRow)
                        _cell(letter, 12),
                    ],
                  ),
                ],
              ),
              _divider(vertical: true),
              SizedBox(
                width: _ksaWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final letter in _ksa)
                      Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: CustomerColors.primaryText,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
