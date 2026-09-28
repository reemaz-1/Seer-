import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../screens/provider_profile_screen.dart';

import '../services/auth_service.dart';
import '../widgets/logout_button.dart';
import 'home.dart';
import 'notifications.dart';
import 'orders.dart';

class ServiceProviderMain extends StatefulWidget {
  const ServiceProviderMain({super.key, this.authService, this.firstName = ''});
  final AuthService? authService;
  final String firstName;

  @override
  State<ServiceProviderMain> createState() => _ServiceProviderMainState();
}

class _ServiceProviderMainState extends State<ServiceProviderMain> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),

      // Index 1 opens the combined Orders screen.
      body: selectedIndex == 0
          ? ProviderHome(firstName: widget.firstName)
          : selectedIndex == 1
          ? const ProviderOrders()
          : ProviderProfileScreen(authService: widget.authService),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4FA),
        elevation: 0,
        centerTitle: true,
        leadingWidth: 130,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.firstName.isEmpty
                  ? 'مرحباً بك'
                  : 'مرحباً، ${widget.firstName}',
              style: const TextStyle(
                color: Color(0xFF0E1B33),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        title: const Text(
          'سَيْر',
          style: TextStyle(
            color: Color(0xFF0E1B33),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          LogoutButton(authService: widget.authService),
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
                      builder: (context) => const ProviderNotifications(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: const Color(0xFFF1F4FA),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          child: GNav(
            backgroundColor: Colors.transparent,
            color: const Color(0xFF69728C),
            activeColor: const Color(0xFF1C63D6),
            tabBackgroundColor: const Color(0xFFDCE6F5),
            padding: const EdgeInsets.all(16),
            gap: 8,
            selectedIndex: selectedIndex,
            onTabChange: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            tabs: const [
              GButton(icon: Icons.home_rounded, text: 'الرئيسية'),
              GButton(icon: Icons.receipt_long_rounded, text: 'الطلبات'),
              GButton(icon: Icons.person_rounded, text: 'الحساب'),
            ],
          ),
        ),
      ),
    );
  }
}
