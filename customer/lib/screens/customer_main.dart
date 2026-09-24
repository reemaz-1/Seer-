import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'home.dart';
import 'notifications.dart';
import 'orders.dart';
import 'tracking.dart';

class CustomerMain extends StatefulWidget {
  const CustomerMain({super.key});

  @override
  State<CustomerMain> createState() => _CustomerMainState();
}

class _CustomerMainState extends State<CustomerMain> {
  int selectedIndex = 0;

  Widget _selectedPage() {
    switch (selectedIndex) {
      case 0:
        return const Home();

      case 1:
        return const TrackingPage();

      case 2:
        return const CustomerOrders();

      case 3:
        // Connect the profile screen here later.
        return const Home();

      default:
        return const Home();
    }
  }

  Widget _buildCustomerGreeting() {
    final user = FirebaseAuth.instance.currentUser;

    // No authenticated customer.
    if (user == null) {
      return _greetingText('مرحباً');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _greetingText('مرحباً');
        }

        final customerData = snapshot.data!.data();
        final firstName =
            customerData?['firstName']?.toString().trim();

        if (firstName == null || firstName.isEmpty) {
          return _greetingText('مرحباً');
        }

        return _greetingText('مرحباً، $firstName');
      },
    );
  }

  Widget _greetingText(String greeting) {
    return SizedBox(
      width: 110,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          greeting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: _selectedPage(),

      // Upper bar
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1B33),
        elevation: 0,
        centerTitle: true,

        // Notification button on the right
        leadingWidth: 72,
        leading: Padding(
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
                    builder: (context) =>
                        const NotificationsPage(),
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

        // Logo in the center
        title: const Text(
          'سَيْر',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),

        // Real customer name on the left
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: _buildCustomerGreeting(),
            ),
          ),
        ],
      ),

      // Bottom navigation bar
      bottomNavigationBar: Container(
        color: const Color(0xFFFFFFFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 20,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: GNav(
              backgroundColor: Colors.transparent,
              color: const Color(0xFF6B7385),
              activeColor: const Color(0xFF1C63D6),
              tabBackgroundColor: const Color(0xFFEAF1FC),
              padding: const EdgeInsets.all(16),
              gap: 8,
              selectedIndex: selectedIndex,
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
                  icon: Icons.near_me_rounded,
                  text: 'التتبع',
                ),
                GButton(
                  icon: Icons.receipt_long_rounded,
                  text: 'الطلبات',
                ),
                GButton(
                  icon: Icons.person_rounded,
                  text: 'الحساب',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}