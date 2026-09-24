import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'registration_requests_list_screen.dart';
import 'complaints.dart';
import 'users.dart';

class AdminMain extends StatefulWidget {
  const AdminMain({super.key});

  @override
  State<AdminMain> createState() => _AdminMainState();
}

class _AdminMainState extends State<AdminMain> {
  int selectedIndex = 0;

  static const Color navy = Color(0xFF0E1B33);
  static const Color accent = Color(0xFF1C63D6);

final List<Widget> pages = const [
  RegistrationRequestsListScreen(),
  AdminUsers(),
  AdminComplaints(),
];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 220,
              color: navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'لوحة الإدارة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Divider(
                    color: Colors.white24,
                    height: 1,
                  ),

                  const SizedBox(height: 20),

_buildMenuItem(
  icon: Icons.assignment_outlined,
  title: 'طلبات التسجيل',
  index: 0,
),

_buildMenuItem(
  icon: Icons.people_outline,
  title: 'المستخدمون',
  index: 1,
),

_buildMenuItem(
  icon: Icons.report_outlined,
  title: 'الشكاوى',
  index: 2,
),

                  const Spacer(),

                  const Divider(
                    color: Colors.white24,
                    height: 1,
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل الخروج بنجاح'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main area
            Expanded(
              child: Column(
                children: [
                  // Original top Seer bar
                  Container(
                    height: 85,
                    color: navy,
                    alignment: Alignment.center,
                    child: const Text(
                      'سَيْر',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: pages[selectedIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            selectedIndex = index;
          });
        },
        leading: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}