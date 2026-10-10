// =============================================================================
// FILE: lib/services/database/database_service.dart
// OOP ARCHITECTURE: REPOSITORY PATTERN / ABSTRACTION
// Defines the contract for all database implementations (Local Persistent / Firebase).
// =============================================================================

import '../../models/user.dart';
import '../../models/time_slot.dart';
import '../../models/consultation_booking.dart';
import '../../models/capstone_group.dart';
import '../../models/app_notification.dart';

abstract class DatabaseService {
  Future<void> init();

  // Authentication & Users
  Future<User?> authenticate(String email, String password);
  Future<bool> registerUser(User user, String password);
  Future<List<User>> getAllUsers();
  Future<bool> sendPasswordResetEmail(String email);
  Future<bool> sendEmailVerification({String? email});
  Future<bool> isCurrentUserEmailVerified();
  Future<void> reloadCurrentUser();
  Future<bool> updatePassword(String email, String newPassword);
  Future<bool> updateUserProfile(User updatedUser);
  Future<String?> getSavedSessionUserId();
  Future<void> saveSessionUserId(String userId);
  Future<void> clearSession();
  Future<void> saveUserFcmToken(String userId, String token);
  Future<List<String>> getUserFcmTokens(String userId);

  // Time Slots
  Future<List<TimeSlot>> getSlots();
  Future<void> saveSlot(TimeSlot slot);
  Future<bool> deleteSlot(String slotId);
  Stream<List<TimeSlot>>? streamSlots() => null;

  // Consultation Bookings
  Future<List<ConsultationBooking>> getBookings();
  Future<void> saveBooking(ConsultationBooking booking);
  Future<void> updateBooking(ConsultationBooking booking);
  Stream<List<ConsultationBooking>>? streamBookings() => null;

  // Capstone Groups & Assignments
  Future<List<CapstoneGroup>> getGroups();
  Future<void> saveGroup(CapstoneGroup group);

  // Notifications
  Future<List<AppNotification>> getNotifications();
  Future<void> saveNotification(AppNotification notif);
  Stream<List<AppNotification>>? streamNotifications(String userId) => null;
}
