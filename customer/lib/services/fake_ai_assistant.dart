import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;

import '../models/service_catalog.dart';
import '../models/vehicle.dart';
import 'ai_assistant.dart';

/// A stand-in that answers without the internet, for building and testing the
/// chat screen (piece 2) and the cards (piece 4). It streams word by word like
/// the real one and plays one full order flow:
///
/// - a message about the battery → reply + summary card
/// - "جمس" / "GMC" → switches to the second vehicle
/// - "نعم" / "أكد" while a card is waiting → order placed
/// - set [shouldFail] to test the error message
class FakeAiAssistant implements AiAssistant {
  FakeAiAssistant({
    List<Vehicle>? vehicles,
    this.wordDelay = const Duration(milliseconds: 60),
    this.shouldFail = false,
  }) : _vehicles = vehicles ?? sampleVehicles {
    _active = _vehicles.isEmpty ? null : _vehicles.first;
  }

  static const sampleVehicles = [
    Vehicle(
      id: 'fake-camry',
      brand: 'تويوتا',
      model: 'كامري',
      year: 2022,
      color: 'أبيض',
      plateNumberArabic: '1234 ابد',
      plateNumberLatin: '1234 ABD',
    ),
    Vehicle(
      id: 'fake-yukon',
      brand: 'جي إم سي',
      model: 'يوكن',
      year: 2019,
      color: 'أسود',
      plateNumberArabic: '9821 كرس',
      plateNumberLatin: '9821 KRS',
    ),
  ];

  final List<Vehicle> _vehicles;
  final Duration wordDelay;
  bool shouldFail;

  Vehicle? _active;
  OrderSummary? _pending;
  int _summaryCount = 0;
  int messagesSent = 0;

  @override
  List<Vehicle> get vehicles => _vehicles;

  @override
  Vehicle? get activeVehicle => _active;

  /// A fixed point in Riyadh, standing in for GPS.
  static const samplePickup = GeoPoint(24.7136, 46.6753);

  @override
  OrderSummary? updateSummaryLocation(
    String summaryId, {
    GeoPoint? pickup,
    GeoPoint? dropoff,
  }) {
    final pending = _pending;
    if (pending == null || pending.id != summaryId) return null;
    return _pending = pending.copyWithLocations(pickup: pickup, dropoff: dropoff);
  }

  @override
  void reset() {
    _active = _vehicles.isEmpty ? null : _vehicles.first;
    _pending = null;
    messagesSent = 0;
  }

  @override
  Stream<AiEvent> send(
    String text, {
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async* {
    messagesSent++;
    if (shouldFail) {
      throw const AiAssistantException(
        'تعذّر الوصول للمساعد. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
      );
    }

    // Switch car.
    if ((text.contains('جمس') || text.toUpperCase().contains('GMC')) &&
        _vehicles.length > 1) {
      _active = _vehicles[1];
      yield AiVehicleChanged(_active!);
      final old = _pending;
      if (old != null) {
        _pending = null;
        yield AiOrderSummaryCancelled(old.id);
      }
      yield* _words('تمام، غيّرت المركبة إلى ${_active!.title}. وش المشكلة فيها؟');
      return;
    }

    // Confirm.
    final pending = _pending;
    if (pending != null &&
        (text.contains('نعم') || text.contains('أكد') || text.contains('تمام'))) {
      _pending = null;
      yield AiOrderPlaced(orderId: 'FAKE-ORDER-1', summary: pending);
      yield* _words('تم إرسال طلبك، وسيصلك إشعار عندما يقبله مقدم الخدمة.');
      return;
    }

    // Battery problem → summary.
    if (_active != null &&
        (text.contains('بطارية') || text.contains('ما تشتغل'))) {
      yield* _words('غالبًا البطارية فاضية.\n'
          '1. تأكد أن الأنوار الداخلية ضعيفة أو لا تضيء.\n'
          '2. لا تحاول التشغيل مرات كثيرة متتالية.\n');
      final category = ServiceCatalog.categoryById('battery')!;
      final option = ServiceCatalog.optionById('battery', 'activation')!;
      final summary = OrderSummary(
        id: 'S${++_summaryCount}',
        vehicle: _active!,
        categoryId: category.id,
        categoryLabel: category.label,
        optionId: option.id,
        optionLabel: option.label,
        note: 'السيارة لا تشتغل والأنوار ضعيفة.',
        estimatedPrice: 70,
        needsDropoff: false,
        pickupLocation: samplePickup,
      );
      final old = _pending;
      if (old != null) yield AiOrderSummaryCancelled(old.id);
      _pending = summary;
      yield AiOrderSummaryShown(summary);
      yield* _words('هل تؤكد الطلب؟');
      return;
    }

    if (imageBytes != null) {
      yield* _words('يبدو في الصورة أن الإطار الأمامي فارغ من الهواء. '
          'هل لديك إطار احتياطي؟');
      return;
    }

    yield* _words('وش المشكلة اللي تواجهك مع السيارة؟ تقدر ترسل صورة أيضًا.');
  }

  Stream<AiEvent> _words(String text) async* {
    for (final word in text.split(' ')) {
      await Future.delayed(wordDelay);
      yield AiTextDelta('$word ');
    }
  }
}
