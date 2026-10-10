// =============================================================================
// FILE: lib/services/fcm_sender_stub.dart
// Native platform direct FCM push sender using Google Service Account & OAuth 2.0.
// Works 100% on the Free Firebase Spark Plan without Cloud Functions.
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'database/firebase_config.dart';

class FcmSenderServiceImpl {
  static AccessToken? _cachedToken;
  static DateTime? _tokenExpiry;

  /// Loads service account JSON from assets/service-account.json or .env
  static Future<Map<String, dynamic>?> _getServiceAccountCredentials() async {
    // 1. Try loading from assets/service-account.json
    try {
      final jsonStr = await rootBundle.loadString('assets/service-account.json');
      if (jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final privateKey = map['private_key']?.toString() ?? '';
        if (privateKey.contains('BEGIN PRIVATE KEY') &&
            !privateKey.contains('YOUR_PRIVATE_KEY_HERE')) {
          return map;
        }
      }
    } catch (_) {}

    // 2. Try loading from .env
    if (dotenv.isInitialized) {
      final envJson = dotenv.env['FIREBASE_SERVICE_ACCOUNT_JSON'];
      if (envJson != null && envJson.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(envJson.trim()) as Map<String, dynamic>;
          final privateKey = decoded['private_key']?.toString() ?? '';
          if (privateKey.contains('BEGIN PRIVATE KEY') &&
              !privateKey.contains('YOUR_PRIVATE_KEY_HERE')) {
            return decoded;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Obtains a valid OAuth 2.0 access token using googleapis_auth
  static Future<String?> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!.data;
    }

    final serviceAccount = await _getServiceAccountCredentials();
    if (serviceAccount == null) {
      debugPrint("FcmSenderService: Service account key not configured yet. Place service-account.json in assets/ to activate direct cloud push.");
      return null;
    }

    try {
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(credentials, scopes);
      _cachedToken = client.credentials.accessToken;
      _tokenExpiry =
          client.credentials.accessToken.expiry.subtract(const Duration(minutes: 5));
      client.close();
      return _cachedToken?.data;
    } catch (e) {
      debugPrint("FcmSenderService error obtaining OAuth2 token: $e");
      return null;
    }
  }

  /// Sends a push notification to an FCM topic
  static Future<bool> sendPushToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return false;

    final cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
    final projectId = FirebaseConfig.projectId;
    final url =
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    // Merge title/body into data payload so background isolates can access them reliably
    final stringData = <String, String>{
      'title': title,
      'body': body,
      'channel_id': 'capsync_alerts',
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      if (data != null)
        ...data.map((k, v) => MapEntry(k.toString(), v.toString())),
    };

    final payload = {
      'message': {
        'topic': cleanTopic,
        'notification': {
          'title': title,
          'body': body,
        },
        'android': {
          'priority': 'HIGH',
          'notification': {
            'channel_id': 'capsync_alerts',
            'sound': 'default',
            'notification_priority': 'PRIORITY_MAX',
            'default_vibrate_timings': true,
            'default_sound': true,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        'data': stringData,
        'apns': {
          'payload': {
            'aps': {
              'alert': {
                'title': title,
                'body': body,
              },
              'sound': 'default',
              'badge': 1,
              'content-available': 1,
            },
          },
        },
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint("FcmSenderService: Successfully sent push to topic '$cleanTopic'.");
        return true;
      } else {
        debugPrint(
            "FcmSenderService: FCM API error (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("FcmSenderService network error: $e");
      return false;
    }
  }

  /// Sends a push notification directly to specific device registration token(s)
  static Future<bool> sendPushToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final validTokens = tokens.where((t) => t.trim().isNotEmpty).toSet().toList();
    if (validTokens.isEmpty) return false;
    final token = await _getAccessToken();
    if (token == null) return false;

    final projectId = FirebaseConfig.projectId;
    final url =
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    // Merge title/body into data payload so background isolates can access them reliably
    final stringData = <String, String>{
      'title': title,
      'body': body,
      'channel_id': 'capsync_alerts',
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      if (data != null)
        ...data.map((k, v) => MapEntry(k.toString(), v.toString())),
    };

    bool allSuccess = true;
    for (final deviceToken in validTokens) {
      final payload = {
        'message': {
          'token': deviceToken.trim(),
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'priority': 'HIGH',
            'notification': {
              'channel_id': 'capsync_alerts',
              'sound': 'default',
              'notification_priority': 'PRIORITY_MAX',
              'default_vibrate_timings': true,
              'default_sound': true,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          'data': stringData,
          'apns': {
            'payload': {
              'aps': {
                'alert': {
                  'title': title,
                  'body': body,
                },
                'sound': 'default',
                'badge': 1,
                'content-available': 1,
              },
            },
          },
        },
      };

      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          debugPrint(
              "FcmSenderService: Successfully sent push to token (${deviceToken.substring(0, deviceToken.length > 10 ? 10 : deviceToken.length)}...).");
        } else {
          debugPrint(
              "FcmSenderService error for token ($deviceToken): ${response.body}");
          allSuccess = false;
        }
      } catch (e) {
        debugPrint("FcmSenderService token dispatch error: $e");
        allSuccess = false;
      }
    }

    return allSuccess;
  }
}
