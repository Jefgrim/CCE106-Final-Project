// =============================================================================
// FILE: lib/services/booking_service.dart
// OOP PRINCIPLE DEMONSTRATED:
// 1. SINGLE RESPONSIBILITY PRINCIPLE (SRP): Exclusively responsible for
//    consultation booking business rules, validation, and preventing double-booking.
// 2. ENCAPSULATION: Enforces validation rules before mutating booking state.
// =============================================================================

import '../models/consultation_booking.dart';
import '../models/time_slot.dart';

/// Custom result object to encapsulate outcome of a booking transaction
class BookingResult {
  final bool isSuccess;
  final String message;
  final ConsultationBooking? booking;

  BookingResult.success(this.booking, {this.message = 'Consultation booked successfully!'})
      : isSuccess = true;

  BookingResult.failure(this.message)
      : isSuccess = false,
        booking = null;
}

/// [OOP - ENCAPSULATION & BUSINESS LOGIC SERVICE]
class BookingService {
  /// [DOUBLE-BOOKING PREVENTION ALGORITHM]
  /// Checks whether a target time slot can be safely booked:
  /// 1. Verifies the slot itself is not already booked by another group.
  /// 2. Verifies the student's group does not have a conflicting booking at the same date & time.
  BookingResult validateAndBook({
    required TimeSlot slot,
    required List<ConsultationBooking> existingBookings,
    required String studentId,
    required String studentName,
    required String groupId,
    required String capstoneTitle,
    required String facultyId,
    required String facultyName,
    required ConsultationType type,
    required String agenda,
    String? documentUrl,
    DateTime? now,
  }) {
    // 1. Double-booking check on the specific time slot
    if (slot.isBooked) {
      return BookingResult.failure(
        'Double-booking prevented: This slot has already been reserved by another group.',
      );
    }

    // 2. Past slot check: prevent booking slots that have already started or concluded
    final current = now ?? DateTime.now();
    if (slot.isPast(current)) {
      return BookingResult.failure(
        'Cannot book slot: This consultation time slot has already passed.',
      );
    }

    // 2. Conflict check: Allow only ONE booking per day for each capstone group
    final hasGroupDailyBooking = existingBookings.any((b) =>
        b.groupId == groupId &&
        !b.isCancelled &&
        b.date.year == slot.date.year &&
        b.date.month == slot.date.month &&
        b.date.day == slot.date.day);

    if (hasGroupDailyBooking) {
      return BookingResult.failure(
        'Daily limit reached: Your capstone group already has an active consultation scheduled for this date (${slot.formattedDate}). Groups are allowed only one consultation booking per day.',
      );
    }

    // 3. Form validation
    if (agenda.trim().length < 10) {
      return BookingResult.failure(
        'Validation error: Please provide a clear consultation agenda (minimum 10 characters).',
      );
    }

    // Generate unique booking ID
    final bookingId = 'book-${DateTime.now().millisecondsSinceEpoch}';

    // 4. Safely reserve the time slot (Encapsulated state change)
    final reserved = slot.bookSlot(groupId, bookingId);
    if (!reserved) {
      return BookingResult.failure(
        'Double-booking prevented: Slot could not be reserved.',
      );
    }

    // 5. Instantiate new ConsultationBooking object
    final newBooking = ConsultationBooking(
      id: bookingId,
      studentId: studentId,
      studentName: studentName,
      groupId: groupId,
      capstoneTitle: capstoneTitle,
      facultyId: facultyId,
      facultyName: facultyName,
      timeSlotId: slot.id,
      date: slot.date,
      timeRange: slot.timeRange,
      mode: slot.mode,
      locationOrLink: slot.locationOrLink,
      type: type,
      agenda: agenda.trim(),
      documentUrl: documentUrl?.trim().isEmpty ?? true ? null : documentUrl?.trim(),
      status: BookingStatus.confirmed,
    );

    return BookingResult.success(newBooking);
  }

  /// Cancels a booking and frees the corresponding time slot
  bool cancelBooking({
    required ConsultationBooking booking,
    required List<TimeSlot> allSlots,
    String? reason,
  }) {
    // 1. Transition booking status to Cancelled
    booking.cancel(reason: reason ?? 'Cancelled by student');

    // 2. Find associated slot and release it
    final slotIndex = allSlots.indexWhere((s) => s.id == booking.timeSlotId);
    if (slotIndex != -1) {
      allSlots[slotIndex].releaseSlot();
      return true;
    }

    return false;
  }
}
