// =============================================================================
// FILE: lib/services/database/persistent_database_service.dart
// PRODUCTION PERSISTENT DATABASE IMPLEMENTATION
// Implements DatabaseService using SharedPreferences and JSON serialization.
// Ensures data persists permanently across page refreshes and device restarts.
// =============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import '../../models/time_slot.dart';
import '../../models/consultation_booking.dart';
import '../../models/capstone_group.dart';
import '../../models/app_notification.dart';
import 'database_service.dart';

class PersistentDatabaseService implements DatabaseService {
  static const String _keyUsers = 'capsync_db_users';
  static const String _keyPasswords = 'capsync_db_passwords';
  static const String _keySlots = 'capsync_db_slots';
  static const String _keyBookings = 'capsync_db_bookings';
  static const String _keyGroups = 'capsync_db_groups';
  static const String _keyNotifications = 'capsync_db_notifications';
  static const String _keyCleanedDemo = 'capsync_db_purged_demo_v3';
  static const String _keySessionUser = 'capsync_active_session_uid';

  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _purgeLegacyDemoDataIfPresent();
  }

  /// Ensures any legacy mock/demo or orphaned data is completely purged from local storage.
  Future<void> _purgeLegacyDemoDataIfPresent() async {
    final prefs = _prefs!;
    final alreadyPurged = prefs.getBool(_keyCleanedDemo) ?? false;
    if (!alreadyPurged) {
      await prefs.remove(_keyUsers);
      await prefs.remove(_keyPasswords);
      await prefs.remove(_keySlots);
      await prefs.remove(_keyBookings);
      await prefs.remove(_keyGroups);
      await prefs.remove(_keyNotifications);
      await prefs.setBool(_keyCleanedDemo, true);
    }
  }

  // ===========================================================================
  // AUTHENTICATION & USERS
  // ===========================================================================
  @override
  Future<User?> authenticate(String email, String password) async {
    await init();
    final prefs = _prefs!;
    final passwordsRaw = prefs.getString(_keyPasswords) ?? '{}';
    final Map<String, dynamic> passwords = jsonDecode(passwordsRaw);

    final cleanEmail = email.trim().toLowerCase();
    final storedPassword = passwords[cleanEmail];

    // Strict password verification
    if (storedPassword == null || storedPassword != password.trim()) {
      return null;
    }

    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.email.toLowerCase() == cleanEmail);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> registerUser(User user, String password) async {
    await init();
    final users = await getAllUsers();
    final cleanEmail = user.email.trim().toLowerCase();

    if (users.any((u) => u.email.toLowerCase() == cleanEmail)) {
      return false; // Email already registered
    }

    users.add(user);
    final usersJson = jsonEncode(users.map((u) => u.toJson()).toList());
    await _prefs!.setString(_keyUsers, usersJson);

    final passwordsRaw = _prefs!.getString(_keyPasswords) ?? '{}';
    final Map<String, dynamic> passwords = jsonDecode(passwordsRaw);
    passwords[cleanEmail] = password.trim();
    await _prefs!.setString(_keyPasswords, jsonEncode(passwords));

    return true;
  }

  @override
  Future<List<User>> getAllUsers() async {
    await init();
    final raw = _prefs!.getString(_keyUsers);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list
        .map((item) => User.fromJson(Map<String, dynamic>.from(item)))
        .where((u) => u.name.trim().isNotEmpty && u.email.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    await init();
    final cleanEmail = email.trim().toLowerCase();
    final users = await getAllUsers();
    return users.any((u) => u.email.toLowerCase() == cleanEmail);
  }

  static const String _keyVerifiedEmails = 'capsync_verified_emails';

  @override
  Future<bool> sendEmailVerification({String? email}) async {
    await init();
    return true;
  }

  @override
  Future<bool> isCurrentUserEmailVerified() async {
    await init();
    final verified = _prefs?.getStringList(_keyVerifiedEmails) ?? [];
    final currentUid = _prefs?.getString(_keySessionUser);
    if (currentUid != null) {
      final clean = currentUid.toLowerCase();
      if (verified.contains(clean)) return true;
    }
    return true;
  }

  Future<void> markEmailVerified(String email) async {
    await init();
    final clean = email.trim().toLowerCase();
    final verified = _prefs?.getStringList(_keyVerifiedEmails) ?? [];
    if (!verified.contains(clean)) {
      verified.add(clean);
      await _prefs?.setStringList(_keyVerifiedEmails, verified);
    }
  }

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<bool> updatePassword(String email, String newPassword) async {
    await init();
    final cleanEmail = email.trim().toLowerCase();
    final passwordsRaw = _prefs!.getString(_keyPasswords) ?? '{}';
    final Map<String, dynamic> passwords = jsonDecode(passwordsRaw);
    passwords[cleanEmail] = newPassword.trim();
    await _prefs!.setString(_keyPasswords, jsonEncode(passwords));
    return true;
  }

  @override
  Future<bool> updateUserProfile(User updatedUser) async {
    await init();
    final users = await getAllUsers();
    final cleanEmail = updatedUser.email.trim().toLowerCase();
    final index = users.indexWhere((u) => u.id == updatedUser.id || u.email.toLowerCase() == cleanEmail);
    if (index >= 0) {
      users[index] = updatedUser;
    } else {
      users.add(updatedUser);
    }
    final usersJson = jsonEncode(users.map((u) => u.toJson()).toList());
    await _prefs!.setString(_keyUsers, usersJson);
    return true;
  }

  @override
  Future<String?> getSavedSessionUserId() async {
    await init();
    return _prefs!.getString(_keySessionUser);
  }

  @override
  Future<void> saveSessionUserId(String userId) async {
    await init();
    await _prefs!.setString(_keySessionUser, userId);
  }

  @override
  Future<void> clearSession() async {
    await init();
    await _prefs!.remove(_keySessionUser);
  }

  @override
  Future<void> saveUserFcmToken(String userId, String token) async {
    await init();
    await _prefs!.setString('capsync_fcm_token_$userId', token);
  }

  @override
  Future<List<String>> getUserFcmTokens(String userId) async {
    await init();
    final token = _prefs!.getString('capsync_fcm_token_$userId');
    if (token != null && token.isNotEmpty) {
      return [token];
    }
    return [];
  }

  // ===========================================================================
  // TIME SLOTS
  // ===========================================================================
  @override
  Future<List<TimeSlot>> getSlots() async {
    await init();
    final raw = _prefs!.getString(_keySlots);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((item) => TimeSlot.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  @override
  Future<void> saveSlot(TimeSlot slot) async {
    await init();
    final slots = await getSlots();
    final idx = slots.indexWhere((s) => s.id == slot.id);
    if (idx != -1) {
      slots[idx] = slot;
    } else {
      slots.add(slot);
    }
    await _prefs!.setString(_keySlots, jsonEncode(slots.map((s) => s.toJson()).toList()));
  }

  @override
  Future<bool> deleteSlot(String slotId) async {
    await init();
    final slots = await getSlots();
    final initialCount = slots.length;
    slots.removeWhere((s) => s.id == slotId);
    if (slots.length < initialCount) {
      await _prefs!.setString(_keySlots, jsonEncode(slots.map((s) => s.toJson()).toList()));
      return true;
    }
    return false;
  }

  // ===========================================================================
  // CONSULTATION BOOKINGS
  // ===========================================================================
  @override
  Future<List<ConsultationBooking>> getBookings() async {
    await init();
    final raw = _prefs!.getString(_keyBookings);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((item) => ConsultationBooking.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  @override
  Future<void> saveBooking(ConsultationBooking booking) async {
    await init();
    final bookings = await getBookings();
    final idx = bookings.indexWhere((b) => b.id == booking.id);
    if (idx != -1) {
      bookings[idx] = booking;
    } else {
      bookings.add(booking);
    }
    await _prefs!.setString(_keyBookings, jsonEncode(bookings.map((b) => b.toJson()).toList()));
  }

  @override
  Future<void> updateBooking(ConsultationBooking booking) async {
    await saveBooking(booking);
  }

  // ===========================================================================
  // CAPSTONE GROUPS & ASSIGNMENTS
  // ===========================================================================
  @override
  Future<List<CapstoneGroup>> getGroups() async {
    await init();
    final raw = _prefs!.getString(_keyGroups);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((item) => CapstoneGroup.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  @override
  Future<void> saveGroup(CapstoneGroup group) async {
    await init();
    final groups = await getGroups();
    final idx = groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      groups[idx] = group;
    } else {
      groups.add(group);
    }
    await _prefs!.setString(_keyGroups, jsonEncode(groups.map((g) => g.toJson()).toList()));
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================
  @override
  Future<List<AppNotification>> getNotifications() async {
    await init();
    final raw = _prefs!.getString(_keyNotifications);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  @override
  Future<void> saveNotification(AppNotification notif) async {
    await init();
    final notifs = await getNotifications();
    final idx = notifs.indexWhere((n) => n.id == notif.id);
    if (idx != -1) {
      notifs[idx] = notif;
    } else {
      notifs.add(notif);
    }
    await _prefs!.setString(_keyNotifications, jsonEncode(notifs.map((n) => n.toJson()).toList()));
  }

  @override
  Stream<List<TimeSlot>>? streamSlots() => null;

  @override
  Stream<List<ConsultationBooking>>? streamBookings() => null;

  @override
  Stream<List<AppNotification>>? streamNotifications(String userId) => null;
}
