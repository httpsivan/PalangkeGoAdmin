import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// PLACEHOLDER — replace by running `flutterfire configure` in this project.
/// In demo mode (`flutter run` without FIREBASE_ENABLED) this file is never
/// used. In Firebase mode with placeholders still present, startup fails
/// closed with a clear message instead of silently misbehaving.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC8bEf_eTNv9lIWwk3MOk0PZ8f5_SKNkUo',
    appId: '1:817586589237:web:81b342a0df17aa55132b7c',
    messagingSenderId: '817586589237',
    projectId: 'palengkegodb',
    authDomain: 'palengkegodb.firebaseapp.com',
    storageBucket: 'palengkegodb.firebasestorage.app',
    measurementId: 'G-S0CDKZQPD6',
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: 'placeholder',
    messagingSenderId: 'placeholder',
    projectId: 'placeholder',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: 'placeholder',
    messagingSenderId: 'placeholder',
    projectId: 'placeholder',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: 'placeholder',
    messagingSenderId: 'placeholder',
    projectId: 'placeholder',
  );

  static bool get isPlaceholder =>
      web.apiKey == 'placeholder-run-flutterfire-configure';
}
