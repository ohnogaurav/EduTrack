// File generated/configured for Web Demo.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for iOS in this configuration. Please run flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDMu5V6Ty3R9Xz3RwyRH-IkN3aqSn4dHwg',
    appId: '1:935135778212:web:d8753a812df08e92f61d31', // Placeholder: Update this with your Firebase Web App ID if needed
    messagingSenderId: '935135778212',
    projectId: 'edtrack-3b605',
    authDomain: 'edtrack-3b605.firebaseapp.com',
    storageBucket: 'edtrack-3b605.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDMu5V6Ty3R9Xz3RwyRH-IkN3aqSn4dHwg',
    appId: '1:935135778212:android:0c186380c01e9c93f61d31',
    messagingSenderId: '935135778212',
    projectId: 'edtrack-3b605',
    storageBucket: 'edtrack-3b605.firebasestorage.app',
  );
}
