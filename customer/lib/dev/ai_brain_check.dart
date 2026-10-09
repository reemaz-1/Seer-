// A separate entry point for testing the AI brain (piece 1) on the emulator,
// without touching main.dart. Run it with:
//
//   flutter run -t lib/dev/ai_brain_check.dart
//
// It is a bare chat: type, or tap a quick message, and watch the reply stream
// in, with the summary card and order events printed as boxes. Everything is
// also printed in the Debug Console.
//
// By default orders are NOT written: the demo actions use two sample cars and
// pretend to place the order. To test the real Firestore write, sign in a test
// account in this app first and set _useRealFirestore to true.
//
// Delete this folder after integration, or keep it as a developer tool; the
// real app never imports it.

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';
import '../models/pricing_model.dart';
import '../models/vehicle.dart';
import '../services/ai_assistant.dart';
import '../services/ai_order_actions.dart';
import '../services/fake_ai_assistant.dart';
import '../services/gemini_ai_assistant.dart';

const _useRealFirestore = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase AI Logic refuses requests without App Check. The debug provider
  // prints a token in the Debug Console the first time; register it once in
  // the Firebase console (Security > App Check > Apps > Manage debug tokens).
  // `androidProvider` works with every firebase_app_check version. On the
  // newest one it shows a blue "deprecated" hint, which is safe to ignore.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  runApp(const _AiBrainCheckApp());
}

/// Two sample cars and fallback prices; "places" the order without writing.
class _DemoOrderActions implements AiOrderActions {
  int _count = 0;

  @override
  Future<List<Vehicle>> loadVehicles() async => FakeAiAssistant.sampleVehicles;

  @override
  Future<ServicePrices> loadPrices() async => ServicePrices.fallback();

  /// Pretends GPS worked. Return null here to test the "GPS failed" path.
  @override
  Future<GeoPoint?> currentLocation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return FakeAiAssistant.samplePickup;
  }

  @override
  Future<String> placeOrder(OrderSummary summary) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'DEMO-${++_count}';
    debugPrint('DEMO placeOrder $id: ${summary.vehicle.title} / '
        '${summary.optionLabel} / ${summary.estimatedPrice} / "${summary.note}"');
    return id;
  }
}

const _quickMessages = [
  'كفري الأمامي نزل فجأة وعندي سبير',
  'السيارة ما تتحرك بعد حادث بسيط، أحتاج سطحة للورشة',
  'السيارة ما تشتغل، أسمع تكتكة والأنوار ضعيفة',
  'نعم أكد الطلب',
  'لا، هذي للجمس مو الكامري',
  'خلص البنزين والسيارة وقفت',
  'يطلع دخان من الكبوت وأنا على الطريق السريع',
  'نسيت المفتاح داخل السيارة وقفلت',
  'اكتب لي قصيدة عن القهوة',
];

class _AiBrainCheckApp extends StatelessWidget {
  const _AiBrainCheckApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: _AiBrainCheckPage(),
      ),
    );
  }
}

class _AiBrainCheckPage extends StatefulWidget {
  const _AiBrainCheckPage();

  @override
  State<_AiBrainCheckPage> createState() => _AiBrainCheckPageState();
}

class _Line {
  _Line(this.text, {this.isCustomer = false, this.isEvent = false});
  String text;
  final bool isCustomer;
  final bool isEvent;
}

class _AiBrainCheckPageState extends State<_AiBrainCheckPage> {
  late final AiAssistant _assistant = GeminiAiAssistant(
    actions: _useRealFirestore
        ? FirestoreAiOrderActions(uid: FirebaseAuth.instance.currentUser!.uid)
        : _DemoOrderActions(),
  );
  final _input = TextEditingController();
  final _lines = <_Line>[];
  bool _busy = false;

  /// The last summary card shown, so the demo map button can update it.
  String? _lastSummaryId;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {Uint8List? image}) async {
    if (_busy || (text.trim().isEmpty && image == null)) return;
    _input.clear();
    setState(() {
      _busy = true;
      _lines.add(_Line(image == null ? text : '$text  [صورة]', isCustomer: true));
    });
    debugPrint('العميل: $text');

    _Line? bubble; // the assistant text currently streaming
    try {
      await for (final event in _assistant.send(text, imageBytes: image)) {
        setState(() {
          switch (event) {
            case AiTextDelta(text: final delta):
              if (bubble == null) {
                bubble = _Line('');
                _lines.add(bubble!);
              }
              bubble!.text += delta;
            case AiVehicleChanged(:final vehicle):
              _addEvent('🚗 تغيّرت المركبة: ${vehicle.title}');
              bubble = null;
            case AiOrderSummaryShown(:final summary):
              _addEvent('🧾 ملخص ${summary.id}\n'
                  'المركبة: ${summary.vehicle.title}\n'
                  'الخدمة: ${summary.categoryLabel} ← ${summary.optionLabel}\n'
                  'السعر التقديري: ${summary.estimatedPrice ?? '—'} ريال'
                  '${summary.priceDependsOnDistance ? ' + حسب المسافة' : ''}\n'
                  'ملاحظة: ${summary.note.isEmpty ? '—' : summary.note}\n'
                  '${_locationText(summary)}');
              _lastSummaryId = summary.id;
              bubble = null;
            case AiOrderSummaryCancelled(:final summaryId):
              _addEvent('✖ أُلغي الملخص $summaryId');
              bubble = null;
            case AiOrderPlaced(:final orderId):
              _addEvent('✅ أُرسل الطلب: $orderId');
              bubble = null;
          }
        });
      }
    } on AiAssistantException catch (e) {
      setState(() => _addEvent('⚠ خطأ للعميل: ${e.message}'));
    }
    if (bubble != null) debugPrint('المساعد: ${bubble!.text}');
    setState(() => _busy = false);
  }

  String _locationText(OrderSummary s) {
    final pickup = s.pickupLocation == null ? '❌ غير محدد' : '✔ محدد';
    final dropoff = !s.needsDropoff
        ? ''
        : '\nموقع التوصيل: ${s.dropoffLocation == null ? '❌ غير محدد' : '✔ محدد'}';
    return 'موقع المركبة: $pickup$dropoff';
  }

  /// Stands in for the card's map button (LocationPickerPage).
  void _pickDemoDropoff() {
    final id = _lastSummaryId;
    final updated = id == null
        ? null
        : _assistant.updateSummaryLocation(
            id,
            dropoff: const GeoPoint(24.7743, 46.7386),
          );
    setState(() => _addEvent(updated == null
        ? 'لا يوجد ملخص ينتظر التأكيد'
        : '📍 حُدد موقع التوصيل للملخص ${updated.id}\n${_locationText(updated)}'));
  }

  void _addEvent(String text) {
    debugPrint(text);
    _lines.add(_Line(text, isEvent: true));
  }

  Future<void> _sendTestImage() async {
    try {
      final data = await rootBundle.load('assets/dev/test_car.jpg');
      await _send('وش المشكلة في الصورة؟', image: data.buffer.asUint8List());
    } catch (e) {
      setState(() => _addEvent('أضف صورة في assets/dev/test_car.jpg أولًا'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _assistant.activeVehicle;
    return Scaffold(
      appBar: AppBar(
        title: Text(active == null ? 'فحص عقل الـAI' : 'المركبة: ${active.title}'),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            icon: const Icon(Icons.refresh),
            onPressed: _busy
                ? null
                : () => setState(() {
                      _assistant.reset();
                      _lines.clear();
                      _lastSummaryId = null;
                    }),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                for (final m in _quickMessages)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(m),
                      onPressed: _busy ? null : () => _send(m),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.place_outlined, size: 18),
                    label: const Text('موقع توصيل تجريبي'),
                    onPressed: _busy ? null : _pickDemoDropoff,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('صورة تجريبية'),
                    onPressed: _busy ? null : _sendTestImage,
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                return Align(
                  alignment: line.isCustomer
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: line.isCustomer
                          ? const Color(0xFFE3ECFB)
                          : line.isEvent
                              ? const Color(0xFFFFF4D6)
                              : const Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(line.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _busy ? null : () => _send(_input.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
