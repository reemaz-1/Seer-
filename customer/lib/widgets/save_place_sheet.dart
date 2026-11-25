import 'package:flutter/material.dart';

import '../models/saved_location.dart';
import '../theme/app_colors.dart';

/// What the customer chose in the "save this place" sheet.
class SavePlaceChoice {
  const SavePlaceChoice(this.kind, this.name);

  /// 'home', 'work' or 'other'.
  final String kind;

  /// The customer's own name. Only for kind 'other'.
  final String? name;
}

/// Asks the customer what to call a place: home, work, or a name they type.
///
/// [savedPlaces] lets the sheet warn that home or work will be replaced.
/// [current] is the place already saved at this spot, if any, so its name is
/// shown and saving again renames it instead of making a second copy.
/// Returns null when the sheet is closed without saving.
Future<SavePlaceChoice?> showSavePlaceSheet(
  BuildContext context, {
  required List<SavedLocation> savedPlaces,
  SavedLocation? current,
}) {
  return showModalBottomSheet<SavePlaceChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _SavePlaceSheet(savedPlaces: savedPlaces, current: current),
  );
}

class _SavePlaceSheet extends StatefulWidget {
  const _SavePlaceSheet({required this.savedPlaces, required this.current});

  final List<SavedLocation> savedPlaces;
  final SavedLocation? current;

  @override
  State<_SavePlaceSheet> createState() => _SavePlaceSheetState();
}

class _SavePlaceSheetState extends State<_SavePlaceSheet> {
  final _name = TextEditingController();
  String? _kind;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    if (current != null) {
      _kind = current.kind;
      if (current.kind == SavedLocation.other) _name.text = current.name ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid =>
      _kind != null &&
      (_kind != SavedLocation.other || _name.text.trim().isNotEmpty);

  /// Home or work is already saved somewhere else: saving here replaces it.
  bool get _replaces {
    final kind = _kind;
    if (kind == null || kind == SavedLocation.other) return false;
    return widget.savedPlaces.any(
      (p) => p.kind == kind && p.id != widget.current?.id,
    );
  }

  void _save() {
    if (!_valid) return;
    Navigator.pop(
      context,
      SavePlaceChoice(
        _kind!,
        _kind == SavedLocation.other ? _name.text.trim() : null,
      ),
    );
  }

  Widget _chip(String kind, String label, IconData icon) {
    final selected = _kind == kind;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: CustomerColors.accent),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFFEAF1FC),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? CustomerColors.accent : CustomerColors.cardBorder,
      ),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: CustomerColors.primaryText,
      ),
      onSelected: (_) => setState(() => _kind = kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'احفظ هذا المكان باسم',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: CustomerColors.primaryText,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(SavedLocation.home, 'المنزل', Icons.home_outlined),
              _chip(SavedLocation.work, 'العمل', Icons.work_outline),
              _chip(SavedLocation.other, 'اسم آخر', Icons.edit_outlined),
            ],
          ),
          if (_kind == SavedLocation.other) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: SavedLocation.maxNameLength,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'مثال: بيت أهلي',
                filled: true,
                fillColor: CustomerColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CustomerColors.cardBorder),
                ),
              ),
            ),
          ],
          if (_replaces)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'سيحل هذا المكان محل ${SavedLocation.labelOf(_kind!)} '
                'المحفوظ حاليًا.',
                style: const TextStyle(
                  fontSize: 12,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _valid ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: CustomerColors.accent,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'حفظ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
