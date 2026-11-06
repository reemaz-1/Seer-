import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushOrderOpen {
  const PushOrderOpen({required this.orderId, required this.recipientId});
  final String orderId;
  final String recipientId;
  static PushOrderOpen? fromData(Map<String, dynamic> data) {
    final order = data['orderId'];
    final recipient = data['recipientId'];
    if (data['type'] != 'orderStatusChanged' ||
        order is! String ||
        order.isEmpty ||
        recipient is! String ||
        recipient.isEmpty) {
      return null;
    }
    return PushOrderOpen(orderId: order, recipientId: recipient);
  }
}

abstract class CustomerPushGateway {
  bool get supported;
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get tokenRefresh;
  Stream<PushOrderOpen> get opened;
  Future<PushOrderOpen?> initialOpen();
  Future<void> register(String token, String uid, {String? previousToken});
  Future<void> deleteToken();
}

/// Android is the only native platform configured by this repository.
/// Registration goes through an authenticated callable, never an open token
/// document or a topic that another user could subscribe to.
class FirebaseCustomerPushGateway implements CustomerPushGateway {
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  @override
  Future<bool> requestPermission() async {
    final permission = await _messaging.requestPermission();
    return permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();
  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;
  @override
  Stream<PushOrderOpen> get opened => FirebaseMessaging.onMessageOpenedApp
      .map((message) => PushOrderOpen.fromData(message.data))
      .where((message) => message != null)
      .cast<PushOrderOpen>();
  @override
  Future<PushOrderOpen?> initialOpen() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushOrderOpen.fromData(message.data);
  }

  @override
  Future<void> register(
    String token,
    String uid, {
    String? previousToken,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Push account changed');
    }
    final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'registerCustomerPushToken',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<Map<String, dynamic>>({
          'token': token,
          'platform': 'android',
          'previousToken': ?previousToken,
        });
    if (result.data['uid'] != uid) throw StateError('Push account changed');
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
