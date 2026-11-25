import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/dashboard_model.dart';

enum DashboardPeriod { all, week, month, year }

/// Aggregated values only: views never read Firestore or calculate rewards.
class DashboardStats {
  /// Takes a dataset, period and clock; returns statistics using existing fields.
  DashboardStats.from(
    DashboardData data,
    DashboardPeriod period,
    DateTime now,
  ) {
    customers = data.customers.length;
    providers = data.providers.length;
    approvedProviders = data.providers
        .where((p) => p['status'] == 'approved')
        .length;
    final days = switch (period) {
      DashboardPeriod.all => null,
      DashboardPeriod.week => 7,
      DashboardPeriod.month => 30,
      DashboardPeriod.year => 365,
    };
    final today = DateTime(now.year, now.month, now.day);
    final start = days == null
        ? null
        : today.subtract(Duration(days: days - 1));

    // Takes a stored timestamp; includes it in the selected calendar-day window.
    bool inPeriod(dynamic value) {
      if (start == null) return true;
      final date = dateOf(value);
      return date != null && !date.isBefore(start) && !date.isAfter(now);
    }

    final selectedOrders = data.orders
        .where((o) => inPeriod(o['createdAt']))
        .toList();
    orders = selectedOrders.length;
    completedOrders = selectedOrders
        .where((o) => o['status'] == 'completed')
        .length;
    for (final order in selectedOrders) {
      final id = order['serviceCategoryId']?.toString() ?? '';
      final label = serviceLabels[id] ?? 'خدمة أخرى';
      services.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final complaint in data.complaints.where(
      (c) => inPeriod(c['createdAt']),
    )) {
      if (complaint['status'] == 'resolved') {
        resolvedComplaints++;
        if (complaint['freeWashGranted'] == true) compensatedComplaints++;
      } else if (complaint['status'] == 'pending' ||
          complaint['status'] == null) {
        pendingComplaints++;
      }
    }

    // Match LoyaltyController: each customer earns one wash per five paid services.
    final completedByCustomer = <String, List<Map<String, dynamic>>>{};
    for (final order in data.orders) {
      final uid = order['customerId']?.toString() ?? '';
      if (uid.isEmpty ||
          order['status'] != 'completed' ||
          order['usedFreeWash'] == true) {
        continue;
      }
      completedByCustomer.putIfAbsent(uid, () => []).add(order);
    }
    for (final entries in completedByCustomer.values) {
      entries.sort(
        (a, b) => (dateOf(a['completedAt']) ?? DateTime(1970)).compareTo(
          dateOf(b['completedAt']) ?? DateTime(1970),
        ),
      );
      for (var index = 4; index < entries.length; index += 5) {
        if (inPeriod(entries[index]['completedAt'])) loyaltyGranted++;
      }
    }
    compensationGranted = data.complaints
        .where(
          (c) =>
              c['freeWashGranted'] == true &&
              inPeriod(c['compensatedAt'] ?? c['resolvedAt']),
        )
        .length;
    const refunded = {'cancelled', 'rejected', 'autoCancelled'};
    washesUsed = data.orders
        .where(
          (o) =>
              o['usedFreeWash'] == true &&
              !refunded.contains(o['status']) &&
              inPeriod(o['createdAt']),
        )
        .length;

    // A seven-day chart stays useful even when the summary shows all records.
    for (var offset = 6; offset >= 0; offset--) {
      final date = today.subtract(Duration(days: offset));
      final next = date.add(const Duration(days: 1));
      dailyOrders['${date.day}/${date.month}'] = data.orders.where((o) {
        final created = dateOf(o['createdAt']);
        return created != null &&
            !created.isBefore(date) &&
            created.isBefore(next) &&
            !created.isAfter(now);
      }).length;
    }
    scheduledOrders = selectedOrders
        .where((o) => dateOf(o['scheduledAt']) != null)
        .length;
    upcomingScheduled = data.orders.where((o) {
      final date = dateOf(o['scheduledAt']);
      return const {
            'scheduledPending',
            'scheduledAccepted',
          }.contains(o['status']) &&
          date != null &&
          !date.isBefore(now) &&
          date.isBefore(now.add(const Duration(hours: 24)));
    }).length;
    final rated = data.providers
        .where(
          (p) =>
              p['status'] == 'approved' &&
              p['ratingCount'] is num &&
              (p['ratingCount'] as num) > 0 &&
              p['rating'] is num,
        )
        .toList();
    rated.sort((a, b) {
      final result = (b['rating'] as num).compareTo(a['rating'] as num);
      return result != 0
          ? result
          : (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
    });
    topProviders = rated.take(3).toList();
    lowestProviders = rated.reversed.take(3).toList();
  }

  static const serviceLabels = {
    'battery': 'البطارية',
    'fuel': 'الوقود',
    'tires': 'الإطارات',
    'towing': 'السطحة',
    'carwash': 'غسيل السيارة',
  };
  late final int customers,
      providers,
      approvedProviders,
      orders,
      completedOrders;
  late final int compensationGranted,
      washesUsed,
      scheduledOrders,
      upcomingScheduled;
  int loyaltyGranted = 0;
  int pendingComplaints = 0;
  int resolvedComplaints = 0;
  int compensatedComplaints = 0;
  final services = <String, int>{};
  final dailyOrders = <String, int>{};
  late final List<Map<String, dynamic>> topProviders, lowestProviders;

  /// Takes no arguments; returns all granted compensation and loyalty washes.
  int get washesGranted => compensationGranted + loyaltyGranted;

  /// Takes a Firestore timestamp or test date; returns a date or null.
  static DateTime? dateOf(dynamic value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
}

class DashboardController extends ChangeNotifier {
  /// Takes an optional model and clock; creates a controller without starting reads.
  DashboardController({DashboardModel? model, DateTime Function()? clock})
    : _model = model ?? DashboardModel(),
      _clock = clock ?? DateTime.now;

  final DashboardModel _model;
  final DateTime Function() _clock;
  StreamSubscription<DashboardData>? _subscription;
  Timer? _timer;
  DashboardData? _data;
  DashboardStats? stats;
  DashboardPeriod period = DashboardPeriod.all;
  String? error;
  bool loading = true;
  bool _disposed = false;
  int _generation = 0;

  /// Takes no arguments; reports whether any collection is served from local cache.
  bool get isFromCache => _data?.isFromCache ?? false;

  /// Takes no arguments; replaces listeners, clears stale results and starts updates.
  Future<void> start() async {
    final generation = ++_generation;
    _timer?.cancel();
    loading = true;
    error = null;
    stats = null;
    notifyListeners();
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    _subscription = _model.watch().listen(
      (data) {
        if (_disposed || generation != _generation) return;
        _data = data;
        error = null;
        loading = false;
        _recalculate();
      },
      onError: (Object failure) {
        if (_disposed || generation != _generation) return;
        loading = false;
        stats = null;
        error =
            failure is FirebaseException && failure.code == 'permission-denied'
            ? 'لا توجد صلاحية لقراءة الإحصاءات. تأكد من حساب الأدمن وصلاحياته.'
            : 'تعذّر تحميل الإحصاءات. تحقق من الاتصال ثم أعد المحاولة.';
        notifyListeners();
      },
    );
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (error == null && !loading) _recalculate();
    });
  }

  /// Takes the selected period; recalculates statistics without new database reads.
  void selectPeriod(DashboardPeriod value) {
    period = value;
    if (error == null && !loading) _recalculate();
  }

  /// Takes no arguments; derives the visible statistics and notifies the view.
  void _recalculate() {
    if (_data != null) stats = DashboardStats.from(_data!, period, _clock());
    notifyListeners();
  }

  /// Takes no arguments; cancels the timer and database listeners on screen disposal.
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
