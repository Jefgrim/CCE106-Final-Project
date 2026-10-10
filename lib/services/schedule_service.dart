// =============================================================================
// FILE: lib/services/schedule_service.dart
// OOP PRINCIPLE DEMONSTRATED: SERVICE LAYER & ENCAPSULATION
// Manages faculty schedules and slot queries without exposing raw database/state
// mutation to UI components.
// =============================================================================

import '../models/time_slot.dart';

class ScheduleService {
  /// Filter time slots for a given faculty member on a specific date
  List<TimeSlot> getSlotsForFacultyOnDate({
    required List<TimeSlot> allSlots,
    required String facultyId,
    required DateTime date,
  }) {
    return allSlots.where((slot) {
      return slot.facultyId == facultyId && slot.isSameDay(date);
    }).toList();
  }

  /// Filter all available slots across multiple faculty members on a specific date.
  /// Strictly filters out slots that are already booked OR have passed.
  List<TimeSlot> getAvailableSlotsForFacultiesOnDate({
    required List<TimeSlot> allSlots,
    required List<String> facultyIds,
    required DateTime date,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return allSlots.where((slot) {
      return facultyIds.contains(slot.facultyId) &&
          slot.isSameDay(date) &&
          slot.isAvailable(current);
    }).toList();
  }

  /// Standard consultation start times (every 30 mins during academic office hours)
  static const List<String> standardStartTimes = [
    '08:00 AM',
    '08:30 AM',
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '01:00 PM',
    '01:30 PM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
  ];

  /// Convert standard formatted time (e.g. "09:00 AM") to minutes from midnight
  static int timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return -1;
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      return hour * 60 + minute;
    } catch (_) {
      return -1;
    }
  }

  /// Convert minutes from midnight to standard formatted time (e.g. 540 -> "09:00 AM")
  static String minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final hStr = displayHour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  /// Constructs a full DateTime for a slot on a specific date and time string
  static DateTime slotDateTime(DateTime date, String timeStr) {
    final mins = timeToMinutes(timeStr);
    if (mins < 0) return date;
    return DateTime(date.year, date.month, date.day, mins ~/ 60, mins % 60);
  }

  /// Checks if a time on a given date has already passed
  static bool isPastSlot(DateTime date, String timeStr, [DateTime? now]) {
    final current = now ?? DateTime.now();
    final dt = slotDateTime(date, timeStr);
    return dt.isBefore(current);
  }

  /// Returns unopened available start times for a faculty on a specific date
  /// Filters out:
  /// 1. Times in the past.
  /// 2. Times that overlap with an already opened slot.
  /// 3. Times that don't have at least a 30-minute free window.
  List<String> getAvailableStartTimes({
    required List<TimeSlot> allSlots,
    required String facultyId,
    required DateTime date,
    DateTime? now,
  }) {
    final facultySlotsOnDate = getSlotsForFacultyOnDate(
      allSlots: allSlots,
      facultyId: facultyId,
      date: date,
    );

    return standardStartTimes.where((startTime) {
      // 1. Cannot be in the past
      if (isPastSlot(date, startTime, now)) {
        return false;
      }

      final startM = timeToMinutes(startTime);

      // 2. Cannot fall within an already opened slot [slotStart, slotEnd)
      for (final slot in facultySlotsOnDate) {
        final sStart = timeToMinutes(slot.startTime);
        final sEnd = timeToMinutes(slot.endTime);
        if (startM >= sStart && startM < sEnd) {
          return false;
        }
      }

      // 3. Minimum 30 mins check: must have at least 30 mins available before block end or next slot
      final minEndM = startM + 30;
      final blockEndM = startM < 720 ? 720 : 1020;
      if (minEndM > blockEndM) {
        return false;
      }

      for (final slot in facultySlotsOnDate) {
        final sStart = timeToMinutes(slot.startTime);
        final sEnd = timeToMinutes(slot.endTime);
        if (startM < sEnd && minEndM > sStart) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Returns valid end times for a chosen start time (minimum 30 minutes, no overlap)
  List<String> getAvailableEndTimes({
    required List<TimeSlot> allSlots,
    required String facultyId,
    required DateTime date,
    required String startTime,
  }) {
    final startM = timeToMinutes(startTime);
    if (startM < 0) return [];

    final facultySlotsOnDate = getSlotsForFacultyOnDate(
      allSlots: allSlots,
      facultyId: facultyId,
      date: date,
    );

    // End of session block (12:00 PM for morning, 05:00 PM for afternoon)
    int maxEnd = startM < 720 ? 720 : 1020;

    // Constrain to start of next existing slot, if any
    for (final slot in facultySlotsOnDate) {
      final sStart = timeToMinutes(slot.startTime);
      if (sStart > startM && sStart < maxEnd) {
        maxEnd = sStart;
      }
    }

    final validEnds = <String>[];
    for (int m = startM + 30; m <= maxEnd; m += 30) {
      validEnds.add(minutesToTime(m));
    }
    return validEnds;
  }

  /// Validates if a proposed time slot is valid, unopened, not in the past, and >= 30 mins
  bool isSlotValid({
    required List<TimeSlot> allSlots,
    required String facultyId,
    required DateTime date,
    required String startTime,
    required String endTime,
    DateTime? now,
  }) {
    if (isPastSlot(date, startTime, now)) {
      return false;
    }

    final startM = timeToMinutes(startTime);
    final endM = timeToMinutes(endTime);

    // Minimum 30 minutes
    if (startM < 0 || endM < 0 || endM - startM < 30) {
      return false;
    }

    final facultySlotsOnDate = getSlotsForFacultyOnDate(
      allSlots: allSlots,
      facultyId: facultyId,
      date: date,
    );

    // Overlap check
    for (final slot in facultySlotsOnDate) {
      final sStart = timeToMinutes(slot.startTime);
      final sEnd = timeToMinutes(slot.endTime);
      if (startM < sEnd && endM > sStart) {
        return false;
      }
    }

    return true;
  }

  /// Creates and adds a new consultation time slot for a faculty member.
  /// Validates against duplicate/overlapping slots and past times, enforcing a 30-min minimum.
  TimeSlot? addFacultySlot({
    required List<TimeSlot> allSlots,
    required String facultyId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required ConsultationMode mode,
    required String locationOrLink,
    DateTime? now,
  }) {
    if (!isSlotValid(
      allSlots: allSlots,
      facultyId: facultyId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      now: now,
    )) {
      return null;
    }

    final newSlot = TimeSlot(
      id: 'slot-${DateTime.now().millisecondsSinceEpoch}',
      facultyId: facultyId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      mode: mode,
      locationOrLink: locationOrLink,
    );

    allSlots.add(newSlot);
    return newSlot;
  }

  /// Removes an unbooked slot
  bool removeSlot({
    required List<TimeSlot> allSlots,
    required String slotId,
  }) {
    final slot = allSlots.firstWhere(
      (s) => s.id == slotId,
      orElse: () => throw Exception('Slot not found'),
    );

    if (slot.isBooked) {
      return false; // Cannot delete an already booked slot
    }

    allSlots.removeWhere((s) => s.id == slotId);
    return true;
  }
}
