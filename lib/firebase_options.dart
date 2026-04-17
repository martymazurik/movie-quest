// Firebase configuration options.
//
// For best results, regenerate this file with:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=moviequestapp
//
// The Android options below are filled from android/app/google-services.json.
// The web options require the Web App's API key from the Firebase Console
// (Project settings → General → Your apps → Web app → SDK setup).
// Replace the TODO_WEB_* placeholders before running on the web.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPXCTPydf7KX9oi67jiYpdPxqzaUYDAc0',
    appId: '1:485865986449:android:c890cb53e57ee037e72230',
    messagingSenderId: '485865986449',
    projectId: 'moviequestapp',
    storageBucket: 'moviequestapp.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZIz5yIDSv_LMqkx-jn7N0rD4wVnRvBkY',
    appId: '1:485865986449:web:012efd4170a65c7ae72230',
    messagingSenderId: '485865986449',
    projectId: 'moviequestapp',
    authDomain: 'moviequestapp.firebaseapp.com',
    storageBucket: 'moviequestapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO_IOS_API_KEY',
    appId: '1:485865986449:ios:dab0ebcb9a2a0ac4e72230',
    messagingSenderId: '485865986449',
    projectId: 'moviequestapp',
    storageBucket: 'moviequestapp.firebasestorage.app',
    iosBundleId: 'com.example.moviequestapp',
  );
}
