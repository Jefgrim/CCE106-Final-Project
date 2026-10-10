// =============================================================================
// FILE: lib/services/push_notification_web.dart
// Web platform implementation using modern Dart 3 JS Interop for Notifications.
// =============================================================================

import 'dart:js_interop';

@JS('Notification')
extension type Notification._(JSObject _) implements JSObject {
  external factory Notification(String title, [NotificationOptions options]);
  external static JSPromise<JSString> requestPermission();
  external static String get permission;
}

extension type NotificationOptions._(JSObject _) implements JSObject {
  external factory NotificationOptions({String body, String icon});
}

class PushNotificationServiceImpl {
  static Future<bool> requestPermission() async {
    try {
      final result = await Notification.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void showNotification({required String title, required String body}) {
    try {
      if (isGranted) {
        Notification(title, NotificationOptions(body: body, icon: 'favicon.png'));
      }
    } catch (_) {}
  }

  static bool get isSupported {
    try {
      return Notification.permission.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool get isGranted {
    try {
      return Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getDeviceToken() async => null;
  static Future<void> subscribeToTopic(String topic) async {}
  static Future<void> initializeBackgroundHandler() async {}
  static Future<void> initialize({void Function(String token)? onTokenRefresh}) async {}
  static Future<bool> testBackgroundPushNotification({int delaySeconds = 5}) async => false;
}
