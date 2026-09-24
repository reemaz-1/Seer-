import 'package:flutter/material.dart';

import 'current_order.dart';
import 'history.dart';

class ProviderOrders extends StatelessWidget {
  const ProviderOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF1C63D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF69728C),
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'الطلبات الحالية'),
                  Tab(text: 'الطلبات السابقة'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ProviderCurrentOrder(),
                  ProviderHistory(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}