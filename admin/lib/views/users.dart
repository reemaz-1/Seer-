import 'package:flutter/material.dart';
import '../controllers/admin_users_controller.dart';
import '../models/admin_users_model.dart';

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final AdminUsersController _controller = const AdminUsersController();
  String _searchQuery = '';

  late final Stream<List<AdminUserData>> _customersStream =
    _controller.getCustomers();

late final Stream<List<AdminUserData>> _providersStream =
    _controller.getApprovedProviders();

  static const Color navy = Color(0xFF0E1B33);
  static const Color accent = Color(0xFF1C63D6);
  static const Color background = Color(0xFFF7F9FC);
  static const Color secondaryText = Color(0xFF6B7385);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: background,
        padding: const EdgeInsets.all(24),

        // Listen to the customers collection
        child: StreamBuilder<List<AdminUserData>>(
          stream: _customersStream,
          builder: (context, customerSnapshot) {
            if (customerSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (customerSnapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل المستخدمين'),
              );
            }

            // Listen to approved service providers
            return StreamBuilder<List<AdminUserData>>(
              stream: _providersStream,
              builder: (context, providerSnapshot) {
                if (providerSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (providerSnapshot.hasError) {
                  return const Center(
                    child: Text('حدث خطأ أثناء تحميل مزودي الخدمة'),
                  );
                }

                bool matchesSearch(AdminUserData user) {
  final query = _searchQuery.trim().toLowerCase();
  if (query.isEmpty) return true;

  return '${user.firstName} ${user.lastName}'
          .toLowerCase()
          .contains(query) ||
      user.email.toLowerCase().contains(query) ||
      user.phone.contains(query);
}

final customers = (customerSnapshot.data ?? [])
    .where(matchesSearch)
    .toList();

final providers = (providerSnapshot.data ?? [])
    .where(matchesSearch)
    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'المستخدمون',
                      style: TextStyle(
                        color: navy,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),
                    TextField(
  onChanged: (value) {
    setState(() {
      _searchQuery = value;
    });
  },
  decoration: InputDecoration(
    hintText: 'ابحث بالاسم أو البريد الإلكتروني أو رقم الجوال',
    prefixIcon: const Icon(Icons.search),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.white,
  ),
),

const SizedBox(height: 20),

                    if (customers.isEmpty && providers.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'لا يوجد مستخدمون لعرضهم حالياً',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          children: [
                            // CUSTOMER SECTION
                            if (customers.isNotEmpty) ...[
                              const Text(
                                'العملاء',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              ...customers.map((document) {
                                final data = document;

                                return _buildUserCard(
                                  icon: Icons.person_outline,
                                  type: 'عميل',
                                  name:
                                      '${data.firstName} ${data.lastName}',
                                  email: data.email.isEmpty
                                      ? 'غير متوفر'
                                      : data.email,
                                  phone: data.phone.isEmpty
                                      ? 'غير متوفر'
                                      : data.phone,
                                );
                              }),

                              const SizedBox(height: 20),
                            ],

                            // SERVICE PROVIDER SECTION
                            if (providers.isNotEmpty) ...[
                              const Text(
                                'مزودو الخدمة',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              ...providers.map((document) {
                                final data = document;

                                return _buildUserCard(
                                  icon: Icons.build_outlined,
                                  type: 'مزود خدمة',
                                  name:
                                      '${data.firstName} ${data.lastName}',
                                  email: data.email.isEmpty
                                      ? 'غير متوفر'
                                      : data.email,
                                  phone: data.phone.isEmpty
                                      ? 'غير متوفر'
                                      : data.phone,
                                  extra:
                                      '${data.vehicleBrand} ${data.vehicleModel}',
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required IconData icon,
    required String type,
    required String name,
    required String email,
    required String phone,
    String? extra,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE4E8F0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: accent.withValues(alpha: 0.1),
            child: Icon(
              icon,
              color: accent,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'بدون اسم' : name,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  type,
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'البريد الإلكتروني: $email',
                  style: const TextStyle(
                    color: secondaryText,
                  ),
                ),

                Text(
                  'رقم الجوال: $phone',
                  style: const TextStyle(
                    color: secondaryText,
                  ),
                ),

                if (extra != null && extra.trim().isNotEmpty)
                  Text(
                    'المركبة: $extra',
                    style: const TextStyle(
                      color: secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}