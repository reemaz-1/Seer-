import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  static const services = [
    {'name': 'البطارية', 'icon': Icons.battery_charging_full},
    {'name': 'الوقود', 'icon': Icons.local_gas_station},
    {'name': 'الإطارات', 'icon': Icons.tire_repair},
    {'name': 'السحب', 'icon': Icons.local_shipping_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AI Card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: const Color(0xFF0E1B33),
            borderRadius: BorderRadius.circular(20),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'مو متأكد وش المشكلة؟',
                textAlign: TextAlign.right,
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
                style: TextStyle(
                  color: Color(0xFFE4E8F0),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),

                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF6B7385),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Expanded(
                      child: Text(
                        'صف المشكلة...',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Color(0xFFE4E8F0),
                        ),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1C63D6),
                      ),
                      onPressed: () {
                        // Later: open the AI page
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Services
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'اطلب خدمة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E1B33),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: services.length,

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),

          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                border: Border.all(
                  color: const Color(0xFFE4E8F0),
                ),
                borderRadius: BorderRadius.circular(16),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    services[index]['icon'] as IconData,
                    size: 36,
                    color: const Color(0xFF1C63D6),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    services[index]['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0E1B33),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}