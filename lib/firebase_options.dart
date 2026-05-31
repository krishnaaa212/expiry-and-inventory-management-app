import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web; // ✅ Windows desktop uses web config
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS config not added yet.');
      default:
        throw UnsupportedError('This platform is not supported.');
    }
  }

  // ✅ Android config — from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBsZmgf6y90mUDN9vYBz0vmIrUG7pCJ2l0',
    appId: '1:351080652075:android:dee18d3243e80361a1f96e',
    messagingSenderId: '351080652075',
    projectId: 'expiry-and-inventory-mngmnt',
    storageBucket: 'expiry-and-inventory-mngmnt.firebasestorage.app',
  );

  // ✅ Web config — from Firebase Console → Web App
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDsfqMSlkYoJGBHozgrv0VHK2_VDR4EpUI',
    appId: '1:351080652075:web:3c660186808077d3a1f96e',
    messagingSenderId: '351080652075',
    projectId: 'expiry-and-inventory-mngmnt',
    storageBucket: 'expiry-and-inventory-mngmnt.firebasestorage.app',
    authDomain: 'expiry-and-inventory-mngmnt.firebaseapp.com',
    measurementId: 'G-ZBE7GFRDRK',
  );
}