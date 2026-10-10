// =============================================================================
// FILE: lib/models/app_notification.dart
// Notification model with database serialization.
// =============================================================================

import 'package:intl/intl.dart';

enum NotificationType {
  bookingRequested,
  bookingConfirmed,
  bookingCancelled,
  slotAdded,
  noteAdded,
}

class AppNotification {
  final String id;
  final String recipientUserId;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool _isRead;

  AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.message,
    DateTime? timestamp,
    this.type = NotificationType.bookingConfirmed,
    bool isRead = false,
  })  : timestamp = timestamp ?? DateTime.now(),
        _isRead = isRead;

  bool get isRead => _isRead;
  String get formattedTime => DateFormat('h:mm a • MMM d').format(timestamp);

  void markAsRead() {
    _isRead = true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipientUserId': recipientUserId,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'isRead': _isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      recipientUserId: json['recipientUserId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.bookingConfirmed,
      ),
      isRead: json['isRead'] ?? false,
    );
  }
}
