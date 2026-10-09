import 'package:flutter/material.dart';

import '../../theme/app_colors.dart'; 
import '../../models/service_catalog.dart';
import 'request_service_page.dart';
import 'ai_chat_page.dart';

/// VIEW: the customer home page.
class Home extends StatelessWidget {
  const Home({super.key, required this.uid, this.onOrderSent});

  final String uid;

  /// Called after an order is sent, so the main page can open the orders tab.
  final VoidCallback? onOrderSent;

  static const _icons = <String, IconData>{
    'battery': Icons.battery_charging_full,
    'fuel': Icons.local_gas_station,
    'tires': Icons.tire_repair,
    'towing': Icons.local_shipping_outlined,
  };

  Future<void> _openService(BuildContext context, String categoryId) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RequestServicePage(uid: uid, categoryId: categoryId),
      ),
    );
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    onOrderSent?.call();
  }

  ///Opens the ai chat 
  void _openAiChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiChatPage(uid: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CustomerColors.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _aiCard(context),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
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
          _servicesGrid(context),
        ],
      ),
    );
  }

  /// The AI assistant card (#11)
  Widget _aiCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAiChat(context),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        color: CustomerColors.darkPanel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'مو متأكد وش المشكلة؟',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'صف المشكلة لمساعد Seer الذكي',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: CustomerColors.cardBorder,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: CustomerColors.secondaryText),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Expanded(
                  child: Text(
                    'صف المشكلة...',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: CustomerColors.cardBorder),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: CustomerColors.accent),
                  onPressed: () => _openAiChat(context),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// The services menu (#12)
  Widget _servicesGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: ServiceCatalog.categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final category = ServiceCatalog.categories[index];

        return Material(
          color: CustomerColors.fieldFill,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: CustomerColors.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _openService(context, category.id),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _icons[category.id] ?? Icons.build_outlined,
                  size: 36,
                  color: CustomerColors.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  category.shortLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CustomerColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}