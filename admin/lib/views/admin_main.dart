import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import 'complaints.dart';
import 'home.dart';
import 'registration_requests_list_screen.dart';
import 'users.dart';

class AdminMain extends StatefulWidget {
  /// Takes an optional dashboard controller for tests; creates the admin shell.
  const AdminMain({super.key, this.dashboardController});
  final DashboardController? dashboardController;

  /// Takes no arguments; creates the navigation state.
  @override
  State<AdminMain> createState() => _AdminMainState();
}

class _AdminMainState extends State<AdminMain> {
  int _selectedIndex = 0;
  static const _titles = [
    'لوحة التحكم',
    'طلبات التسجيل',
    'المستخدمون',
    'الشكاوى',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.assignment_outlined,
    Icons.people_outline,
    Icons.report_outlined,
  ];

  /// Takes no arguments; signs out and reports the outcome using the shared snackbar.
  Future<void> _logOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        showAppMessage(
          context,
          'تم تسجيل الخروج بنجاح',
          type: AppMessageType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'تعذّر تسجيل الخروج. أعد المحاولة.',
          type: AppMessageType.error,
        );
      }
    }
  }

  /// Takes the build context; returns a desktop sidebar or a mobile navigation drawer.
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final pages = [
          AdminHome(controller: widget.dashboardController),
          const RegistrationRequestsListScreen(),
          const AdminUsers(),
          const AdminComplaints(),
        ];
        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: compact
              ? Drawer(
                  backgroundColor: AppColors.darkPanel,
                  child: _navigation(closeDrawer: true),
                )
              : null,
          appBar: compact
              ? AppBar(
                  title: Text(_titles[_selectedIndex]),
                  backgroundColor: AppColors.darkPanel,
                  foregroundColor: Colors.white,
                )
              : null,
          body: Row(
            children: [
              if (!compact) SizedBox(width: 220, child: _navigation()),
              Expanded(child: pages[_selectedIndex]),
            ],
          ),
        );
      },
    ),
  );

  /// Takes whether navigation is in a drawer; returns scrollable existing destinations.
  Widget _navigation({bool closeDrawer = false}) => Material(
    color: AppColors.darkPanel,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سِير',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'لوحة إدارة النظام',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              children: [
                for (var index = 0; index < _titles.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: _selectedIndex == index
                          ? AppColors.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        selected: _selectedIndex == index,
                        selectedTileColor: Colors.transparent,
                        selectedColor: Colors.white,
                        iconColor: Colors.white70,
                        textColor: Colors.white70,
                        leading: Icon(_icons[index], size: 21),
                        title: Text(
                          _titles[index],
                          style: TextStyle(
                            fontWeight: _selectedIndex == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          if (closeDrawer) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: _logOut,
              icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
