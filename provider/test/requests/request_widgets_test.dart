import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/controllers/provider_requests_controller.dart';
import 'package:provider/views/available_requests.dart';
import 'package:provider/views/request_details_page.dart';
import 'package:provider/widgets/order_display.dart';
import 'package:provider/widgets/plate_number_view.dart';

import 'request_fakes.dart';

/// Takes no inputs; verifies the Arabic request UI, timer and confirmation flow.
void main() {
  var disposed = false;
  late DateTime now;
  late FakeRequests repository;
  late FakeLocation location;
  late ProviderRequestsController controller;
  // Takes no inputs; releases owned timers once before widget invariant checks.
  void disposeController() {
    if (!disposed) {
      disposed = true;
      controller.dispose();
    }
  }

  setUp(() {
    disposed = false;
    now = DateTime.utc(2026, 10, 9, 12);
    repository = FakeRequests();
    location = FakeLocation();
    controller = ProviderRequestsController(
      providerId: 'p1',
      repository: repository,
      location: location,
      now: () => now,
    );
  });
  tearDown(() async {
    disposeController();
    await repository.stream.close();
    await location.stream.close();
  });

  /// Takes a tester; renders populated details without Firebase or platform GPS.
  Future<void> showDetails(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller.start();
    repository.stream.add([requestFixture(now)]);
    await tester.pumpWidget(
      MaterialApp(
        home: RequestDetailsPage(
          orderId: 'request-1',
          controller: controller,
          addresses: FakeAddresses(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'details show service, Saudi plate, addresses, base price; hide contact',
    (tester) async {
      await showDetails(tester);
      expect(find.text('خدمة السطحة'), findsOneWidget);
      expect(find.text('سطحة عادية'), findsOneWidget);
      expect(find.text('المركبة عند مدخل الحي'), findsOneWidget);
      expect(find.text('شارع الملك فهد، الرياض'), findsOneWidget);
      expect(find.text('حي النرجس، الرياض'), findsOneWidget);
      expect(find.text('السعر الأساسي: 150 ر.س'), findsOneWidget);
      expect(
        find.text('لا يشمل رسوم المسافة، وليس السعر النهائي.'),
        findsOneWidget,
      );
      expect(find.byType(PlateNumberView), findsOneWidget);
      expect(find.text('PRIVATE CUSTOMER'), findsNothing);
      expect(find.text('PRIVATE PHONE'), findsNothing);
      expect(tester.takeException(), isNull);
      disposeController();
    },
  );

  testWidgets('countdown ticks in accept button and disables at exact expiry', (
    tester,
  ) async {
    await showDetails(tester);
    now = now.add(const Duration(seconds: 55));
    await tester.pump(const Duration(seconds: 1));
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('request-countdown')),
    );
    expect(text.data, '1:05');
    expect(
      text.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(
      tester
          .widget<FractionallySizedBox>(
            find.byKey(const ValueKey('request-time-fill')),
          )
          .widthFactor,
      closeTo(65 / 120, .001),
    );
    now = now.add(const Duration(seconds: 65));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('accept-request')), findsNothing);
    expect(find.byKey(const ValueKey('reject-request')), findsNothing);
    expect(
      find.text(ProviderRequestsController.unavailableMessage),
      findsOneWidget,
    );
    disposeController();
  });

  testWidgets('reject requires confirmation and Back makes no write', (
    tester,
  ) async {
    await showDetails(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('reject-request')));
    await tester.tap(find.byKey(const ValueKey('reject-request')));
    await tester.pumpAndSettle();
    expect(find.text('هل أنت متأكد من رفض هذا الطلب؟'), findsOneWidget);
    expect(repository.rejects, 0);
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(repository.rejects, 0);
    disposeController();
  });

  testWidgets(
    'expiry while confirmation is open disables confirm without writing',
    (tester) async {
      await showDetails(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('reject-request')));
      await tester.tap(find.byKey(const ValueKey('reject-request')));
      await tester.pumpAndSettle();
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('confirm-reject')))
            .onPressed,
        isNull,
      );
      expect(repository.rejects, 0);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      disposeController();
    },
  );

  testWidgets(
    'available list retires expired requests without a new snapshot',
    (tester) async {
      controller.start();
      repository.stream.add([requestFixture(now)]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AvailableRequests(
                controller: controller,
                addresses: FakeAddresses(),
                onAccepted: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('request-1')), findsOneWidget);
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('request-1')), findsNothing);
      expect(find.text('لا توجد طلبات متاحة حالياً'), findsOneWidget);
      disposeController();
    },
  );

  testWidgets(
    'accept still returns to parent when snapshot retires details first',
    (tester) async {
      controller.start();
      repository.stream.add([requestFixture(now)]);
      repository.pending = Completer<void>();
      bool? accepted;
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  accepted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailsPage(
                        orderId: 'request-1',
                        controller: controller,
                        addresses: FakeAddresses(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('accept-request')));
      await tester.tap(find.byKey(const ValueKey('accept-request')));
      await tester.pump();
      repository.stream.add([]);
      await tester.pump();
      expect(
        find.text(ProviderRequestsController.unavailableMessage),
        findsOneWidget,
      );
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      expect(find.text('open'), findsOneWidget);
      disposeController();
    },
  );

  test('customer status/date/time/price conventions are retained', () {
    expect(OrderStatusStyle.labelOf('rejected'), 'ملغي');
    expect(OrderStatusStyle.labelOf('pending'), 'بانتظار مزود خدمة');
    expect(OrderFormat.price(150.5), '150.50 ر.س');
    expect(OrderFormat.price(null), 'يحدد لاحقاً');
    expect(OrderFormat.date(DateTime(2026, 10, 9)), '2026/10/09');
    expect(OrderFormat.time(DateTime(2026, 10, 9, 13, 5)), '1:05 م');
  });
}
