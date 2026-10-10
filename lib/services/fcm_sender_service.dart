// =============================================================================
// FILE: lib/services/fcm_sender_service.dart
// Client-side Direct FCM Push Notification Dispatcher (100% Free Firebase Spark Plan)
// Dispatches FCM messages via Google's FCM v1 HTTP API using a Service Account Key.
// Delivers notifications to devices even when the app is closed or killed.
// =============================================================================

import 'fcm_sender_stub.dart'
    if (dart.library.html) 'fcm_sender_web.dart';

class FcmSenderService {
  /// Sends a cloud push notification to all devices subscribed to an FCM topic
  static Future<bool> sendPushToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) =>
      FcmSenderServiceImpl.sendPushToTopic(
        topic: topic,
        title: title,
        body: body,
        data: data,
      );

  /// Sends a cloud push notification directly to specific recipient FCM device tokens
  static Future<bool> sendPushToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) =>
      FcmSenderServiceImpl.sendPushToTokens(
        tokens: tokens,
        title: title,
        body: body,
        data: data,
      );
}
