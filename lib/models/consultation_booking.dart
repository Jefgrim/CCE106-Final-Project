// =============================================================================
// FILE: lib/models/consultation_booking.dart
// OOP PRINCIPLE DEMONSTRATED: ENCAPSULATION & STATE TRANSITION
// Guarded state transitions with database serialization support.
// =============================================================================

import 'package:intl/intl.dart';
import 'time_slot.dart';

enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending Approval';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum ConsultationType {
  titleDefense,
  manuscriptReview,
  prototypeDemo,
  generalInquiry,
}

extension ConsultationTypeExtension on ConsultationType {
  String get label {
    switch (this) {
      case ConsultationType.titleDefense:
        return 'Title Defense Consultation';
      case ConsultationType.manuscriptReview:
        return 'Manuscript / Chapter Review';
      case ConsultationType.prototypeDemo:
        return 'System Prototype & Code Walkthrough';
      case ConsultationType.generalInquiry:
        return 'General Capstone Inquiry';
    }
  }
}

/// [OOP - ENCAPSULATION]
class ConsultationBooking {
  final String id;
  final String studentId;
  final String studentName;
  final String groupId;
  final String capstoneTitle;
  final String facultyId;
  final String facultyName;
  final String timeSlotId;
  final DateTime date;
  final String timeRange;
  final ConsultationMode mode;
  final String locationOrLink;
  final ConsultationType type;
  final String agenda;
  final String? documentUrl;
  final DateTime createdAt;

  // Encapsulated state fields
  BookingStatus _status;
  String? _facultyNotes;

  ConsultationBooking({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.groupId,
    required this.capstoneTitle,
    required this.facultyId,
    required this.facultyName,
    required this.timeSlotId,
    required this.date,
    required this.timeRange,
    required this.mode,
    required this.locationOrLink,
    required this.type,
    required this.agenda,
    this.documentUrl,
    DateTime? createdAt,
    BookingStatus status = BookingStatus.confirmed,
    String? facultyNotes,
  })  : createdAt = createdAt ?? DateTime.now(),
        _status = status,
        _facultyNotes = facultyNotes;

  BookingStatus get status => _status;
  String? get facultyNotes => _facultyNotes;

  /// Checks whether this consultation's date and scheduled time range has passed
  bool isPast([DateTime? now]) {
    final current = now ?? DateTime.now();
    final bookingDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(current.year, current.month, current.day);
    if (bookingDay.isBefore(today)) return true;
    if (bookingDay.isAfter(today)) return false;

    // Same day: evaluate slot end time
    final parts = timeRange.split(' - ');
    final endStr = parts.length > 1 ? parts[1].trim() : parts[0].trim();
    final endMinutes = _parseTimeToMinutes(endStr);
    final currentMinutes = current.hour * 60 + current.minute;
    return currentMinutes >= endMinutes;
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

  /// Active consultations are upcoming (not yet passed) and confirmed/pending
  bool get isActive =>
      (_status == BookingStatus.confirmed || _status == BookingStatus.pending) && !isPast();

  /// Whether the consultation is concluded/past or marked completed
  bool get isPastOrCompleted =>
      _status == BookingStatus.completed ||
      ((_status == BookingStatus.confirmed || _status == BookingStatus.pending) && isPast());

  /// User-friendly display status
  String get displayStatus => getDisplayStatus();

  String getDisplayStatus([DateTime? now]) {
    if (isCancelled) return 'CANCELLED';
    if (_status == BookingStatus.completed || isPast(now)) return 'PAST / CONCLUDED';
    return _status.displayName.toUpperCase();
  }

  bool get isCancelled => _status == BookingStatus.cancelled;

  String get formattedDate => DateFormat('EEE, MMM d, yyyy').format(date);
  String get formattedCreatedAt => DateFormat('MMM d, yyyy h:mm a').format(createdAt);

  void confirm({String? notes}) {
    _status = BookingStatus.confirmed;
    if (notes != null) _facultyNotes = notes;
  }

  void cancel({String? reason}) {
    _status = BookingStatus.cancelled;
    if (reason != null) _facultyNotes = reason;
  }

  void complete({String? feedback}) {
    _status = BookingStatus.completed;
    if (feedback != null) _facultyNotes = feedback;
  }

  /// Serialization for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'groupId': groupId,
      'capstoneTitle': capstoneTitle,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'timeSlotId': timeSlotId,
      'date': date.toIso8601String(),
      'timeRange': timeRange,
      'mode': mode.name,
      'locationOrLink': locationOrLink,
      'type': type.name,
      'agenda': agenda,
      'documentUrl': documentUrl,
      'createdAt': createdAt.toIso8601String(),
      'status': _status.name,
      'facultyNotes': _facultyNotes,
    };
  }

  factory ConsultationBooking.fromJson(Map<String, dynamic> json) {
    return ConsultationBooking(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      groupId: json['groupId'] ?? '',
      capstoneTitle: json['capstoneTitle'] ?? '',
      facultyId: json['facultyId'] ?? '',
      facultyName: json['facultyName'] ?? '',
      timeSlotId: json['timeSlotId'] ?? '',
      date: DateTime.parse(json['date']),
      timeRange: json['timeRange'] ?? '',
      mode: json['mode'] == 'online' ? ConsultationMode.online : ConsultationMode.inPerson,
      locationOrLink: json['locationOrLink'] ?? '',
      type: ConsultationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ConsultationType.generalInquiry,
      ),
      agenda: json['agenda'] ?? '',
      documentUrl: json['documentUrl'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      status: BookingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BookingStatus.confirmed,
      ),
      facultyNotes: json['facultyNotes'],
    );
  }
}
