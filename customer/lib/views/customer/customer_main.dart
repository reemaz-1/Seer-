import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'profile_page.dart';
import 'home.dart';
import 'orders.dart';

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
      return Home(
        uid: FirebaseAuth.instance.currentUser!.uid,
        onOrderSent: () => setState(() => selectedIndex = 2),
      );
    case 1:
      return CustomerOrders(uid: FirebaseAuth.instance.currentUser!.uid);

    case 2:
      return ProfilePage(
        uid: FirebaseAuth.instance.currentUser!.uid,
      );

    default:
      return Home(uid: FirebaseAuth.instance.currentUser!.uid);
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
alignment: Alignment.centerRight,
        child: Text(
          textAlign: TextAlign.right,
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
      // Show the main AppBar only on the Home tab.
appBar: selectedIndex == 0
    ? AppBar(
        backgroundColor: const Color(0xFF0E1B33),
        elevation: 0,
        centerTitle: true,

       

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

// Customer greeting on the right
leadingWidth: 126,
leading: Padding(
  padding: const EdgeInsets.only(right: 16),
  child: Center(
    child: _buildCustomerGreeting(),
  ),
),
       )
    : null,

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