import 'package:flutter/material.dart';

import '../controllers/notification_controller.dart';
import '../models/app_notification.dart';
import '../theme/app_colors.dart';

/// The provider's notifications list (#47).
///
/// Opening the page marks everything as read, so the bell badge clears.
/// Tapping a request that can still be answered closes the page and returns
/// true, and the main screen then opens the available requests.
class ProviderNotifications extends StatefulWidget {
  const ProviderNotifications({super.key, this.controller});

  /// Null only when notifications could not start; the page then shows the
  /// empty state.
  final NotificationController? controller;

  @override
  State<ProviderNotifications> createState() => _ProviderNotificationsState();
}

class _ProviderNotificationsState extends State<ProviderNotifications> {
  /// Unread when the page opened, so they keep their dot after being marked.
  late final Set<String> _unreadAtOpen;

  @override
  void initState() {
    super.initState();
    _unreadAtOpen = {
      for (final n in widget.controller?.items ?? const <AppNotification>[])
        if (!n.read) n.id,
    };
    widget.controller?.markAllRead();
  }

  void _open(AppNotification notification) {
    if (!notification.isActive(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا الطلب لم يعد متاحاً.')),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: controller == null
          ? const _EmptyState()
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final items = controller.items;
                if (items.isEmpty) return const _EmptyState();
                final now = DateTime.now();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = items[index];
                    return _NotificationTile(
                      notification: n,
                      unread: _unreadAtOpen.contains(n.id),
                      active: n.isActive(now),
                      onTap: () => _open(n),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.unread,
    required this.active,
    required this.onTap,
  });

  final AppNotification notification;
  final bool unread;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unread ? const Color(0xFFEAF1FC) : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: active ? AppColors.blue : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.build_circle_outlined,
                  size: 20,
                  color: active ? Colors.white : AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      active
                          ? 'متاح الآن · ${_timeAgo(notification.createdAt)}'
                          : 'انتهى وقت الطلب · ${_timeAgo(notification.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? AppColors.blue : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "الآن", "قبل 5 دقائق", "قبل ساعتين"... in short Arabic.
  static String _timeAgo(DateTime? time) {
    if (time == null) return 'الآن';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
    return 'قبل ${diff.inDays} يوم';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 55,
            color: AppColors.secondaryText,
          ),
          SizedBox(height: 12),
          Text(
            'لا توجد إشعارات حالياً',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 17, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}
