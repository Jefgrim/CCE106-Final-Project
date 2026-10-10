// =============================================================================
// FILE: lib/firebase_options.dart
// Default FirebaseOptions for use with Firebase.initializeApp
// Generated and configured to load credentials dynamically from .env
// =============================================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'services/database/firebase_config.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Rather than hardcoding sensitive credentials in source code,
/// all options are loaded dynamically from environment variables (.env)
/// via [FirebaseConfig].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.appId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        authDomain: FirebaseConfig.authDomain,
        databaseURL: FirebaseConfig.databaseUrl,
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: FirebaseConfig.androidApiKey,
        appId: FirebaseConfig.androidAppId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.appId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        iosBundleId: 'com.capsync.um',
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.appId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        authDomain: FirebaseConfig.authDomain,
      );
}
