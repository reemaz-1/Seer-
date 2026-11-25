import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../controllers/order_draft_controller.dart';
import '../../controllers/location_controller.dart';
import '../../theme/app_colors.dart';
import '../../models/order.dart';
import '../../services/ai_assistant.dart';
import '../../models/pricing_model.dart';
import '../../models/service_catalog.dart';
import '../../controllers/saved_locations_controller.dart';
import '../../models/saved_location.dart';
import '../../widgets/vehicle_picker_sheet.dart';
import 'order_review_page.dart';
import 'vehicle_form_page.dart';
import 'location_picker_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/app_snackbar.dart';

/// VIEW: build a service request.
/// Choose the service option (#13), the vehicle (#14) and an optional note
/// (#23), then continue to the review page (#17).
///
/// Pops with a success message once the order has been sent.
class RequestServicePage extends StatefulWidget {
  const RequestServicePage({
    super.key,
    required this.uid,
    required this.categoryId,
    this.preferredVehicleId,
    this.useFreeWash = false,
    this.reorderFrom,
    this.suggestion,
  });

  final String uid;

  /// Which service was tapped on the home page.
  final String categoryId;

  /// The vehicle shown on the home page, pre-selected here.
  final String? preferredVehicleId;

  /// True when opened from the loyalty card to use a free car cleaning (#67).
  final bool useFreeWash;

  /// The rejected or auto-cancelled order this request is copied from, or
  /// null for a brand-new request (#21).
  final ServiceOrder? reorderFrom;

  /// The service the AI assistant suggested in the chat, or null when the
  /// customer came from the home page.
  final OrderSummary? suggestion;

  /// Opens the request form filled with the service the AI assistant
  /// suggested. The customer can change anything before sending.
  ///
  /// Parameters: [context] to navigate from, the customer's [uid] and the
  /// assistant's [summary].
  /// Returns: a future that completes when the page is closed, with the
  /// success message if the order was sent.
  static Future<String?> fromSuggestion(
    BuildContext context, {
    required String uid,
    required OrderSummary summary,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RequestServicePage(
          uid: uid,
          categoryId: summary.categoryId,
          preferredVehicleId: summary.vehicle.id,
          suggestion: summary,
        ),
      ),
    );
  }

  /// Opens the request form filled with the data of an earlier order (#21).
  ///
  /// The customer can change anything, including the location, then
  /// continues to the review page and confirms.
  ///
  /// Parameters: [context] to navigate from, the customer's [uid] and the
  /// [order] to copy.
  /// Returns: a future that completes when the page is closed, with the
  /// success message if the order was sent.
  static Future<String?> reorder(
    BuildContext context, {
    required String uid,
    required ServiceOrder order,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RequestServicePage(
          uid: uid,
          categoryId: order.serviceCategoryId,
          preferredVehicleId: order.vehicleId,
          reorderFrom: order,
        ),
      ),
    );
  }

  @override
  State<RequestServicePage> createState() => _RequestServicePageState();
}

class _RequestServicePageState extends State<RequestServicePage> {
  late final _places = SavedLocationsController(uid: widget.uid);
  late final _controller = OrderDraftController(
    uid: widget.uid,
    categoryId: widget.categoryId,
    preferredVehicleId: widget.preferredVehicleId,
    useFreeWash: widget.useFreeWash,
  );

  // Handles GPS/map location separately from the order-building controller.
  // This keeps the location logic reusable regardless of the map provider.
  final _locationController = LocationController();

  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final source = widget.reorderFrom;
    if (source != null) {
      // Reorder (#21): start from the earlier order's data.
      _controller.prefillFromOrder(source);
      _note.text = source.note;
    }
    final suggestion = widget.suggestion;
    if (suggestion != null) {
      // Suggested by the AI chat: start from what the assistant chose.
      _controller.prefillFromSuggestion(
        optionId: suggestion.optionId,
        note: suggestion.note,
        pickup: suggestion.pickupLocation,
        dropoff: suggestion.dropoffLocation,
        vehicleSizeId: suggestion.vehicleSizeId,
      );
      _note.text = suggestion.note;
    }
    _controller.loadVehicles();
    _controller.loadPrices();
    _places.addListener(_onPlacesChanged);
    _places.load();
  }

  @override
  void dispose() {
    _note.dispose();
    _locationController.dispose();
    _places.removeListener(_onPlacesChanged);
    _places.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------- Actions ----------------

  void _onPlacesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _changeVehicle() async {
    final picked = await showVehiclePicker(
      context: context,
      vehicles: _controller.vehicles,
      selected: _controller.selectedVehicle,
    );
    if (picked != null) _controller.selectVehicle(picked);
  }

  Future<void> _addVehicle() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => VehicleFormPage(uid: widget.uid)),
    );
    if (!mounted) return;
    if (message != null) _showMessage(message);
    _controller.loadVehicles();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    _controller.setNote(_note.text);

    final problem = _controller.validate();
    if (problem != null) {
      _showMessage(problem, type: AppMessageType.warning);
      return;
    }

    final sentMessage = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => OrderReviewPage(controller: _controller),
      ),
    );
    if (!mounted || sentMessage == null) return;
    /**
     * The AI chat needs the created order ID to switch its suggestion card
     * to "sent" and open that order. Normal service requests still return
     * the existing success message, preserving other callers' behavior.
     */
    if (widget.suggestion != null) {
      final orderId = _controller.createdOrderId;
      if (orderId == null || orderId.isEmpty) {
        _showMessage('تعذر فتح الطلب الجديد. تحقق من قائمة الطلبات.',
            type: AppMessageType.warning);
        return;
      }
      Navigator.of(context).pop(orderId);
    } else {
      Navigator.of(context).pop(sentMessage);
    }
  }

  void _showMessage(String text, {AppMessageType type = AppMessageType.success}) {
    showAppMessage(context, text, type: type);
  }

  /// Opens the shared map screen to select the vehicle's pickup location.
 Future<void> _selectPickupFromMap() async {
  final LatLng? selectedLocation = await Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
builder: (_) => LocationPickerPage(
  title: 'تحديد موقع المركبة',
  places: _places,
  initialSelectedLocation: _controller.pickupLocation == null
      ? null
      : LatLng(
          _controller.pickupLocation!.latitude,
          _controller.pickupLocation!.longitude,
        ),
),
    ),
  );

  if (!mounted || selectedLocation == null) return;
  debugPrint(
  '📍 PICKUP LOCATION: Latitude = ${selectedLocation.latitude}, '
  'Longitude = ${selectedLocation.longitude}',
);

  _controller.setPickupLocation(
    GeoPoint(selectedLocation.latitude, selectedLocation.longitude),
  );

}

  
/// Opens the shared map screen to select the towing destination.
Future<void> _selectDropoffFromMap() async {
  final LatLng? selectedLocation = await Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
   builder: (_) => LocationPickerPage(
  title: 'تحديد موقع التوصيل',
  places: _places,
  initialSelectedLocation: _controller.dropoffLocation == null
      ? null
      : LatLng(
          _controller.dropoffLocation!.latitude,
          _controller.dropoffLocation!.longitude,
        ),
),
    ),
  );

  if (!mounted || selectedLocation == null) return;

  debugPrint(
    '📍 DROPOFF LOCATION: Latitude = ${selectedLocation.latitude}, '
    'Longitude = ${selectedLocation.longitude}',
  );

  _controller.setDropoffLocation(
    GeoPoint(selectedLocation.latitude, selectedLocation.longitude),
  );

}


  /// Saved-place shortcuts above a location row.
  Widget _savedBar({required bool forDropoff}) {
    return _SavedLocationsBar(
      places: _places,
      current:
          forDropoff ? _controller.dropoffLocation : _controller.pickupLocation,
      onUse: (place) {
        if (forDropoff) {
          _controller.setDropoffLocation(place.location);
        } else {
          _controller.setPickupLocation(place.location);
        }
      },
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final category = _controller.category;

    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor: CustomerColors.darkPanel,
        foregroundColor: Colors.white,
        title: Text(
          category?.label ?? 'طلب خدمة',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.isLoadingVehicles) {
              return const Center(
                child: CircularProgressIndicator(color: CustomerColors.accent),
              );
            }
            if (_controller.vehiclesError != null) {
              return _Message(
                icon: Icons.wifi_off_rounded,
                title: 'تعذّر التحميل',
                body: _controller.vehiclesError!,
                buttonLabel: 'إعادة المحاولة',
                onPressed: _controller.loadVehicles,
              );
            }
            if (_controller.vehicles.isEmpty) {
              return _Message(
                icon: Icons.directions_car_outlined,
                title: 'لا توجد مركبة',
                body: 'أضف مركبتك أولاً حتى يعرف مزود الخدمة أي مركبة يساعدك فيها.',
                buttonLabel: 'إضافة مركبة',
                onPressed: _addVehicle,
              );
            }
            return _form(category);
          },
        ),
      ),
    );
  }

  static const _freeLabel = 'مجاني';
  static const _freeTotalLabel = 'مجانًا';

  Widget _form(ServiceCategory? category) {
    final options = category?.options ?? const <ServiceOption>[];
    final vehicle = _controller.selectedVehicle;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // ---- #13: which option inside this service ----
              if (_controller.needsVehicleSize) ...[
                // Car wash: tick exterior, interior, or both.
                const _SectionTitle('نوع الغسيل'),
                _OptionCard(
                  label: 'غسيل خارجي',
                  price: formatPrice(_controller.priceOf(CarWash.exteriorId)),
                  // A free car cleaning keeps the real price, crossed out.
                  freeLabel: _controller.isFreeWash ? _freeLabel : null,
                  selected: _controller.washExterior,
                  multi: true,
                  onTap: () => _controller.toggleWashPart(exterior: true),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  label: 'غسيل داخلي',
                  price: formatPrice(_controller.priceOf(CarWash.interiorId)),
                  freeLabel: _controller.isFreeWash ? _freeLabel : null,
                  selected: _controller.washInterior,
                  multi: true,
                  onTap: () => _controller.toggleWashPart(exterior: false),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 14),
                  child: Text(
                    'اختر الاثنين معًا لغسيل داخلي وخارجي بسعر '
                    '${formatPrice(_controller.priceOf(CarWash.fullId))}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ),
              ] else ...[
                const _SectionTitle('نوع الخدمة'),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionCard(
                      label: option.label,
                      price: formatPrice(_controller.priceOf(option.id)),
                      freeLabel: _controller.isFreeWash ? _freeLabel : null,
                      selected: _controller.selectedOptionId == option.id,
                      onTap: () => _controller.selectOption(option.id),
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // ---- #14: which vehicle ----
              const _SectionTitle('المركبة'),
              _Row(
                icon: Icons.directions_car_outlined,
                title: vehicle?.title ?? '',
                subtitle: vehicle == null
                    ? ''
                    : 'لوحة ${vehicle.plateDisplay}'
                        '${_controller.needsVehicleSize && vehicle.size != null ? ' · ${vehicle.size!.shortLabel}' : ''}',
                actionLabel: _controller.vehicles.length > 1 ? 'تغيير' : null,
                onAction: _changeVehicle,
              ),
              const SizedBox(height: 14),

              // Car wash: a vehicle saved before the type existed has none, so
              // the customer says it once and it is saved on the vehicle.
              if (_controller.needsBodyTypeChoice) ...[
                const _SectionTitle('نوع المركبة'),
                for (final size in VehicleSize.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionCard(
                      label: size.label,
                      price: '',
                      selected: _controller.vehicleSizeId == size.id,
                      onTap: () => _controller.chooseBodyType(size.id),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'يحدد نوع المركبة سعر الغسيل، ونحفظه في بيانات مركبتك.',
                    style: TextStyle(
                      fontSize: 12,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ),
              ],

              // ---- #15 / #16: not built yet ----
              const _SectionTitle('الموقع'),

  _savedBar(forDropoff: false),
  _MapLocationRow(
  title: 'موقع المركبة الحالي',
  isSelected: _controller.pickupLocation != null,
  onSelectFromMap: _selectPickupFromMap,
),
              if (_controller.needsDropoff) ...[
                const SizedBox(height: 10),

                _savedBar(forDropoff: true),
                _MapLocationRow(
                  title: 'موقع التوصيل',
                  isSelected: _controller.dropoffLocation != null,
                  onSelectFromMap: _selectDropoffFromMap,
                ),
              ],
              const SizedBox(height: 14),

              // Select when this provider should arrive, inside the existing service form.
              _SchedulingSection(controller: _controller),
              const SizedBox(height: 14),

              // ---- #23: an optional note ----
              const _SectionTitle('ملاحظة لمزود الخدمة (اختياري)'),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 15,
                  color: CustomerColors.primaryText,
                ),
                decoration: InputDecoration(
                  hintText: 'مثال: السيارة في الدور الثاني من المواقف',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9AA1B0),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: CustomerColors.fieldFill,
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: CustomerColors.cardBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: CustomerColors.accent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.selectedOptionId != null) ...[
                  Row(
                    children: [
                      const Text(
                        'السعر التقديري',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: CustomerColors.primaryText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _controller.isFreeWash
                            ? _freeTotalLabel
                            : formatPrice(_controller.estimatedPrice),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: CustomerColors.accent,
                        ),
                      ),
                    ],
                  ),
                  if (_controller.priceDependsOnDistance &&
                      _controller.distanceFee == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تُضاف رسوم المسافة بعد تحديد الموقع',
                          style: TextStyle(
                            fontSize: 12,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: CustomerColors.accent,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'متابعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Small pieces used by this page
// ============================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: CustomerColors.primaryText,
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.price,
    this.freeLabel,
    required this.selected,
    required this.onTap,
    this.multi = false,
  });

  final String label;
  final String price;

  /// True for a tick box (several can be chosen) instead of a round button.
  final bool multi;

  /// Shown in blue after the crossed-out [price] when the service is free.
  final String? freeLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF1FC) : CustomerColors.fieldFill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? CustomerColors.accent : CustomerColors.cardBorder,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(
                multi
                    ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                    : selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                color: selected
                    ? CustomerColors.accent
                    : CustomerColors.secondaryText,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: CustomerColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (freeLabel == null)
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? CustomerColors.accent
                        : CustomerColors.secondaryText,
                  ),
                )
              else ...[
                // The real price, grey and crossed out, then the free label.
                if (price.isNotEmpty) ...[
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CustomerColors.secondaryText,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: CustomerColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 8),
                ],
                Text(
                  freeLabel!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CustomerColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        border: Border.all(color: CustomerColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CustomerColors.darkPanel,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CustomerColors.primaryText,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: CustomerColors.accent,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shortcuts for the customer's saved places, shown above a location row.
///
/// One tap on a place fills this location. Saving a place is done inside the
/// map screen, and deleting or renaming on the profile page, so a stray tap
/// here cannot remove one. The same places serve the pickup and the towing
/// destination.
class _SavedLocationsBar extends StatelessWidget {
  const _SavedLocationsBar({
    required this.places,
    required this.current,
    required this.onUse,
  });

  final SavedLocationsController places;

  /// The location currently picked for this row, if any.
  final GeoPoint? current;

  final void Function(SavedLocation place) onUse;

  static IconData _iconOf(String kind) {
    if (kind == SavedLocation.home) return Icons.home_outlined;
    if (kind == SavedLocation.work) return Icons.work_outline;
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final saved = places.places;
    if (saved.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أماكنك المحفوظة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CustomerColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final place in saved)
                ChoiceChip(
                  avatar: Icon(
                    _iconOf(place.kind),
                    size: 18,
                    color: CustomerColors.accent,
                  ),
                  label: Text(place.label),
                  selected: place.isSameAs(current),
                  showCheckmark: false,
                  selectedColor: const Color(0xFFEAF1FC),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: place.isSameAs(current)
                        ? CustomerColors.accent
                        : CustomerColors.cardBorder,
                  ),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: CustomerColors.primaryText,
                  ),
                  onSelected: (_) => onUse(place),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Location card used when the location must be selected from the map.
///
/// It follows the same visual design as the pickup location card,
/// but uses one full-width map button.
class _MapLocationRow extends StatelessWidget {
  const _MapLocationRow({
    required this.title,
    required this.isSelected,
    required this.onSelectFromMap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onSelectFromMap;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CustomerColors.primaryText,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            isSelected
                ? 'يمكنك تغيير الموقع في أي وقت'
                : 'اختر المكان الذي تريد توصيل المركبة إليه',
            style: const TextStyle(
              fontSize: 13,
              color: CustomerColors.secondaryText,
            ),
          ),

          const SizedBox(height: 12),

          // Confirmation only; this is not a clickable button.
          if (isSelected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7E4C7)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF16834B),
                    size: 21,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'تم تحديد الموقع',
                    style: TextStyle(
                      color: Color(0xFF16834B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: CustomerColors.darkPanel,
              foregroundColor: Colors.white,
            ),
            onPressed: onSelectFromMap,
            icon: const Icon(Icons.map_outlined, size: 19),
            label: Text(
              isSelected ? 'تغيير الموقع من الخريطة' : 'اختيار من الخريطة',
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: CustomerColors.fieldFill,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 30, color: CustomerColors.secondaryText),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: CustomerColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: CustomerColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: CustomerColors.accent,
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Optional scheduling in the existing request flow. The selected appointment
/// is the requested provider arrival time, not the provider dispatch time.
class _SchedulingSection extends StatelessWidget {
  const _SchedulingSection({required this.controller});
  final OrderDraftController controller;

  static DateTime _firstTimeToday(DateTime now) {
    // Round up to the next five-minute option (strictly in the future).
    final next = now.add(const Duration(minutes: 1));
    final roundedMinute = ((next.minute + 4) ~/ 5) * 5;
    return DateTime(next.year, next.month, next.day, next.hour, roundedMinute);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _appointmentLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'صباحًا' : 'مساءً'}';
  }

  Future<void> _pickAppointment(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final earliestToday = _firstTimeToday(now);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 55);
    final todayAvailable = !earliestToday.isAfter(todayEnd);
    var chosenDay = todayAvailable ? today : tomorrow;
    if (controller.scheduledAt != null &&
        (todayAvailable && _sameDay(controller.scheduledAt!, today) ||
            _sameDay(controller.scheduledAt!, tomorrow))) {
      chosenDay = DateTime(controller.scheduledAt!.year,
          controller.scheduledAt!.month, controller.scheduledAt!.day);
    }

    DateTime initialForDay(DateTime selectedDay) {
      final earliest = _sameDay(selectedDay, today)
          ? earliestToday
          : DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final saved = controller.scheduledAt;
      if (saved != null && _sameDay(saved, selectedDay) &&
          !saved.isBefore(earliest) && saved.minute % 5 == 0) {
        return saved;
      }
      return _sameDay(selectedDay, today)
          ? earliest
          : DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
    }

    var picked = initialForDay(chosenDay);
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final start = _sameDay(chosenDay, today)
              ? earliestToday
              : DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
          final end = DateTime(chosenDay.year, chosenDay.month,
              chosenDay.day, 23, 55);
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تحديد موعد وصول مزود الخدمة',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('اختر اليوم والوقت المناسب لك',
                    style: TextStyle(color: CustomerColors.secondaryText)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: todayAvailable ? () => setSheetState(() {
                      chosenDay = today;
                      picked = initialForDay(today);
                    }) : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _sameDay(chosenDay, today)
                          ? CustomerColors.fieldFill : null,
                      side: BorderSide(color: _sameDay(chosenDay, today)
                          ? CustomerColors.accent : CustomerColors.cardBorder),
                    ),
                    child: const Text('اليوم'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(
                    onPressed: () => setSheetState(() {
                      chosenDay = tomorrow;
                      picked = initialForDay(tomorrow);
                    }),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _sameDay(chosenDay, tomorrow)
                          ? CustomerColors.fieldFill : null,
                      side: BorderSide(color: _sameDay(chosenDay, tomorrow)
                          ? CustomerColors.accent : CustomerColors.cardBorder),
                    ),
                    child: const Text('غدًا'),
                  )),
                ]),
                const SizedBox(height: 12),
                // Native wheels: hours, minutes (five-minute precision), AM/PM.
                SizedBox(
                  height: 190,
                  child: CupertinoDatePicker(
                    key: ValueKey(chosenDay),
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    minuteInterval: 5,
                    initialDateTime: picked,
                    minimumDate: start,
                    maximumDate: end,
                    onDateTimeChanged: (value) => picked = value,
                  ),
                ),
                const SizedBox(height: 10),
                Text('الموعد المطلوب: ${_sameDay(chosenDay, today) ? 'اليوم' : 'غدًا'}'
                    ' — ${_appointmentLabel(picked)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () {
                    final current = DateTime.now();
                    final endOfTomorrow = DateTime(current.year,
                        current.month, current.day + 2);
                    if (!picked.isAfter(current) ||
                        !picked.isBefore(endOfTomorrow)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('اختر وقتًا مستقبليًا اليوم أو غدًا')),
                      );
                      return;
                    }
                    Navigator.of(sheetContext).pop(picked);
                  },
                  child: const Text('تأكيد الموعد'),
                )),
              ]),
            ),
          );
        },
      ),
    );
    if (result != null) controller.setScheduledAt(result);
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.scheduledAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerColors.background,
        border: Border.all(color: CustomerColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('متى تحتاج وصول مزود الخدمة؟',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          RadioListTile<bool>(
            title: const Text('طلب الآن'),
            subtitle: const Text('البحث عن مزود متاح فورًا'),
            value: false,
            groupValue: selected != null,
            onChanged: (_) => controller.setScheduledAt(null),
          ),
          RadioListTile<bool>(
            title: const Text('جدولة الطلب'),
            subtitle: const Text('حجز مسبق لوصول المزود اليوم أو غدًا'),
            value: true,
            groupValue: selected != null,
            onChanged: (_) => _pickAppointment(context),
          ),
          if (selected != null) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('موعد الوصول المطلوب'),
              subtitle: Text('${selected.day}/${selected.month}/${selected.year}'
                  ' — ${_appointmentLabel(selected)}'),
              trailing: TextButton(
                onPressed: () => _pickAppointment(context),
                child: const Text('تغيير'),
              ),
            ),
            const Text('يتأكد الحجز بعد قبول مزود الخدمة.',
                style: TextStyle(fontSize: 12,
                    color: CustomerColors.secondaryText)),
          ],
        ],
      ),
    );
  }
}
