import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../controllers/provider_availability_controller.dart';
import '../controllers/provider_stats_controller.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({
    super.key,
    this.firstName = '',
    this.authService,
  });

  final String firstName;
  final AuthService? authService;

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
 bool isAvailable = false;
bool isLoadingAvailability = true;
bool isSavingAvailability = false;

late final ProviderAvailabilityController _availabilityController;

// Quick statistics (#36). Null until loaded; shown as 0 meanwhile.
final ProviderStatsController _statsController = ProviderStatsController();
ProviderStats? _stats;

@override
void initState() {
  super.initState();
  _availabilityController = ProviderAvailabilityController(
    widget.authService ?? AuthService(),
  );
  _loadAvailability();
  _loadStats();
}

Future<void> _loadStats() async {
  final stats = await _statsController.load();
  if (!mounted) return;
  setState(() => _stats = stats);
}

Future<void> _loadAvailability() async {
  try {
    final availability = await _availabilityController.loadAvailability();
    if (!mounted) return;

    setState(() {
      isAvailable = availability;
      isLoadingAvailability = false;
    });
  } catch (_) {
    if (!mounted) return;

    setState(() {
      isLoadingAvailability = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر تحميل حالة التوفر')),
    );
  }
}

Future<void> _changeAvailability(bool value) async {
  setState(() => isSavingAvailability = true);

  try {
    await _availabilityController.updateAvailability(value);
    if (!mounted) return;

    setState(() => isAvailable = value);
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حفظ حالة التوفر')),
    );
  } finally {
    if (mounted) {
      setState(() => isSavingAvailability = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.firstName.isEmpty
                        ? 'مرحباً بك'
                        : 'مرحباً، ${widget.firstName}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Color(0xFF0E1B33),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'جاهز لمساعدة عملائك اليوم!',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Color(0xFF69728C), fontSize: 15),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Availability Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6F5)),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Availability Switch
                Switch(
  value: isAvailable,
  activeThumbColor: const Color(0xFF1C63D6),
  onChanged: isLoadingAvailability || isSavingAvailability
      ? null
      : _changeAvailability,
),

                // Availability Text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'حالة التوفر',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Color(0xFF0E1B33),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      isAvailable ? 'متاح لاستقبال الطلبات' : 'غير متاح',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Color(0xFF69728C), fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Quick Statistics Title
          const Text(
            'إحصائيات سريعة',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFF0E1B33),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star_rounded,
                  value: '0.0',
                  label: 'التقييم',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildStatCard(
                  icon: Icons.payments_outlined,
                  value: _stats?.earningsText ?? '0',
                  label: 'صافي الأرباح (ر.س)',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildStatCard(
                  icon: Icons.receipt_long_rounded,
                  value: '${_stats?.completedToday ?? 0}',
                  label: 'طلبات اليوم',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Available Requests
          const Text(
            'الطلبات المتاحة',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFF0E1B33),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // No available requests yet
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6F5)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined, color: Color(0xFF69728C), size: 36),

                SizedBox(height: 10),

                Text(
                  'لا توجد طلبات متاحة حالياً',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Color(0xFF0E1B33),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'عند توفر طلبات جديدة في منطقتك، ستظهر هنا',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF69728C), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1C63D6), size: 26),

          const SizedBox(height: 8),

          Text(
            value,
            style: TextStyle(
              color: Color(0xFF0E1B33),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF69728C), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
