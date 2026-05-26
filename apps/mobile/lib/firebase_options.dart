// Generated/maintained manually.
// Android values come from google-services.json.
// Web values: Firebase Console → Project Settings → Your apps → Web app.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // ── Web ──────────────────────────────────────────────────────────────────
  // Paste values from Firebase Console → Project Settings → Your apps → Web.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCe9Wx9PYyLSlQlnUa5m-QRy5FjxFFLqlY',
    appId: '1:1076533368678:web:97e41c808c9f10648fdaa7',
    messagingSenderId: '1076533368678',
    projectId: 'mitaleet-fb8ce',
    authDomain: 'mitaleet-fb8ce.firebaseapp.com',
    storageBucket: 'mitaleet-fb8ce.firebasestorage.app',
  );

  // ── Android ──────────────────────────────────────────────────────────────
  // Values from android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBrhzG4I972Apgk7mhbF9yGvMYQswe0bdM',
    appId: '1:1076533368678:android:d686564c68a0f8558fdaa7',
    messagingSenderId: '1076533368678',
    projectId: 'mitaleet-fb8ce',
    storageBucket: 'mitaleet-fb8ce.firebasestorage.app',
  );
}
