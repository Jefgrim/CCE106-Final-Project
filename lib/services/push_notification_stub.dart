// =============================================================================
// FILE: lib/services/push_notification_stub.dart
// Mobile & native platform push notification service using Firebase Cloud Messaging
// (FCM) combined with flutter_local_notifications for foreground & background display.
// Requests runtime permissions (Android 13+ POST_NOTIFICATIONS, iOS Darwin),
// sets up native notification channels, and displays native alerts.
// Supports background and terminated push notification delivery.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'fcm_sender_service.dart';

const String _kNotificationChannelId = 'capsync_alerts';
const String _kNotificationChannelName = 'CapSync Academic Alerts';
const String _kNotificationChannelDesc =
    'Notifications for consultation bookings, adviser notes, and status updates.';

/// Top-level background message handler required by FirebaseMessaging.
/// Runs in a background isolate when a notification arrives while the app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint("CapSync FCM Background message received: ${message.messageId}");

    // If message is data-only (no system notification payload), display it manually
    // so it shows in the Android notification shade even when the app is killed.
    if (message.notification == null && message.data.isNotEmpty) {
      final title = message.data['title']?.toString() ?? 'CapSync Alert';
      final body = message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          'You have a consultation update.';

      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          _kNotificationChannelId,
          _kNotificationChannelName,
          description: _kNotificationChannelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }

      const androidDetails = AndroidNotificationDetails(
        _kNotificationChannelId,
        _kNotificationChannelName,
        channelDescription: _kNotificationChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final id = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).remainder(100000);
      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
    }
  } catch (e) {
    debugPrint("CapSync FCM Background handler notice: $e");
  }
}

class PushNotificationServiceImpl {
  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _isInitialized = false;
  static bool _isGranted = false;
  static void Function(String token)? _onTokenRefreshCallback;

  static FlutterLocalNotificationsPlugin? _getPlugin() {
    try {
      return _plugin ??= FlutterLocalNotificationsPlugin();
    } catch (_) {
      return null;
    }
  }

  /// Full push notification initialization called during app startup.
  static Future<void> initialize({void Function(String token)? onTokenRefresh}) async {
    _onTokenRefreshCallback = onTokenRefresh;
    await _ensureInitialized();
  }

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    final plugin = _getPlugin();
    if (plugin == null) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await plugin.initialize(settings: initSettings);

      // Create Android Notification Channel with maximum importance
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          _kNotificationChannelId,
          _kNotificationChannelName,
          description: _kNotificationChannelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidPlugin.createNotificationChannel(channel);

        // Check if notification permission is already active on Android
        try {
          final enabled = await androidPlugin.areNotificationsEnabled();
          if (enabled != null) {
            _isGranted = enabled;
          }
        } catch (_) {}
      }

      // Configure foreground presentation options for FCM
      try {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Register background message handler
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Listen for incoming messages while the app is in foreground
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint("CapSync FCM foreground message: ${message.notification?.title ?? message.data['title']}");
          final title = message.notification?.title ?? message.data['title'] ?? 'CapSync Alert';
          final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';
          showNotification(
            title: title,
            body: body,
          );
        });

        // Listen for user tapping a notification when the app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint("CapSync FCM opened app from notification: ${message.messageId}");
        });

        // Check if the app was launched by tapping a notification while terminated
        FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
          if (message != null) {
            debugPrint("CapSync FCM app launched from terminated notification: ${message.messageId}");
          }
        });

        // Listen for FCM registration token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
          debugPrint("CapSync FCM token refreshed: $newToken");
          _onTokenRefreshCallback?.call(newToken);
        });
      } catch (e) {
        debugPrint("FCM initialization setup notice: $e");
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint("PushNotificationService initialization notice: $e");
    }
  }

  static Future<bool> requestPermission() async {
    await _ensureInitialized();

    try {
      // 1. Firebase Messaging runtime permission
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          _isGranted = true;
        }
      } catch (e) {
        debugPrint("FCM requestPermission notice: $e");
      }

      // 2. Android 13+ (API level 33+) local notification permission
      final plugin = _getPlugin();
      if (plugin != null) {
        final androidPlugin = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted =
              await androidPlugin.requestNotificationsPermission();
          if (granted != null) {
            _isGranted = granted;
            return _isGranted;
          }
        }

        // 3. iOS Darwin permission
        final iosPlugin = plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          if (granted != null) {
            _isGranted = granted;
            return _isGranted;
          }
        }
      }

      _isGranted = true;
      return true;
    } catch (e) {
      debugPrint("PushNotificationService requestPermission notice: $e");
      _isGranted = false;
      return false;
    }
  }

  /// Retrieves the unique FCM Device Registration Token.
  static Future<String?> getDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint("CapSync FCM Device Token: $token");
      }
      return token;
    } catch (e) {
      debugPrint("Could not retrieve FCM token: $e");
      return null;
    }
  }

  /// Subscribes this device to an FCM topic for group or role-based broadcasts.
  static Future<void> subscribeToTopic(String topic) async {
    try {
      final cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.subscribeToTopic(cleanTopic);
      debugPrint("Subscribed to FCM topic: $cleanTopic");
    } catch (e) {
      debugPrint("FCM subscribeToTopic notice ($topic): $e");
    }
  }

  static void showNotification({
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    final plugin = _getPlugin();
    if (plugin == null) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _kNotificationChannelId,
        _kNotificationChannelName,
        channelDescription: _kNotificationChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint("PushNotificationService showNotification notice: $e");
    }
  }

  static Future<void> initializeBackgroundHandler() async {
    await _ensureInitialized();
  }

  /// Schedules a test push notification delivered in [delaySeconds] directly to this device
  /// via Google FCM v1. Allows the user to close / terminate the app and observe the notification!
  static Future<bool> testBackgroundPushNotification({int delaySeconds = 5}) async {
    final token = await getDeviceToken();
    if (token == null || token.isEmpty) {
      debugPrint("testBackgroundPushNotification: No device token available.");
      return false;
    }

    // Delay asynchronously so the user has time to close the app
    Future.delayed(Duration(seconds: delaySeconds), () async {
      try {
        await FcmSenderService.sendPushToTokens(
          tokens: [token],
          title: "CapSync Background Test",
          body: "Success! Push notification received while app was closed ($delaySeconds s delayed).",
          data: {
            'type': 'testNotification',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        debugPrint("testBackgroundPushNotification dispatch notice: $e");
      }
    });

    return true;
  }

  static bool get isSupported => true;
  static bool get isGranted => _isGranted;
}
