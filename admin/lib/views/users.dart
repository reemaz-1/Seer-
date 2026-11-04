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
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String? _updatingId;

  late final Stream<List<AdminUserData>> _customersStream =
      _controller.getCustomers();
  late final Stream<List<AdminUserData>> _providersStream =
      _controller.getApprovedProviders();

  static const Color navy = Color(0xFF0E1B33);
  static const Color accent = Color(0xFF1C63D6);
  static const Color background = Color(0xFFF7F9FC);
  static const Color secondaryText = Color(0xFF6B7385);

  Future<void> _confirmChange(AdminUserData user) async {
    if (_updatingId != null) return;
    final suspend = !user.isSuspended;
    final action = suspend ? 'إيقاف' : 'إعادة تفعيل';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد $action الحساب'),
        content: Text(
          'هل تريد $action حساب ${user.name.isEmpty ? user.email : user.name}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('تأكيد $action'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _updatingId = '${user.type}:${user.id}');
    try {
      await _controller.setSuspended(user, suspend);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(suspend ? 'تم إيقاف الحساب' : 'تمت إعادة تفعيل الحساب')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث الحساب. يرجى المحاولة مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: background,
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<List<AdminUserData>>(
          stream: _customersStream,
          builder: (context, customerSnapshot) {
            if (customerSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (customerSnapshot.hasError) {
              return const Center(child: Text('حدث خطأ أثناء تحميل المستخدمين'));
            }
            return StreamBuilder<List<AdminUserData>>(
              stream: _providersStream,
              builder: (context, providerSnapshot) {
                if (providerSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (providerSnapshot.hasError) {
                  return const Center(child: Text('حدث خطأ أثناء تحميل مزودي الخدمة'));
                }

                final customers = filterAdminUsers(
                  customerSnapshot.data ?? [],
                  search: _searchQuery,
                  type: _typeFilter,
                  status: _statusFilter,
                );
                final providers = filterAdminUsers(
                  providerSnapshot.data ?? [],
                  search: _searchQuery,
                  type: _typeFilter,
                  status: _statusFilter,
                );

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
                      onChanged: (value) => setState(() => _searchQuery = value),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: _typeFilter,
                            decoration: const InputDecoration(
                              labelText: 'نوع الحساب',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('جميع الحسابات')),
                              DropdownMenuItem(value: 'customer', child: Text('العملاء')),
                              DropdownMenuItem(value: 'provider', child: Text('مزودو الخدمة')),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _typeFilter = value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'حالة الحساب',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                              DropdownMenuItem(value: 'active', child: Text('نشط')),
                              DropdownMenuItem(value: 'suspended', child: Text('موقوف')),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _statusFilter = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (customers.isEmpty && providers.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'لا يوجد مستخدمون لعرضهم حالياً',
                            style: TextStyle(color: secondaryText, fontSize: 18),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          children: [
                            if (customers.isNotEmpty) ...[
                              const Text(
                                'العملاء',
                                style: TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              ...customers.map((user) => _buildUserCard(
                                    user: user,
                                    icon: Icons.person_outline,
                                    type: 'عميل',
                                  )),
                              const SizedBox(height: 20),
                            ],
                            if (providers.isNotEmpty) ...[
                              const Text(
                                'مزودو الخدمة',
                                style: TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              ...providers.map((user) => _buildUserCard(
                                    user: user,
                                    icon: Icons.build_outlined,
                                    type: 'مزود خدمة',
                                    extra: '${user.vehicleBrand} ${user.vehicleModel}',
                                  )),
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
    required AdminUserData user,
    required IconData icon,
    required String type,
    String? extra,
  }) {
    final busy = _updatingId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: accent.withValues(alpha: 0.1),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? 'بدون اسم' : user.name,
                  style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(type, style: const TextStyle(color: accent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text('البريد الإلكتروني: ${user.email.isEmpty ? 'غير متوفر' : user.email}',
                    style: const TextStyle(color: secondaryText)),
                Text('رقم الجوال: ${user.phone.isEmpty ? 'غير متوفر' : user.phone}',
                    style: const TextStyle(color: secondaryText)),
                if (extra != null && extra.trim().isNotEmpty)
                  Text('المركبة: $extra', style: const TextStyle(color: secondaryText)),
                const SizedBox(height: 8),
                Text(
                  user.isSuspended ? 'الحالة: موقوف' : 'الحالة: نشط',
                  style: TextStyle(
                    color: user.isSuspended ? Colors.red.shade700 : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: busy ? null : () => _confirmChange(user),
            child: Text(user.isSuspended ? 'إعادة تفعيل' : 'إيقاف الحساب'),
          ),
        ],
      ),
    );
  }
}
