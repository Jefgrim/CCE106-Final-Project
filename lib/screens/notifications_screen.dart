// =============================================================================
// FILE: lib/screens/notifications_screen.dart
// Push Notification Center
// Displays real-time alerts when students book, advisers add notes, or slots cancel.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../services/push_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final AppState appState;

  const NotificationsScreen({super.key, required this.appState});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequested:
        return Icons.event_note_rounded;
      case NotificationType.bookingConfirmed:
        return Icons.check_circle_rounded;
      case NotificationType.bookingCancelled:
        return Icons.cancel_rounded;
      case NotificationType.slotAdded:
        return Icons.add_alarm_rounded;
      case NotificationType.noteAdded:
        return Icons.comment_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequested:
        return AppColors.royalBlue;
      case NotificationType.bookingConfirmed:
        return AppColors.primaryBlue;
      case NotificationType.bookingCancelled:
        return AppColors.error;
      case NotificationType.slotAdded:
        return AppColors.skyBlue;
      case NotificationType.noteAdded:
        return AppColors.royalBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = widget.appState.userNotifications;
    final showPushBanner = PushNotificationService.isSupported && !PushNotificationService.isGranted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile_rounded, color: Colors.white, size: 22),
            tooltip: 'Test Closed-App Push',
            onPressed: () => _showTestPushDialog(context),
          ),
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                widget.appState.markAllNotificationsAsRead();
              },
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: AppColors.skyBlue, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (showPushBanner)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.primaryNavy, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enable Push Notifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Get instant push alerts on your device when advisers add notes or consultations are scheduled.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final granted = await PushNotificationService.requestPermission();
                      if (!mounted) return;
                      setState(() {});
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            granted
                                ? 'Push Notifications enabled! You will receive instant mobile alerts.'
                                : 'Notification permission was denied or dismissed.',
                          ),
                          backgroundColor: granted ? AppColors.success : AppColors.error,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryNavy,
              onRefresh: () async {
                await widget.appState.refreshData();
              },
              child: notifications.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Notifications Yet',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Real-time push notifications will trigger alerts here when consultations update. Swipe down to refresh.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      final iconColor = _getColorForType(notif.type);

                      return Container(
                        color: notif.isRead ? Colors.white : AppColors.lightBlue.withValues(alpha: 0.5),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withValues(alpha: 0.15),
                                child: Icon(_getIconForType(notif.type), color: iconColor, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    notif.formattedTime,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  notif.message,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                ),
                              ),
                              onTap: () {
                                widget.appState.markNotificationAsRead(notif.id);
                              },
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestPushDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send_to_mobile_rounded, color: AppColors.primaryNavy),
            SizedBox(width: 8),
            Text('Test Closed-App Push', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test that push notifications work even when CapSync is closed or minimized.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              '1. Tap "Start 5s Countdown" below.\n'
              '2. Immediately press Home or swipe CapSync away to close the app.\n'
              '3. Lock your screen.\n'
              '4. In 5 seconds, Google FCM will wake your phone and deliver the notification!',
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);

              if (!PushNotificationService.isGranted) {
                final granted = await PushNotificationService.requestPermission();
                if (!granted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please allow notification permission in your phone settings to receive alerts.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
              }

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('5-Second Timer Started! Close the app or lock your phone right now to test...'),
                  backgroundColor: AppColors.primaryNavy,
                  duration: Duration(seconds: 4),
                ),
              );

              final success = await PushNotificationService.testBackgroundPushNotification(delaySeconds: 5);
              if (!success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not retrieve device token. Make sure Google Play Services is available.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start 5s Countdown'),
          ),
        ],
      ),
    );
  }
}
