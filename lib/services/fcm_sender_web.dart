// =============================================================================
// FILE: lib/services/fcm_sender_web.dart
// Web platform stub for direct FCM sending
// =============================================================================

class FcmSenderServiceImpl {
  static Future<bool> sendPushToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    return false;
  }

  static Future<bool> sendPushToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    return false;
  }
}
