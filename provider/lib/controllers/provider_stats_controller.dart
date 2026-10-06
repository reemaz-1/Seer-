import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';

/// The numbers shown under "quick statistics" on the home page (#36).
class ProviderStats {
  const ProviderStats({required this.earnings, required this.completedToday});

  /// Net earnings: the total paid on all completed orders, in riyals.
  final double earnings;

  /// Earnings as shown on the card, e.g. "250" or "250.5".
  String get earningsText => earnings == earnings.roundToDouble()
      ? earnings.toInt().toString()
      : earnings.toStringAsFixed(1);

  /// Orders this provider completed today.
  final int completedToday;
}

/// CONTROLLER: loads the provider's quick statistics (#36).
class ProviderStatsController {
  ProviderStatsController({OrderModel? model, FirebaseAuth? auth})
      : _model = model ?? OrderModel(),
        _auth = auth ?? FirebaseAuth.instance;

  final OrderModel _model;
  final FirebaseAuth _auth;

  /// Returns null when the user is signed out or the numbers cannot be
  /// read, so the home page simply keeps showing 0.
  Future<ProviderStats?> load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final results = await Future.wait([
        _model.sumEarnings(uid),
        _model.countCompletedToday(uid),
      ]);
      return ProviderStats(
        earnings: results[0].toDouble(),
        completedToday: results[1].toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
