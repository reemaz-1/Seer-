import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_alerts.dart';
import '../theme/app_colors.dart';

/// In-app notification banner (#47), built from scratch.
///
/// Slides down from the top over whatever screen is open, plays the phone's
/// notification tone or vibrates (following the phone's mode), and hides
/// itself after a few seconds. Tapping it runs [onTap];
/// swiping it up dismisses it. Only one banner is shown at a time.
class NotificationBanner {
  NotificationBanner._();

  static const Duration visibleFor = Duration(seconds: 5);
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onTap,
    bool withSound = true,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerView(
        title: title,
        body: body,
        onTap: () {
          _remove(entry);
          onTap();
        },
        onDismissed: () => _remove(entry),
      ),
    );
    _current = entry;
    overlay.insert(entry);

    if (withSound) DeviceAlerts.playForCurrentMode();
  }

  /// Removes the banner that is showing, if any.
  static void hide() {
    final entry = _current;
    if (entry != null) _remove(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (identical(_current, entry)) _current = null;
  }
}

class _BannerView extends StatefulWidget {
  const _BannerView({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismissed,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  State<_BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<_BannerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -1.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _slide.forward();
    _timer = Timer(NotificationBanner.visibleFor, _close);
  }

  /// Slides the banner back up, then removes it.
  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _slide.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: GestureDetector(
                onTap: widget.onTap,
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < 0) _close();
                },
                child: Material(
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              if (widget.body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'عرض',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
