import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

// Flutter's browser unit-test runner does not generate the app registrant.
void registerFirebaseWebPlugins() {
  FirebaseCoreWeb.registerWith(webPluginRegistrar);
  FirebaseAuthWeb.registerWith(webPluginRegistrar);
  FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
}
