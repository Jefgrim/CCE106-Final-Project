// =============================================================================
// FILE: lib/services/database/firebase_config.dart
// FIREBASE CLOUD FIRESTORE CONFIGURATION & SETUP GUIDE
// =============================================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration constants and instructions for connecting to Google Firebase.
///
/// Credentials are read securely from environment variables (.env file).
/// In Firebase Console (https://console.firebase.google.com/):
/// 1. Create a Firebase project named "CapSync-UM".
/// 2. Enable Cloud Firestore Database (in test or production mode).
/// 3. Enable Authentication -> Sign-in method -> Email/Password.
/// 4. Add your credentials to the project root `.env` file (see `.env.example`).
/// 5. Collections used by CapSync:
///    - 'users'                  : Stores student, faculty, and coordinator documents
///    - 'time_slots'             : Stores consultation availability slots
///    - 'consultation_bookings'  : Stores RSVP bookings and statuses
///    - 'capstone_groups'        : Stores group assignments and adviser/panel pairings
///    - 'notifications'          : Stores in-app alerts and announcements
class FirebaseConfig {
  static const String usersCollection = 'users';
  static const String timeSlotsCollection = 'time_slots';
  static const String bookingsCollection = 'consultation_bookings';
  static const String groupsCollection = 'capstone_groups';
  static const String notificationsCollection = 'notifications';

  /// Helper to safely resolve environment values from .env with fallback to compile-time definitions.
  static String _getEnv(String key, {String defaultValue = ''}) {
    if (dotenv.isInitialized) {
      final value = dotenv.env[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return defaultValue;
  }

  /// Firebase Web / Android / Desktop Project Credentials
  /// Loaded dynamically from environment variables (.env file or --dart-define).
  static String get apiKey => _getEnv(
        'FIREBASE_API_KEY',
        defaultValue: const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
      );

  static String get androidApiKey {
    final specific = _getEnv('FIREBASE_ANDROID_API_KEY');
    if (specific.isNotEmpty) return specific;
    final general = apiKey;
    if (general.isNotEmpty) return general;
    return const String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'AIzaSyBT_agnDiPAd3J7qRLu-UHcjDt8vPO3snU',
    );
  }

  static String get appId => _getEnv(
        'FIREBASE_APP_ID',
        defaultValue: const String.fromEnvironment(
          'FIREBASE_APP_ID',
          defaultValue: '1:108120561521:web:faa3c61a2b55a128f4c8d0',
        ),
      );

  static String get androidAppId {
    final specific = _getEnv('FIREBASE_ANDROID_APP_ID');
    if (specific.isNotEmpty) return specific;
    return const String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '1:108120561521:android:e3de1e990a6bfd0ef4c8d0',
    );
  }

  static String get messagingSenderId => _getEnv(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
          defaultValue: '108120561521',
        ),
      );

  static String get storageBucket => _getEnv(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
          defaultValue: 'capsync-813b5.firebasestorage.app',
        ),
      );

  static String get projectId => _getEnv(
        'FIREBASE_PROJECT_ID',
        defaultValue: const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'capsync-813b5'),
      );

  static String get authDomain => _getEnv(
        'FIREBASE_AUTH_DOMAIN',
        defaultValue: const String.fromEnvironment(
          'FIREBASE_AUTH_DOMAIN',
          defaultValue: 'capsync-813b5.firebaseapp.com',
        ),
      );

  static String get databaseUrl => _getEnv(
        'FIREBASE_DATABASE_URL',
        defaultValue: const String.fromEnvironment(
          'FIREBASE_DATABASE_URL',
          defaultValue: 'https://capsync-813b5-default-rtdb.asia-southeast1.firebasedatabase.app',
        ),
      );
}
