import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'home.dart';
import 'notifications.dart';
import 'tracking.dart';


class CustomerMain extends StatefulWidget {
  const CustomerMain({Key? key}) : super(key: key);

  @override
  State<CustomerMain> createState() => _CustomerMainState();
}

class _CustomerMainState extends State<CustomerMain> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      
      body: selectedIndex == 2
    ? const TrackingPage()
    : const Home(),

      // Upper Bar
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1B33),
        elevation: 0,
        centerTitle: true,

        // Left side
        leadingWidth: 130,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'مرحباً، نورة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Center
        title: const Text(
          'سَيْر',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),

        // Right side
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C63D6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const NotificationsPage(),
    ),
  );
                },
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Bar
      bottomNavigationBar: Container(
        color: const Color(0xFFFFFFFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 20.0,
          ),
          child: GNav(
            backgroundColor: Colors.transparent,
            color: const Color(0xFF6B7385),
            activeColor: const Color(0xFF1C63D6),
            tabBackgroundColor: const Color(0xFFEAF1FC),
            padding: const EdgeInsets.all(16),
            gap: 8,

            onTabChange: (index) {
              setState(() {
                selectedIndex = index;
              });
            },

            tabs: const [
  GButton(
    icon: Icons.home_rounded,
    text: 'الصفحة الرئيسية',
  ),
  GButton(
    icon: Icons.receipt_long_rounded,
    text: 'الطلبات',
  ),
  GButton(
    icon: Icons.near_me_rounded,
    text: 'التتبع',
  ),
  GButton(
    icon: Icons.person_rounded,
    text: 'الحساب',
  ),
],
          ),
        ),
      ),
    );
  }
}