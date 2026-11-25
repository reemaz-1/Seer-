import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/address_controller.dart';
import '../../controllers/saved_locations_controller.dart';
import '../../models/saved_location.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/save_place_sheet.dart';
import 'location_picker_page.dart';

/// VIEW: the customer's saved places: home, work and places with a name of
/// their own. They show up as one-tap shortcuts when requesting a service.
/// Here they are added, moved, renamed and deleted.
class SavedLocationsPage extends StatefulWidget {
  const SavedLocationsPage({super.key, required this.uid});

  final String uid;

  @override
  State<SavedLocationsPage> createState() => _SavedLocationsPageState();
}

class _SavedLocationsPageState extends State<SavedLocationsPage> {
  late final _places = SavedLocationsController(uid: widget.uid);
  final _addresses = AddressController();

  @override
  void initState() {
    super.initState();
    _places.load();
  }

  @override
  void dispose() {
    _places.dispose();
    super.dispose();
  }

  void _show(String text, {AppMessageType type = AppMessageType.success}) {
    showAppMessage(context, text, type: type);
  }

  Future<LatLng?> _pickOnMap(String title, SavedLocation? from) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: title,
          initialSelectedLocation: from == null
              ? null
              : LatLng(from.location.latitude, from.location.longitude),
        ),
      ),
    );
  }

  Future<void> _report(Future<String?> result, String success) async {
    // The list already changed; confirm now, speak again only on failure.
    _show(success);
    final error = await result;
    if (error != null && mounted) _show(error, type: AppMessageType.warning);
  }

  /// Adds a new place: pick on the map, then name it.
  Future<void> _add({String? kind}) async {
    final picked = await _pickOnMap(
      kind == null ? 'إضافة مكان' : 'تحديد ${SavedLocation.labelOf(kind)}',
      null,
    );
    if (!mounted || picked == null) return;
    final point = GeoPoint(picked.latitude, picked.longitude);
    final existing = _places.placeAt(point);

    var choiceKind = kind;
    String? name;
    if (kind == null || kind == SavedLocation.other) {
      final choice = await showSavePlaceSheet(
        context,
        savedPlaces: _places.places,
        current: existing,
      );
      if (!mounted || choice == null) return;
      choiceKind = choice.kind;
      name = choice.name;
    }
    await _report(
      _places.save(
        kind: choiceKind!,
        name: name,
        point: point,
        replaceId: existing?.kind == choiceKind ? existing?.id : null,
      ),
      'تم حفظ المكان',
    );
  }

  /// Moves [place] to a new spot, keeping its name.
  Future<void> _move(SavedLocation place) async {
    final picked = await _pickOnMap('تغيير موقع ${place.label}', place);
    if (!mounted || picked == null) return;
    await _report(
      _places.save(
        kind: place.kind,
        name: place.name,
        point: GeoPoint(picked.latitude, picked.longitude),
        replaceId: place.id,
      ),
      'تم تحديث ${place.label}',
    );
  }

  /// Renames [place]: home, work, or another name.
  Future<void> _rename(SavedLocation place) async {
    final choice = await showSavePlaceSheet(
      context,
      savedPlaces: _places.places,
      current: place,
    );
    if (!mounted || choice == null) return;
    // Another kind (say "other" to "home") replaces the old entry, since it
    // is the same spot.
    await _report(
      _places.save(
        kind: choice.kind,
        name: choice.name,
        point: place.location,
        replaceId: place.id,
      ),
      'تم تغيير الاسم',
    );
  }

  Future<void> _delete(SavedLocation place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف ${place.label}'),
        content: Text('هل تريد حذف ${place.label} من أماكنك المحفوظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppStatusColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _report(_places.remove(place.id), 'تم حذف ${place.label}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor: CustomerColors.darkPanel,
        foregroundColor: Colors.white,
        title: const Text(
          'أماكني المحفوظة',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _places,
          builder: (context, _) {
            if (_places.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: CustomerColors.accent),
              );
            }
            if (_places.loadError != null) return _errorView();

            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_places.places.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'لا توجد أماكن محفوظة بعد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CustomerColors.secondaryText),
                    ),
                  ),
                for (final place in _places.places) ...[
                  _PlaceCard(
                    title: place.label,
                    icon: place.kind == SavedLocation.home
                        ? Icons.home_outlined
                        : place.kind == SavedLocation.work
                            ? Icons.work_outline
                            : Icons.place_outlined,
                    place: place,
                    addresses: _addresses,
                    onAdd: () {},
                    onMove: _move,
                    onRename: _rename,
                    onDelete: _delete,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_places.places.length < SavedLocation.maxPlaces)
                  OutlinedButton.icon(
                    onPressed: _add,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('إضافة مكان جديد'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_places.loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _places.load,
              style: FilledButton.styleFrom(
                backgroundColor: CustomerColors.accent,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.title,
    required this.icon,
    required this.place,
    required this.addresses,
    required this.onAdd,
    required this.onMove,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final IconData icon;
  final SavedLocation? place;
  final AddressController addresses;
  final VoidCallback onAdd;
  final void Function(SavedLocation place) onMove;
  final void Function(SavedLocation place) onRename;
  final void Function(SavedLocation place) onDelete;

  @override
  Widget build(BuildContext context) {
    final saved = place;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CustomerColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: CustomerColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: CustomerColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (saved == null)
                      const Text(
                        'لم تحدد هذا المكان بعد',
                        style: TextStyle(
                          fontSize: 13,
                          color: CustomerColors.secondaryText,
                        ),
                      )
                    else
                      FutureBuilder<String?>(
                        future: addresses.addressOf(saved.location),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? 'تم تحديد الموقع على الخريطة',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (saved == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: CustomerColors.darkPanel,
                foregroundColor: Colors.white,
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.map_outlined, size: 19),
              label: const Text('إضافة من الخريطة'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onMove(saved),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 19),
                  label: const Text('تغيير الموقع'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onRename(saved),
                  icon: const Icon(Icons.drive_file_rename_outline, size: 19),
                  label: const Text('تغيير الاسم'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onDelete(saved),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStatusColors.error,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 19),
                  label: const Text('حذف'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
