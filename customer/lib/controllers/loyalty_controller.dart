import 'dart:async';

import '../models/complaint.dart';
import '../models/complaint_model.dart';
import '../models/customer_orders_model.dart';
import '../models/order.dart';

/// The customer's loyalty card and free car washes (#66, #68, #69, #70).
///
/// Nothing is stored as a counter: every number is worked out from the
/// customer's orders and complaints, so it can never drift out of date.
class LoyaltyProgress {
  /// Takes the completed services, the compensated complaints and the free
  /// washes already used; creates the progress.
  const LoyaltyProgress({
    required this.completed,
    this.compensations = 0,
    this.used = 0,
  });

  /// Completed services needed for one free car wash (#69).
  static const goal = 5;

  /// Every completed service the customer has ever had (#68).
  final int completed;

  /// Complaints the admin compensated with a free wash (#65).
  final int compensations;

  /// Car washes the customer already took for free (#67).
  final int used;

  /// Takes no inputs; returns the free washes earned from the card (#69).
  int get earnedFromCard => completed ~/ goal;

  /// Takes no inputs; returns the free washes the customer can still use
  /// (#66). Never below zero.
  int get available {
    final left = earnedFromCard + compensations - used;
    return left < 0 ? 0 : left;
  }

  /// Takes no inputs; returns true when a free wash is waiting.
  bool get hasFreeWash => available > 0;

  /// Takes no inputs; returns how many cars on the current card are lit.
  int get filled => completed % goal;

  /// Takes no inputs; returns how many services are left for the next wash.
  int get remaining => goal - filled;

  /// Takes no inputs; returns the card title.
  String get title => 'مكافأة الولاء';

  /// Takes no inputs; returns the line about the next free wash (#70).
  String get message {
    if (completed == 0) return 'أكمل $goal خدمات للحصول على خدمة تنظيف سيارتك مجانًا';
    switch (remaining) {
      case 1:
        return 'باقي خدمة واحدة للحصول على خدمة تنظيف سيارتك مجانًا';
      case 2:
        return 'باقي خدمتان للحصول على خدمة تنظيف سيارتك مجانًا';
      default:
        return 'باقي $remaining خدمات للحصول على خدمة تنظيف سيارتك مجانًا';
    }
  }

  /// Takes no inputs; returns how many free washes are waiting (#66), or
  /// null when there are none.
  String? get availableLabel {
    switch (available) {
      case 0:
        return null;
      case 1:
        return 'متاح لك تنظيف السيارة مجانًا';
      case 2:
        return 'متاح لك تنظيف السيارة مجانًا مرتين';
      default:
        return available <= 10
            ? 'متاح لك تنظيف السيارة مجانًا $available مرات'
            : 'متاح لك تنظيف السيارة مجانًا $available مرة';
    }
  }

  /// Takes no inputs; returns the "3 / 5" counter.
  String get counter => '$filled / $goal';

  /// Takes no inputs; returns the screen reader label for the timeline.
  String get semanticsLabel => 'أكملت $filled من $goal خدمات';
}

/// CONTROLLER: builds the loyalty progress from the customer's orders and
/// complaints (#66, #68, #69).
class LoyaltyController {
  /// Takes optional models for tests; creates the controller.
  LoyaltyController({
    CustomerOrdersModel? orders,
    ComplaintModel? complaints,
  }) : _orders = orders ?? CustomerOrdersModel(),
       _complaints = complaints ?? ComplaintModel();

  final CustomerOrdersModel _orders;
  final ComplaintModel _complaints;

  /// Order statuses where no provider served the customer.
  static const _notServed = {
    OrderStatus.cancelled,
    OrderStatus.rejected,
    OrderStatus.autoCancelled,
  };

  /// Takes order statuses; returns how many of them are completed.
  static int countCompleted(Iterable<String> statuses) =>
      statuses.where((status) => status == OrderStatus.completed).length;

  /// Takes the customer's orders and complaints; returns the progress.
  static LoyaltyProgress progressFrom(
    List<ServiceOrder> orders,
    List<Complaint> complaints,
  ) {
    return LoyaltyProgress(
      completed: countCompleted(orders.where((o) => !o.usedFreeWash).map((o) => o.status)),
      compensations: complaints.where((c) => c.freeWashGranted).length,
      // A free wash that never happened (cancelled, rejected or no answer)
      // gives the reward back, so it does not count.
      used: orders
          .where((o) => o.usedFreeWash && !_notServed.contains(o.status))
          .length,
    );
  }

  /// Takes the customer id; returns a live stream of their progress. It
  /// waits for the orders, and treats complaints it cannot read as none so
  /// the card still shows.
  Stream<LoyaltyProgress> watch(String uid) {
    StreamSubscription<List<ServiceOrder>>? ordersSub;
    StreamSubscription<List<Complaint>>? complaintsSub;
    List<ServiceOrder>? orders;
    List<Complaint>? complaints;
    late final StreamController<LoyaltyProgress> out;

    void emit() {
      if (orders == null || complaints == null) return;
      out.add(progressFrom(orders!, complaints!));
    }

    out = StreamController<LoyaltyProgress>(
      onListen: () {
        ordersSub = _orders.watchCustomerOrders(uid).listen((value) {
          orders = value;
          emit();
        }, onError: out.addError);
        complaintsSub = _complaints.watchComplaintsBy(uid).listen((value) {
          complaints = value;
          emit();
        }, onError: (Object _) {
          complaints = const [];
          emit();
        });
      },
      onCancel: () async {
        await ordersSub?.cancel();
        await complaintsSub?.cancel();
      },
    );
    return out.stream;
  }
}
