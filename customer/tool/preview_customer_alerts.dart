// Development-only Android preview. Never imports production Firebase options.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:customer/controllers/customer_alerts_controller.dart';
import 'package:customer/controllers/customer_notifications_controller.dart';
import 'package:customer/controllers/customer_orders_controller.dart';
import 'package:customer/models/customer_notification.dart';
import 'package:customer/models/customer_orders_model.dart';
import 'package:customer/widgets/notification_banner.dart';

const project = 'demo-seer-alert-preview';
const host =
    '10.0.2.2'; // Android Emulator -> this computer; never a live service.
late FirebaseFirestore db;
late String uid;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(
    name: project,
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:1234567890:android:preview',
      messagingSenderId: '1234567890',
      projectId: project,
    ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(host, 9196, automaticHostMapping: false);
  uid = (await auth.signInAnonymously()).user!.uid;
  db = FirebaseFirestore.instanceFor(app: app);
  db.settings = const Settings(persistenceEnabled: false);
  db.useFirestoreEmulator(host, 8186);
  await seed('customers/$uid', {'firstName': 'عميل تجريبي'});
  debugPrint('ALERT_PREVIEW_READY uid=$uid project=$project');
  runApp(const Preview());
}

Map<String, dynamic> value(dynamic v) {
  if (v == null) return {'nullValue': null};
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(value).toList()},
    };
  }
  throw StateError('Unsupported preview fixture');
}

Future<void> seed(String path, Map<String, dynamic> data) async {
  final response = await http.patch(
    Uri.parse(
      'http://$host:8186/v1/projects/$project/databases/(default)/documents/$path',
    ),
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, value(v)))}),
  );
  if (response.statusCode != 200) {
    throw StateError('Local fixture failed: ${response.statusCode}');
  }
}

class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> with WidgetsBindingObserver {
  final scaffold = GlobalKey<ScaffoldMessengerState>();
  final pageKey = GlobalKey<ScaffoldState>();
  late final CustomerAlertsController alerts;
  late final CustomerNotificationsController notices;
  late final CustomerOrdersController orders;
  final log = <String>[];
  var sequence = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    alerts = CustomerAlertsController(
      onBanner: (item, sound) {
        record('BANNER ${item.id} sound=$sound');
        final bannerContext = pageKey.currentContext;
        if (bannerContext != null) {
          NotificationBanner.show(
            bannerContext,
            title: item.title,
            body: item.body,
            withSound: sound,
            onTap: () => record('OPEN_ORDER ${item.orderId}'),
          );
        }
      },
    );
    orders = CustomerOrdersController(
      uid: uid,
      model: CustomerOrdersModel(firestore: db),
    );
    orders.addListener(syncOrders);
    orders.start();
    notices = CustomerNotificationsController(
      uid: uid,
      model: CustomerNotificationModel(firestore: db),
    );
    notices.onNew = (item) {
      record('FIRESTORE_NOTICE ${item.id}');
      alerts.onNotification(item);
    };
    notices.start();
  }

  void record(String text) {
    debugPrint('ALERT_PREVIEW $text');
    if (mounted) setState(() => log.insert(0, text));
  }

  void syncOrders() {
    if (!orders.isLoading && orders.errorMessage == null) {
      alerts.setActive(orders.currentOrders.isNotEmpty);
      record('ACTIVE_ORDERS ${orders.currentOrders.length}');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    record('LIFECYCLE ${state.name}');
    alerts.setForeground(state == AppLifecycleState.resumed);
  }

  Future<void> active() async {
    await seed('orders/preview-order', {
      'customerId': uid,
      'status': 'accepted',
      'providerId': 'preview-provider',
      'candidateProviderIds': ['preview-provider'],
      'rejectedBy': [],
      'vehicleTitle': 'مركبة تجريبية',
      'serviceOptionLabel': 'خدمة تجريبية',
      'createdAt': DateTime.now(),
    });
  }

  Future<void> notice(String status) async {
    sequence++;
    await seed('notifications/preview-$sequence', {
      'recipientId': uid,
      'type': 'orderStatusChanged',
      'orderId': 'preview-order',
      'title': 'تجربة إشعار $sequence — $status',
      'body': 'محاكي محلي، بلا بيانات حقيقية',
      'read': false,
      'createdAt': DateTime.now(),
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationBanner.hide();
    notices.dispose();
    orders.removeListener(syncOrders);
    orders.dispose();
    alerts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: scaffold,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      key: pageKey,
      appBar: AppBar(title: const Text('اختبار محلي — ليس تطبيق الإنتاج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'نفس CustomerAlertsController وCustomerNotificationsController وخدمة Android الفعلية.\nFirebase Auth/Firestore على محاكٍ محلي فقط.',
          ),
          ElevatedButton(
            onPressed: active,
            child: const Text('بدء طلب تجريبي نشط'),
          ),
          ElevatedButton(
            onPressed: () => notice('في المقدمة'),
            child: const Text('إشعار من Firestore الآن'),
          ),
          ElevatedButton(
            onPressed: () async {
              await seed('orders/preview-order', {
                'customerId': uid,
                'providerId': 'preview-provider',
                'status': 'completed',
              });
            },
            child: const Text('إنهاء الطلب وإيقاف المتابعة'),
          ),
          const Divider(),
          ...log
              .take(18)
              .map((line) => Text(line, textDirection: TextDirection.ltr)),
        ],
      ),
    ),
  );
}
