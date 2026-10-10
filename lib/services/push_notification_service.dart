// =============================================================================
// FILE: lib/services/push_notification_service.dart
// Unified Push Notification interface supporting HTML5 Web Push Notifications
// with graceful fallback on non-web / testing environments.
// =============================================================================

import 'push_notification_stub.dart'
    if (dart.library.html) 'push_notification_web.dart';

class PushNotificationService {
  /// Prompts the user / device to allow native system push notifications
  static Future<bool> requestPermission() =>
      PushNotificationServiceImpl.requestPermission();

  /// Triggers a system push notification alert if permissions are granted
  static void showNotification({required String title, required String body}) =>
      PushNotificationServiceImpl.showNotification(title: title, body: body);

  /// Retrieves the unique FCM Device Registration Token (for Cloud Push Notifications)
  static Future<String?> getDeviceToken() =>
      PushNotificationServiceImpl.getDeviceToken();

  /// Subscribes this device to an FCM topic
  static Future<void> subscribeToTopic(String topic) =>
      PushNotificationServiceImpl.subscribeToTopic(topic);

  /// Whether push notifications are supported on the current platform
  static bool get isSupported => PushNotificationServiceImpl.isSupported;

  /// Whether push notification permissions are already granted
  static bool get isGranted => PushNotificationServiceImpl.isGranted;

  /// Registers background message handler and initializes native notification channels
  static Future<void> initialize({void Function(String token)? onTokenRefresh}) =>
      PushNotificationServiceImpl.initialize(onTokenRefresh: onTokenRefresh);

  /// Backwards-compatible background handler initializer
  static Future<void> initializeBackgroundHandler() =>
      PushNotificationServiceImpl.initializeBackgroundHandler();

  /// Tests delayed background cloud push notification to verify delivery when app is closed
  static Future<bool> testBackgroundPushNotification({int delaySeconds = 5}) =>
      PushNotificationServiceImpl.testBackgroundPushNotification(delaySeconds: delaySeconds);
}
