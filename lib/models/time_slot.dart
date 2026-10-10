// =============================================================================
// FILE: lib/models/time_slot.dart
// OOP PRINCIPLE DEMONSTRATED: ENCAPSULATION
// The internal state (_isBooked, _bookedByGroupId, _bookingId) is private.
// State mutations happen exclusively through controlled methods:
// 'bookSlot()' and 'releaseSlot()'. Includes database serialization.
// =============================================================================

import 'package:intl/intl.dart';

/// Consultation delivery mode
enum ConsultationMode {
  inPerson,
  online,
}

extension ConsultationModeExtension on ConsultationMode {
  String get label {
    switch (this) {
      case ConsultationMode.inPerson:
        return 'In-Person (Room)';
      case ConsultationMode.online:
        return 'Online (Google Meet)';
    }
  }
}

/// [OOP - ENCAPSULATION]
class TimeSlot {
  final String id;
  final String facultyId;
  final DateTime date;
  final String startTime;       // e.g. "09:00 AM"
  final String endTime;         // e.g. "10:00 AM"
  final ConsultationMode mode;
  final String locationOrLink;  // Room number or virtual meeting link

  // Encapsulated private state fields
  bool _isBooked;
  String? _bookedByGroupId;
  String? _bookingId;

  TimeSlot({
    required this.id,
    required this.facultyId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.mode,
    required this.locationOrLink,
    bool isBooked = false,
    String? bookedByGroupId,
    String? bookingId,
  })  : _isBooked = isBooked,
        _bookedByGroupId = bookedByGroupId,
        _bookingId = bookingId;

  // Public Getters (Read-Only access to private state)
  bool get isBooked => _isBooked;
  String? get bookedByGroupId => _bookedByGroupId;
  String? get bookingId => _bookingId;

  String get timeRange => '$startTime - $endTime';
  String get formattedDate => DateFormat('EEE, MMM d, yyyy').format(date);
  String get shortDate => DateFormat('MMM d').format(date);

  bool bookSlot(String groupId, String bookingId) {
    if (_isBooked) return false;
    _isBooked = true;
    _bookedByGroupId = groupId;
    _bookingId = bookingId;
    return true;
  }

  void releaseSlot() {
    _isBooked = false;
    _bookedByGroupId = null;
    _bookingId = null;
  }

  bool isSameDay(DateTime targetDate) {
    return date.year == targetDate.year &&
        date.month == targetDate.month &&
        date.day == targetDate.day;
  }

  static int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return 0;
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  /// Exact DateTime for when this slot starts
  DateTime get startDateTime {
    final mins = _parseTimeToMinutes(startTime);
    return DateTime(date.year, date.month, date.day, mins ~/ 60, mins % 60);
  }

  /// Exact DateTime for when this slot ends
  DateTime get endDateTime {
    final mins = _parseTimeToMinutes(endTime);
    return DateTime(date.year, date.month, date.day, mins ~/ 60, mins % 60);
  }

  /// Checks whether this consultation slot's start time (or date) has already passed
  bool isPast([DateTime? now]) {
    final current = now ?? DateTime.now();
    final slotDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(current.year, current.month, current.day);
    if (slotDay.isBefore(today)) return true;
    if (slotDay.isAfter(today)) return false;

    // Same day: evaluate slot start time against current time
    final startMinutes = _parseTimeToMinutes(startTime);
    final currentMinutes = current.hour * 60 + current.minute;
    return currentMinutes >= startMinutes;
  }

  /// Whether the slot is currently open and valid for future booking (unbooked and not in the past)
  bool isAvailable([DateTime? now]) {
    return !_isBooked && !isPast(now);
  }

  /// Serialization for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facultyId': facultyId,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'mode': mode.name,
      'locationOrLink': locationOrLink,
      'isBooked': _isBooked,
      'bookedByGroupId': _bookedByGroupId,
      'bookingId': _bookingId,
    };
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'] ?? '',
      facultyId: json['facultyId'] ?? '',
      date: DateTime.parse(json['date']),
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      mode: json['mode'] == 'online' ? ConsultationMode.online : ConsultationMode.inPerson,
      locationOrLink: json['locationOrLink'] ?? '',
      isBooked: json['isBooked'] ?? false,
      bookedByGroupId: json['bookedByGroupId'],
      bookingId: json['bookingId'],
    );
  }
}
