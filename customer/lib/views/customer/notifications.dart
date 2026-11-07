import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../controllers/customer_notifications_controller.dart';
import '../../models/customer_notification.dart';
import '../../widgets/app_snackbar.dart';
import 'order_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.controller});
  final CustomerNotificationsController? controller;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final CustomerNotificationsController _controller =
      widget.controller ??
      CustomerNotificationsController(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
  final _opening = <String>{};
  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _controller.start();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _open(CustomerNotification item) async {
    if (!_opening.add(item.id)) return;
    try {
      await _controller.markRead(item);
      if (!mounted || item.orderId.isEmpty) return;
      await OrderDetailsPage.openById(
        Navigator.of(context),
        uid: _controller.uid,
        orderId: item.orderId,
      );
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'تعذر فتح الإشعار، حاول مرة أخرى.');
      }
    } finally {
      _opening.remove(item.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF0E1B33),
      foregroundColor: Colors.white,
      title: const Text('الإشعارات'),
    ),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_controller.error!),
                TextButton(
                  onPressed: () {
                    _controller.start();
                    setState(() {});
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        if (_controller.items.isEmpty) {
          return const Center(child: Text('لا توجد إشعارات حالياً'));
        }
        return ListView.builder(
          itemCount: _controller.items.length,
          itemBuilder: (context, index) {
            final item = _controller.items[index];
            return ListTile(
              tileColor: item.read ? null : const Color(0xFFEAF1FC),
              leading: Icon(
                item.read
                    ? Icons.notifications_none
                    : Icons.notifications_active,
              ),
              title: Text(item.title, textDirection: TextDirection.rtl),
              subtitle: Text(item.body, textDirection: TextDirection.rtl),
              onTap: () => _open(item),
            );
          },
        );
      },
    ),
  );
}
