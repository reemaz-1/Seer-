import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../theme/app_colors.dart';

class AdminHome extends StatefulWidget {
  /// Takes an optional controller for tests; creates the dashboard page.
  const AdminHome({super.key, this.controller});
  final DashboardController? controller;

  /// Takes no arguments; creates the state that owns the dashboard subscription.
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  late final DashboardController _controller;

  /// Takes no arguments; starts listening to the dashboard's read-only data source.
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? DashboardController();
    _controller.start();
  }

  /// Takes no arguments; disposes only controllers created by this page.
  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// Takes the build context; renders loading, errors or responsive statistics.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_controller.error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(_controller.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _controller.start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        );
      }
      final stats = _controller.stats!;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'لوحة التحكم',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'نظرة شاملة على الطلبات ومقدمي الخدمة والهدايا في مكان واحد',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('عرض الطلبات والشكاوى والهدايا لـ:'),
                for (final entry in const {
                  DashboardPeriod.all: 'كل الفترات',
                  DashboardPeriod.week: 'آخر 7 أيام',
                  DashboardPeriod.month: 'آخر 30 يومًا',
                  DashboardPeriod.year: 'آخر 365 يومًا',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _controller.period == entry.key,
                    onSelected: (_) => _controller.selectPeriod(entry.key),
                  ),
              ],
            ),
            if (_controller.isFromCache) ...[
              const SizedBox(height: 12),
              const Text(
                'البيانات محفوظة محليًا؛ تتحدث عند توفر الاتصال.',
                style: TextStyle(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 24),
            _ResponsiveTiles(
              children: [
                _Metric(
                  'إجمالي الطلبات',
                  stats.orders,
                  Icons.receipt_long_outlined,
                  subtitle: '${stats.completedOrders} طلب مكتمل',
                ),
                _Metric(
                  'إجمالي مقدمي الخدمة',
                  stats.providers,
                  Icons.local_shipping_outlined,
                  subtitle:
                      '${stats.approvedProviders} مزود معتمد · جميع الحسابات',
                ),
                _Metric(
                  'إجمالي العملاء',
                  stats.customers,
                  Icons.people_outline,
                  subtitle: 'جميع حسابات العملاء',
                ),
                _Metric(
                  'هدايا غسيل مجانية',
                  stats.washesGranted,
                  Icons.card_giftcard,
                  subtitle: '${stats.washesUsed} مستخدمة أو محجوزة',
                  dark: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TwoColumns(
              first: _Panel(
                title: 'الطلبات خلال آخر 7 أيام',
                subtitle: 'عدد الطلبات حسب تاريخ الإنشاء',
                child: _Bars(values: stats.dailyOrders),
              ),
              second: _Panel(
                title: 'الطلبات حسب الخدمة',
                subtitle: 'توزيع أنواع الخدمات المطلوبة خلال الفترة',
                child: _ServiceChart(values: stats.services),
              ),
            ),
            const SizedBox(height: 20),
            _TwoColumns(
              first: _Panel(
                title: 'الهدايا المجانية',
                subtitle: 'غسيل سيارة مجاني للعملاء',
                child: Column(
                  children: [
                    _CountRow(
                      'إجمالي الممنوحة',
                      stats.washesGranted,
                      strong: true,
                    ),
                    _CountRow('تعويض عن شكوى', stats.compensationGranted),
                    _CountRow('مكافأة الولاء', stats.loyaltyGranted),
                    const Divider(height: 24),
                    _CountRow(
                      'المستخدمة أو المحجوزة',
                      stats.washesUsed,
                      strong: true,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'بعد كل 5 خدمات مكتملة مدفوعة تُمنح غسلة مجانية. الطلب المجاني الملغي أو المرفوض لا يُحسب كمستخدم.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              second: _Panel(
                title: 'الشكاوى والتعويض',
                subtitle: 'حالة الشكاوى المنشأة خلال الفترة',
                child: Column(
                  children: [
                    _CountRow(
                      'إجمالي الشكاوى',
                      stats.pendingComplaints + stats.resolvedComplaints,
                      strong: true,
                    ),
                    _CountRow(
                      'قيد المراجعة',
                      stats.pendingComplaints,
                      color: Colors.orange,
                    ),
                    _CountRow(
                      'تم الحل',
                      stats.resolvedComplaints,
                      color: AppColors.success,
                    ),
                    _CountRow('منها مع تعويض', stats.compensatedComplaints),
                    const SizedBox(height: 12),
                    const Text(
                      'الحل بدون تعويض لا يعني أن الشكوى مرفوضة.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Panel(
              title: 'الطلبات المجدولة',
              subtitle: 'الطلبات المحجوزة لوقت لاحق مقابل الفورية',
              child: Column(
                children: [
                  _CountRow('مجدولة', stats.scheduledOrders),
                  _CountRow('فورية', stats.orders - stats.scheduledOrders),
                  _CountRow(
                    'مجدولة قادمة خلال 24 ساعة',
                    stats.upcomingScheduled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _TwoColumns(
              first: _Panel(
                title: 'أعلى 3 مقدمي خدمة تقييمًا',
                subtitle:
                    'المزودون المعتمدون الذين لديهم تقييمات · جميع الفترات',
                child: _ProviderList(providers: stats.topProviders),
              ),
              second: _Panel(
                title: 'أقل 3 مقدمي خدمة تقييمًا',
                subtitle: 'لمتابعة جودة الخدمة · جميع الفترات',
                child: _ProviderList(providers: stats.lowestProviders),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'فلتر الفترة يستخدم تاريخ إنشاء الطلب والشكوى، وتاريخ منح الهدية أو حجزها. السجلات دون تاريخ تظهر في «كل الفترات».',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    },
  );
}

class _ResponsiveTiles extends StatelessWidget {
  /// Takes metric cards; creates a responsive grid without fixed card heights.
  const _ResponsiveTiles({required this.children});
  final List<Widget> children;

  /// Takes layout constraints; returns one, two or four cards per row.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 480
          ? 2
          : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 16) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  /// Takes a label, count, icon and caption; creates a summary card.
  const _Metric(
    this.title,
    this.value,
    this.icon, {
    required this.subtitle,
    this.dark = false,
  });
  final String title, subtitle;
  final int value;
  final IconData icon;
  final bool dark;

  /// Takes the build context; returns the styled metric and its accessible label.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: dark ? AppColors.darkPanel : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white70 : AppColors.secondaryText,
                ),
              ),
            ),
            Icon(
              icon,
              color: dark ? const Color(0xFFE8B65E) : AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: dark ? Colors.white : AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white70 : AppColors.secondaryText,
          ),
        ),
      ],
    ),
  );
}

class _TwoColumns extends StatelessWidget {
  /// Takes two sections; creates a layout that stacks on narrow screens.
  const _TwoColumns({required this.first, required this.second});
  final Widget first, second;

  /// Takes available width; returns a row or column without horizontal overflow.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 760
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 20), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 20),
              Expanded(child: second),
            ],
          ),
  );
}

class _Panel extends StatelessWidget {
  /// Takes a title, caption and body; creates a dashboard section.
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;

  /// Takes the build context; returns the section card.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 24),
        child,
      ],
    ),
  );
}

class _CountRow extends StatelessWidget {
  /// Takes a label and integer; creates a readable statistic row.
  const _CountRow(this.label, this.count, {this.strong = false, this.color});
  final String label;
  final int count;
  final bool strong;
  final Color? color;

  /// Takes the build context; returns the label and count with wrapping text.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color ?? AppColors.secondaryText),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: TextStyle(
            fontSize: strong ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.primaryText,
          ),
        ),
      ],
    ),
  );
}

class _Bars extends StatelessWidget {
  /// Takes seven dated order counts; creates the daily chart.
  const _Bars({required this.values});
  final Map<String, int> values;

  /// Takes the build context; returns bars and textual values for every day.
  @override
  Widget build(BuildContext context) {
    final maximum = math.max(1, values.values.fold<int>(0, math.max));
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in values.entries)
            Expanded(
              child: Semantics(
                label: '${entry.key}: ${entry.value} طلب',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: math.max(2, entry.value / maximum * 155),
                        decoration: BoxDecoration(
                          color: entry.key == values.keys.last
                              ? AppColors.accent
                              : const Color(0xFFB2C7ED),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        child: Text(
                          entry.key,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _chartColors = [
  Color(0xFF183268),
  Color(0xFF3465CE),
  Color(0xFF82A7E5),
  Color(0xFFE6A344),
  Color(0xFFBACBEC),
  Color(0xFF7F8EA5),
];

class _ServiceChart extends StatelessWidget {
  /// Takes service counts; creates a ring chart with a complete text legend.
  const _ServiceChart({required this.values});
  final Map<String, int> values;

  /// Takes the build context; renders an empty state or distribution chart.
  @override
  Widget build(BuildContext context) {
    final total = values.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('لا توجد طلبات خلال الفترة')),
      );
    }
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: CustomPaint(
            painter: _RingPainter(entries.map((e) => e.value).toList()),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('طلب'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _chartColors[index % _chartColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entries[index].key)),
                Text(
                  '${entries[index].value} · ${(entries[index].value / total * 100).toStringAsFixed(1)}٪',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  /// Takes segment counts; creates a painter using the dashboard palette.
  _RingPainter(this.values);
  final List<int> values;

  /// Takes a canvas and size; paints proportional ring segments without labels.
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return;
    var start = -math.pi / 2;
    final rect = (Offset.zero & size).deflate(14);
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = _chartColors[index % _chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 25,
      );
      start += sweep;
    }
  }

  /// Takes the previous painter; reports whether segment counts changed.
  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      values.toString() != oldDelegate.values.toString();
}

class _ProviderList extends StatelessWidget {
  /// Takes ranked provider records; creates their compact rating list.
  const _ProviderList({required this.providers});
  final List<Map<String, dynamic>> providers;

  /// Takes the build context; returns actual names and ratings or an empty state.
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (providers.isEmpty) const Text('لا توجد تقييمات بعد'),
      for (final provider in providers)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEBF0F9),
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${provider['firstName'] ?? ''} ${provider['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${provider['ratingCount']} تقييم',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.star, color: Color(0xFFE6A344), size: 18),
              Text((provider['rating'] as num).toStringAsFixed(1)),
            ],
          ),
        ),
    ],
  );
}
