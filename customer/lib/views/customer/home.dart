import 'package:flutter/material.dart';

import '../../theme/app_colors.dart'; 
import '../../models/pricing_model.dart';
import '../../models/service_catalog.dart';
import '../../widgets/order_display.dart' show ServiceIcons;
import 'request_service_page.dart';
import 'ai_chat_page.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/loyalty_card.dart';

/// VIEW: the customer home page.
class Home extends StatelessWidget {
  const Home({super.key, required this.uid, this.onOrderSent});

  final String uid;

  /// Called after an order is sent, so the main page can open the orders tab.
  final VoidCallback? onOrderSent;

  Future<void> _openService(
    BuildContext context,
    String categoryId, {
    bool useFreeWash = false,
  }) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RequestServicePage(
          uid: uid,
          categoryId: categoryId,
          useFreeWash: useFreeWash,
        ),
      ),
    );
    if (message == null || !context.mounted) return;
    showAppMessage(context, message, type: AppMessageType.success);
    onOrderSent?.call();
  }

  ///Opens the ai chat 
  void _openAiChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiChatPage(uid: uid)),
    );
  }

  /// Category id of the car wash service, used by the free wash button.
  static const _carWashId = 'carwash';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CustomerColors.background,
      child: Stack(
        children: [
          ListView(
            // Extra bottom space so the last card is not hidden by the button.
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              // Progress toward the next free car wash (#68, #70).
              Padding(
                padding: const EdgeInsets.all(20),
                child: LoyaltyCard(
                  uid: uid,
                  onRequestFreeWash: () =>
                      _openService(context, _carWashId, useFreeWash: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'اطلب خدمة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: CustomerColors.primaryText,
                  ),
                ),
              ),
              _ServicesList(onOpen: (id) => _openService(context, id)),
            ],
          ),
          // The AI assistant (#11) as a floating button.
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: _aiButton(context),
          ),
        ],
      ),
    );
  }

  /// Takes context; returns the floating button that opens the AI chat (#11).
  Widget _aiButton(BuildContext context) {
    return Material(
      color: CustomerColors.darkPanel,
      elevation: 6,
      shadowColor: const Color(0x590E1B33),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _openAiChat(context),
        child: const SizedBox(
          height: 56,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 26,
                  color: Color(0xFF8DB6F7),
                ),
                SizedBox(width: 10),
                Text(
                  'اسأل المساعد',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The services menu (#12): one card per service, with what it covers and
/// the price it starts from. Prices come from Firestore (the same document
/// the request page uses); if they cannot be read the card just shows no price.
class _ServicesList extends StatefulWidget {
  const _ServicesList({required this.onOpen});

  final void Function(String categoryId) onOpen;

  @override
  State<_ServicesList> createState() => _ServicesListState();
}

class _ServicesListState extends State<_ServicesList> {
  late final Future<ServicePrices> _prices = PricingModel().getPrices();

  /// "من 40 ريال": the lowest option price in the service. Towing also adds
  /// the distance, so the card says so. Null when no option has a price yet.
  String? _startingPrice(ServiceCategory category, ServicePrices prices) {
    num? lowest;
    for (final option in category.options) {
      final price = prices.basePriceFor(option.id);
      if (price != null && (lowest == null || price < lowest)) lowest = price;
    }
    if (lowest == null) return null;
    final text = 'من ${lowest.round()} ريال';
    return category.id == ServiceCatalog.towingId ? '$text + المسافة' : text;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ServicePrices>(
      future: _prices,
      builder: (context, snapshot) {
        final prices = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final category in ServiceCatalog.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ServiceCard(
                    category: category,
                    price: prices == null ? null : _startingPrice(category, prices),
                    onTap: () => widget.onOpen(category.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.category,
    required this.price,
    required this.onTap,
  });

  final ServiceCategory category;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // A clear border groups each service (common region), and a soft
      // shadow signals that the card can be tapped.
      color: const Color(0xFFF7F8FA), // very light grey
      elevation: 4,
      shadowColor: const Color(0x290E1B33),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDDE3EC), width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CustomerColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ServiceIcons.of(category.id),
                  size: 28,
                  color: CustomerColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.shortLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: CustomerColors.primaryText,
                      ),
                    ),
                    if (category.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        category.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                    ],
                    if (price != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CustomerColors.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          price!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CustomerColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: CustomerColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
