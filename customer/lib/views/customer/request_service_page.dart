import 'package:flutter/material.dart';

import '../../controllers/order_draft_controller.dart';
import '../../controllers/location_controller.dart';
import '../../theme/app_colors.dart';
import '../../models/pricing_model.dart';
import '../../models/service_catalog.dart';
import '../../widgets/vehicle_picker_sheet.dart';
import 'order_review_page.dart';
import 'vehicle_form_page.dart';
import 'location_picker_page.dart';

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
  });

  final String uid;

  /// Which service was tapped on the home page.
  final String categoryId;

  /// The vehicle shown on the home page, pre-selected here.
  final String? preferredVehicleId;

  @override
  State<RequestServicePage> createState() => _RequestServicePageState();
}

class _RequestServicePageState extends State<RequestServicePage> {
  late final _controller = OrderDraftController(
    uid: widget.uid,
    categoryId: widget.categoryId,
    preferredVehicleId: widget.preferredVehicleId,
  );

  // Handles GPS/map location separately from the order-building controller.
  // This keeps the location logic reusable regardless of the map provider.
  final _locationController = LocationController();

  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadVehicles();
    _controller.loadPrices();
  }

  @override
  void dispose() {
    _note.dispose();
    _locationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------- Actions ----------------

  /// Gets the customer's current GPS location and saves it
  /// as the pickup location for this specific order draft (#15).
  Future<void> _useCurrentLocation() async {
    final success = await _locationController.getCurrentLocation();

    if (!mounted) return;

    if (!success) {
      _showMessage(
        _locationController.errorMessage ?? 'تعذر تحديد موقعك الحالي',
      );
      return;
    }

    final location = _locationController.pickupLocation;

    if (location != null) {
      // The LocationController handles GPS.
      // The OrderDraftController only keeps the result for this order.
      _controller.setPickupLocation(location);
    }
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
      _showMessage(problem);
      return;
    }

    final sentMessage = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => OrderReviewPage(controller: _controller),
      ),
    );
    if (!mounted || sentMessage == null) return;
    // The order was sent: close this page too and let the home page report it.
    Navigator.of(context).pop(sentMessage);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Opens the shared map screen to select the vehicle's pickup location.
  Future<void> _selectPickupFromMap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LocationPickerPage(title: 'تحديد موقع المركبة'),
      ),
    );
  }

  /// Opens the shared map screen to select the towing destination.
  Future<void> _selectDropoffFromMap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LocationPickerPage(title: 'تحديد موقع التوصيل'),
      ),
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
              const _SectionTitle('نوع الخدمة'),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionCard(
                    label: option.label,
                    price: formatPrice(_controller.priceOf(option.id)),
                    selected: _controller.selectedOptionId == option.id,
                    onTap: () => _controller.selectOption(option.id),
                  ),
                ),
              const SizedBox(height: 14),

              // ---- #14: which vehicle ----
              const _SectionTitle('المركبة'),
              _Row(
                icon: Icons.directions_car_outlined,
                title: vehicle?.title ?? '',
                subtitle: vehicle == null
                    ? ''
                    : 'لوحة ${vehicle.plateNumberArabic}',
                actionLabel: _controller.vehicles.length > 1 ? 'تغيير' : null,
                onAction: _changeVehicle,
              ),
              const SizedBox(height: 14),

              // ---- #15 / #16: not built yet ----
              const _SectionTitle('الموقع'),

              ListenableBuilder(
                listenable: _locationController,
                builder: (context, _) {
                  return _LocationRow(
                    icon: Icons.my_location,
                    title: 'موقع المركبة الحالي',
                    isSelected: _controller.pickupLocation != null,
                    isLoading: _locationController.isLoading,
                    onUseCurrentLocation: _useCurrentLocation,
                    onSelectFromMap: _selectPickupFromMap,
                  );
                },
              ),
              if (_controller.needsDropoff) ...[
                const SizedBox(height: 10),

                _MapLocationRow(
                  title: 'موقع التوصيل',
                  isSelected: _controller.dropoffLocation != null,
                  onSelectFromMap: _selectDropoffFromMap,
                ),
              ],
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
                        formatPrice(_controller.estimatedPrice),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: CustomerColors.accent,
                        ),
                      ),
                    ],
                  ),
                  if (_controller.priceDependsOnDistance)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'يُضاف رسم المسافة بعد تحديد الموقع',
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
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
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
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
              Text(
                price,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? CustomerColors.accent
                      : CustomerColors.secondaryText,
                ),
              ),
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

/// Reusable location card for selecting a pickup or drop-off location.
///
/// The card only displays location state and actions.
/// GPS and map logic are handled outside this widget.
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.isLoading,
    required this.onUseCurrentLocation,
    required this.onSelectFromMap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onUseCurrentLocation;
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
                : 'حدد موقع المركبة التي تحتاج إلى خدمة',
            style: const TextStyle(
              fontSize: 13,
              color: CustomerColors.secondaryText,
            ),
          ),

          const SizedBox(height: 12),

          // Shows confirmation only; this is intentionally not clickable.
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

          Row(
            children: [
              // Opens the shared map-selection page for the pickup location.
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: CustomerColors.darkPanel,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onSelectFromMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('اختيار من الخريطة'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: CustomerColors.darkPanel,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading ? null : onUseCurrentLocation,
                  icon: isLoading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 19),
                  label: Text(
                    isLoading ? 'جاري التحديد...' : 'استخدام موقعي الحالي',
                  ),
                ),
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
