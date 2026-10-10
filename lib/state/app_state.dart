// =============================================================================
// FILE: lib/state/app_state.dart
// PRODUCTION STATE MANAGEMENT: Central ChangeNotifier backed by DatabaseService.
// Supports Authentication (Login/Register/Logout), Persistent Database operations,
// and real-time UI reactivity.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/time_slot.dart';
import '../models/consultation_booking.dart';
import '../models/capstone_group.dart';
import '../models/app_notification.dart';
import '../services/booking_service.dart';
import '../services/schedule_service.dart';
import '../services/database/database_service.dart';
import '../services/database/firebase_database_service.dart';
import '../services/push_notification_service.dart';
import '../services/fcm_sender_service.dart';
import '../services/diagnostics/network_diagnostics_service.dart';
import '../services/email_otp_service.dart';

class AppState extends ChangeNotifier {
  // Services
  final BookingService _bookingService = BookingService();
  final ScheduleService _scheduleService = ScheduleService();
  final DatabaseService _databaseService = FirebaseDatabaseService();
  final EmailOtpService _otpService = EmailOtpService();

  // Active Session & Data State
  User? _currentUser;
  bool _isLoading = true;
  String? _lastLoginError;
  String? _lastLoginDiagnostics;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initializationDone => _initCompleter.future;

  List<User> _allUsers = [];
  List<TimeSlot> _slots = [];
  List<ConsultationBooking> _bookings = [];
  List<CapstoneGroup> _groups = [];
  List<AppNotification> _notifications = [];
  final Set<String> _knownNotificationIds = {};
  Timer? _liveSyncTimer;

  // Real-time Firestore Stream Subscriptions
  StreamSubscription<List<TimeSlot>>? _slotsSubscription;
  StreamSubscription<List<ConsultationBooking>>? _bookingsSubscription;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;

  // Active Filter State
  DateTime _selectedDate = DateTime.now();
  String? _selectedFacultyFilterId;

  AppState() {
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    initializeDatabase();
    _startLiveSyncTimer();
  }

  @override
  void dispose() {
    _cancelRealtimeListeners();
    _liveSyncTimer?.cancel();
    super.dispose();
  }

  void _cancelRealtimeListeners() {
    _slotsSubscription?.cancel();
    _slotsSubscription = null;
    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
  }

  void _initRealtimeListeners() {
    _cancelRealtimeListeners();
    if (_isTestingMode) return;

    // 1. Real-time Slots Listener: Automatically updates UI when any faculty adds or changes slots
    final slotsStream = _databaseService.streamSlots();
    if (slotsStream != null) {
      _slotsSubscription = slotsStream.listen(
        (updatedSlots) {
          debugPrint("CapSync Realtime: Received ${updatedSlots.length} slot(s) from Firestore.");
          _slots = updatedSlots;
          notifyListeners();
        },
        onError: (e) {
          debugPrint("CapSync Realtime slots error: $e");
        },
      );
    }

    // 2. Real-time Bookings Listener: Automatically updates statuses and notes
    final bookingsStream = _databaseService.streamBookings();
    if (bookingsStream != null) {
      _bookingsSubscription = bookingsStream.listen(
        (updatedBookings) {
          debugPrint("CapSync Realtime: Received ${updatedBookings.length} booking(s) from Firestore.");
          _bookings = updatedBookings;
          notifyListeners();
        },
        onError: (e) {
          debugPrint("CapSync Realtime bookings error: $e");
        },
      );
    }

    // 3. Real-time Notifications Listener for the current logged-in user
    if (_currentUser != null) {
      final notifsStream = _databaseService.streamNotifications(_currentUser!.id);
      if (notifsStream != null) {
        _notificationsSubscription = notifsStream.listen(
          (updatedNotifs) {
            bool hasNew = false;
            for (final notif in updatedNotifs) {
              if (!_knownNotificationIds.contains(notif.id)) {
                _knownNotificationIds.add(notif.id);
                hasNew = true;
                if (!notif.isRead) {
                  PushNotificationService.showNotification(
                    title: notif.title,
                    body: notif.message,
                  );
                }
              }
            }
            _notifications = updatedNotifs;
            if (hasNew) {
              // Immediately sync slots in case a new slot was opened
              _syncSilently();
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint("CapSync Realtime notifs error: $e");
          },
        );
      }
    }
  }

  void _onUserSessionEstablished(User user) {
    _initRealtimeListeners();

    // Register FCM Device Registration Token for Cloud Push Notifications
    PushNotificationService.getDeviceToken().then((token) {
      if (token != null && token.isNotEmpty) {
        _databaseService.saveUserFcmToken(user.id, token);
      }
    }).catchError((e) {
      debugPrint("FCM token registration notice: $e");
    });

    // Register token refresh listener so rotated tokens are persisted
    PushNotificationService.initialize(onTokenRefresh: (newToken) {
      if (_currentUser != null && newToken.isNotEmpty) {
        _databaseService.saveUserFcmToken(_currentUser!.id, newToken);
      }
    });

    // Subscribe to role and broadcast FCM notification topics
    PushNotificationService.subscribeToTopic('all_users');
    PushNotificationService.subscribeToTopic('role_${user.role.name}');
    PushNotificationService.subscribeToTopic('user_${user.id}');
    if (user is Student && user.groupId.isNotEmpty) {
      PushNotificationService.subscribeToTopic('group_${user.groupId}');
    }
  }

  /// Dispatches push notifications directly to the recipient's FCM device tokens
  /// (for instant delivery when their app is completely closed) and to their topic as a secondary channel.
  Future<void> _dispatchPushNotificationToUser({
    required String recipientUserId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    // 1. Direct device token push (instant, wakes up phone when app is closed / killed)
    try {
      final tokens = await _databaseService.getUserFcmTokens(recipientUserId);
      if (tokens.isNotEmpty) {
        await FcmSenderService.sendPushToTokens(
          tokens: tokens,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      debugPrint("Direct FCM token push notice ($recipientUserId): $e");
    }

    // 2. Secondary topic broadcast as fallback
    try {
      await FcmSenderService.sendPushToTopic(
        topic: 'user_$recipientUserId',
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint("FCM topic push notice ($recipientUserId): $e");
    }
  }

  void _startLiveSyncTimer() {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_currentUser != null && !_isLoading && !_isTestingMode) {
        _syncSilently();
      }
    });
  }

  /// Silently polls slots, bookings, and notifications in the background
  /// to ensure data freshness even under unstable internet or REST fallback mode.
  Future<void> _syncSilently() async {
    if (_currentUser == null || _isLoading || _isTestingMode) return;
    try {
      final results = await Future.wait([
        _databaseService.getSlots(),
        _databaseService.getBookings(),
        _databaseService.getNotifications(),
      ]).timeout(const Duration(seconds: 8));

      final latestSlots = results[0] as List<TimeSlot>;
      final latestBookings = results[1] as List<ConsultationBooking>;
      final latestNotifs = results[2] as List<AppNotification>;

      bool hasChanged = false;

      // 1. Sync slots if count or statuses changed
      if (latestSlots.length != _slots.length ||
          latestSlots.any((s) {
            final match = _slots.where((e) => e.id == s.id).firstOrNull;
            return match == null || match.isBooked != s.isBooked;
          })) {
        _slots = latestSlots;
        hasChanged = true;
      }

      // 2. Sync bookings if count or status/notes changed
      if (latestBookings.length != _bookings.length ||
          latestBookings.any((b) {
            final match = _bookings.where((e) => e.id == b.id).firstOrNull;
            return match == null || match.status != b.status || match.facultyNotes != b.facultyNotes;
          })) {
        _bookings = latestBookings;
        hasChanged = true;
      }

      // 3. Process new notifications
      for (final notif in latestNotifs) {
        if (!_knownNotificationIds.contains(notif.id)) {
          _knownNotificationIds.add(notif.id);
          _notifications.add(notif);
          hasChanged = true;

          if (notif.recipientUserId == _currentUser!.id && !notif.isRead) {
            PushNotificationService.showNotification(
              title: notif.title,
              body: notif.message,
            );
          }
        }
      }

      if (hasChanged) {
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Initialize database connection, load persistent data, and restore active session
  Future<void> initializeDatabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _databaseService.init();
      await refreshData();

      // Auto-login / restore session across phone app restarts
      if (_currentUser == null) {
        try {
          final savedUid = await _databaseService.getSavedSessionUserId();
          if (savedUid != null && savedUid.isNotEmpty) {
            final matched = _allUsers.cast<User?>().firstWhere(
              (u) =>
                  u != null &&
                  (u.id == savedUid ||
                      u.email.toLowerCase() == savedUid.toLowerCase()),
              orElse: () => null,
            );
            if (matched != null) {
              _currentUser = matched;
              _onUserSessionEstablished(matched);
              debugPrint("CapSync: Restored session for ${matched.name} (${matched.role.name})");
            }
          }
        } catch (e) {
          debugPrint("CapSync session restoration notice: $e");
        }
      }
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isTestingMode = false;

  /// Refreshes all collections from the active database service in parallel
  Future<void> refreshData() async {
    if (_isTestingMode) return;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _databaseService.getAllUsers(),
        _databaseService.getSlots(),
        _databaseService.getBookings(),
        _databaseService.getGroups(),
        _databaseService.getNotifications(),
      ]).timeout(const Duration(seconds: 15));

      _allUsers = results[0] as List<User>;
      _slots = results[1] as List<TimeSlot>;
      _bookings = results[2] as List<ConsultationBooking>;
      _groups = results[3] as List<CapstoneGroup>;
      _notifications = results[4] as List<AppNotification>;
      _knownNotificationIds.addAll(_notifications.map((n) => n.id));

      if (_currentUser != null) {
        final updatedUser = _allUsers.firstWhere(
          (u) =>
              u.id == _currentUser!.id ||
              u.email.toLowerCase() == _currentUser!.email.toLowerCase(),
          orElse: () => _currentUser!,
        );
        _currentUser = updatedUser;
      }
    } catch (e) {
      debugPrint("refreshData error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // PUBLIC GETTERS
  // ===========================================================================
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get lastLoginError => _lastLoginError;
  String? get lastLoginDiagnostics => _lastLoginDiagnostics;

  List<User>? _testingUsers;
  List<User> get allUsers => _testingUsers ?? _allUsers;

  List<FacultyMember> get facultyList =>
      allUsers.whereType<FacultyMember>().toList();

  List<Student> get studentList =>
      allUsers.whereType<Student>().toList();

  Coordinator? get coordinator {
    try {
      return allUsers.whereType<Coordinator>().first;
    } catch (_) {
      return null;
    }
  }

  List<CapstoneGroup> get groups => List.unmodifiable(_groups);
  List<TimeSlot> get slots => List.unmodifiable(_slots);
  List<ConsultationBooking> get bookings => List.unmodifiable(_bookings);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  DateTime get selectedDate => _selectedDate;
  String? get selectedFacultyFilterId => _selectedFacultyFilterId;
  ScheduleService get scheduleService => _scheduleService;
  EmailOtpService get otpService => _otpService;

  /// Returns active student's capstone group
  CapstoneGroup? get currentStudentGroup {
    if (_currentUser is! Student) return null;
    final student = _currentUser as Student;

    // 1. Direct match by groupId or groupNumber
    if (student.groupId.isNotEmpty) {
      try {
        return _groups.firstWhere(
          (g) =>
              g.id.trim().toLowerCase() == student.groupId.trim().toLowerCase() ||
              g.groupNumber.trim().toLowerCase() == student.groupId.trim().toLowerCase(),
        );
      } catch (_) {}
    }

    // 2. Fallback: match by student ID or name in group members
    try {
      return _groups.firstWhere(
        (g) => g.studentMembers.any((m) =>
            m.contains(student.id) ||
            m.toLowerCase().contains(student.name.toLowerCase())),
      );
    } catch (_) {
      return null;
    }
  }

  /// Active student's assigned adviser
  FacultyMember? get currentAssignedAdviser {
    final group = currentStudentGroup;
    if (group == null || group.adviserId.trim().isEmpty) return null;
    try {
      return facultyList.firstWhere(
        (f) =>
            f.id.trim().toLowerCase() == group.adviserId.trim().toLowerCase() ||
            f.name.trim().toLowerCase() == group.adviserId.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Active student's assigned lead panelist
  FacultyMember? get currentAssignedLeadPanelist {
    final group = currentStudentGroup;
    if (group == null || group.leadPanelistId.trim().isEmpty) return null;
    try {
      return facultyList.firstWhere(
        (f) =>
            f.id.trim().toLowerCase() == group.leadPanelistId.trim().toLowerCase() ||
            f.name.trim().toLowerCase() == group.leadPanelistId.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Active student's assigned panelists
  List<FacultyMember> get currentAssignedPanelists {
    final group = currentStudentGroup;
    if (group == null) return [];
    return facultyList.where((f) {
      return group.panelistIds.any((pid) =>
          pid.trim().toLowerCase() == f.id.trim().toLowerCase() ||
          pid.trim().toLowerCase() == f.name.trim().toLowerCase());
    }).toList();
  }

  /// All assigned faculty for the active student
  List<FacultyMember> get allAssignedFacultyForStudent {
    final group = currentStudentGroup;
    if (group == null) return [];
    final assignedIds = group.allAssignedFacultyIds;
    return facultyList.where((f) => assignedIds.any((id) =>
        id.trim().toLowerCase() == f.id.trim().toLowerCase() ||
        id.trim().toLowerCase() == f.name.trim().toLowerCase())).toList();
  }

  /// Available consultation slots rendered on Availability Dashboard.
  /// Strictly filters to show only slots that are available (!isBooked) and NOT in the past.
  List<TimeSlot> getDashboardFilteredSlots([DateTime? now]) {
    List<String> targetFacultyIds;

    if (_selectedFacultyFilterId != null) {
      targetFacultyIds = [_selectedFacultyFilterId!];
    } else {
      if (_currentUser is Student) {
        targetFacultyIds = allAssignedFacultyForStudent.map((f) => f.id).toList();
      } else if (_currentUser is FacultyMember) {
        targetFacultyIds = [_currentUser!.id];
      } else {
        targetFacultyIds = facultyList.map((f) => f.id).toList();
      }
    }

    final current = now ?? DateTime.now();
    return _slots.where((slot) {
      final isFacultyMatch = targetFacultyIds.contains(slot.facultyId);
      final isDateMatch = slot.isSameDay(_selectedDate);
      final isAvailable = slot.isAvailable(current);
      return isFacultyMatch && isDateMatch && isAvailable;
    }).toList();
  }

  /// Slots rendered on Availability Dashboard (strictly available and not in the past)
  List<TimeSlot> get dashboardFilteredSlots => getDashboardFilteredSlots();

  /// Current student's bookings
  List<ConsultationBooking> get currentStudentBookings {
    if (_currentUser is! Student) return [];
    final student = _currentUser as Student;
    return _bookings.where((b) => b.groupId == student.groupId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Faculty member's received bookings
  List<ConsultationBooking> get currentFacultyBookings {
    if (_currentUser is! FacultyMember) return [];
    return _bookings.where((b) => b.facultyId == _currentUser!.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Notifications for current user
  List<AppNotification> get userNotifications {
    if (_currentUser == null) return [];
    return _notifications
        .where((n) => n.recipientUserId == _currentUser!.id)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int get unreadNotificationCount =>
      userNotifications.where((n) => !n.isRead).length;

  FacultyMember? getFacultyById(String id) {
    try {
      return facultyList.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // AUTHENTICATION METHODS
  // ===========================================================================
  Future<bool> login(String email, String password) async {
    _lastLoginError = null;
    _lastLoginDiagnostics = null;
    final user = await _databaseService.authenticate(email, password);
    if (user != null) {
      _currentUser = user;
      _selectedFacultyFilterId = null;
      await _databaseService.saveSessionUserId(user.id);
      _onUserSessionEstablished(user);
      notifyListeners();

      // Trigger live sync in background without blocking navigation
      unawaited(refreshData());

      return true;
    }

    if (_databaseService is FirebaseDatabaseService) {
      _lastLoginError = _databaseService.lastAuthError;
      _lastLoginDiagnostics = _databaseService.lastAuthDiagnostics;
    }
    return false;
  }

  /// Runs complete live network reachability and Firebase diagnostic checks
  Future<String> runConnectionDiagnostics({String? email}) async {
    if (_databaseService is FirebaseDatabaseService) {
      return _databaseService.runFullDiagnostics(email: email);
    }
    return NetworkDiagnosticsService.runFullDiagnosticReport(
      attemptedEmail: email,
      lastErrorDescription: _lastLoginError,
    );
  }

  Future<bool> register(User newUser, String password) async {
    final registered = await _databaseService.registerUser(newUser, password);
    if (registered) {
      final authUser = await _databaseService.authenticate(newUser.email, password);
      final userToSet = authUser ?? newUser;

      _currentUser = userToSet;
      _selectedFacultyFilterId = null;
      await _databaseService.saveSessionUserId(userToSet.id);
      _onUserSessionEstablished(userToSet);
      await refreshData();
      return true;
    }
    return false;
  }

  /// Dispatches email verification link via Firebase Auth
  Future<bool> sendEmailVerification({String? email}) async {
    return _databaseService.sendEmailVerification(email: email);
  }

  /// Checks whether current user's email has been verified in Firebase Auth
  Future<bool> isCurrentUserEmailVerified() async {
    return _databaseService.isCurrentUserEmailVerified();
  }

  /// Reloads user from Firebase Auth and activates session if verified
  Future<bool> checkEmailVerifiedAndActivate(User user) async {
    await _databaseService.reloadCurrentUser();
    final verified = await _databaseService.isCurrentUserEmailVerified();
    if (verified) {
      _currentUser = user;
      _selectedFacultyFilterId = null;
      await _databaseService.saveSessionUserId(user.id);
      _onUserSessionEstablished(user);
      await refreshData();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _cancelRealtimeListeners();
    _currentUser = null;
    _selectedFacultyFilterId = null;
    await _databaseService.clearSession();
    notifyListeners();
  }

  void setCurrentUserForTesting(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void setUsersForTesting(List<User> users) {
    _isTestingMode = true;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
    _testingUsers = List.from(users);
    _allUsers = List.from(users);
    _isLoading = false;
    notifyListeners();
  }

  void setGroupsForTesting(List<CapstoneGroup> groups) {
    _groups = List.from(groups);
    notifyListeners();
  }

  void setSlotsForTesting(List<TimeSlot> slots) {
    _slots = List.from(slots);
    notifyListeners();
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    return _databaseService.sendPasswordResetEmail(email);
  }

  Future<bool> changePassword(String newPassword) async {
    if (_currentUser == null) return false;
    return _databaseService.updatePassword(_currentUser!.email, newPassword);
  }

  Future<bool> updateUserProfile(User updatedUser) async {
    final success = await _databaseService.updateUserProfile(updatedUser);
    if (success) {
      _allUsers.removeWhere((u) => u.id == updatedUser.id || u.email.toLowerCase() == updatedUser.email.toLowerCase());
      _allUsers.add(updatedUser);
      if (_currentUser?.id == updatedUser.id || _currentUser?.email.toLowerCase() == updatedUser.email.toLowerCase()) {
        _currentUser = updatedUser;
      }
      notifyListeners();
    }
    return success;
  }

  // ===========================================================================
  // OPERATIONS & DATABASE PERSISTENCE
  // ===========================================================================
  void setSelectedDate(DateTime newDate) {
    _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
    notifyListeners();
  }

  void setFacultyFilter(String? facultyId) {
    _selectedFacultyFilterId = facultyId;
    notifyListeners();
  }

  BookingResult bookConsultation({
    required TimeSlot slot,
    required ConsultationType type,
    required String agenda,
    String? documentUrl,
    DateTime? now,
  }) {
    if (_currentUser is! Student) {
      return BookingResult.failure('Only students can book consultations.');
    }

    final student = _currentUser as Student;
    final faculty = getFacultyById(slot.facultyId);
    if (faculty == null) {
      return BookingResult.failure('Assigned faculty member not found.');
    }

    final result = _bookingService.validateAndBook(
      slot: slot,
      existingBookings: _bookings,
      studentId: student.id,
      studentName: student.name,
      groupId: student.groupId,
      capstoneTitle: student.capstoneTitle,
      facultyId: faculty.id,
      facultyName: faculty.name,
      type: type,
      agenda: agenda,
      documentUrl: documentUrl,
      now: now ?? DateTime.now(),
    );

    if (result.isSuccess && result.booking != null) {
      _bookings.add(result.booking!);

      // Save to database
      _databaseService.saveSlot(slot);
      _databaseService.saveBooking(result.booking!);

      // Push simulated push notification to Student
      final notifStudent = AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-1',
        recipientUserId: student.id,
        title: 'Consultation Booked',
        message: 'Your consultation with ${faculty.name} for ${slot.formattedDate} at ${slot.timeRange} has been scheduled.',
        type: NotificationType.bookingConfirmed,
      );
      _notifications.add(notifStudent);
      _databaseService.saveNotification(notifStudent);

      // Push notification to Faculty
      final notifFaculty = AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-2',
        recipientUserId: faculty.id,
        title: 'New Capstone RSVP Received',
        message: 'Group ${student.groupId.replaceAll('grp-', '')} (${student.name}) requested a consultation for ${slot.formattedDate} (${slot.timeRange}).',
        type: NotificationType.bookingRequested,
      );
      _notifications.add(notifFaculty);
      _databaseService.saveNotification(notifFaculty);

      PushNotificationService.showNotification(
        title: notifStudent.title,
        body: notifStudent.message,
      );

      // Direct Cloud Push via FCM to Faculty (delivers when faculty's app is closed)
      _dispatchPushNotificationToUser(
        recipientUserId: faculty.id,
        title: notifFaculty.title,
        body: notifFaculty.message,
        data: {'type': 'bookingRequested', 'slotId': slot.id},
      );

      notifyListeners();
    }

    return result;
  }

  bool cancelBooking(ConsultationBooking booking, {String? reason}) {
    final success = _bookingService.cancelBooking(
      booking: booking,
      allSlots: _slots,
      reason: reason,
    );

    if (success) {
      // Find updated slot
      final slot = _slots.firstWhere((s) => s.id == booking.timeSlotId);
      _databaseService.saveSlot(slot);
      _databaseService.updateBooking(booking);

      final notifStudent = AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-3',
        recipientUserId: booking.studentId,
        title: 'Consultation Cancelled',
        message: 'The consultation scheduled on ${booking.formattedDate} at ${booking.timeRange} was cancelled.',
        type: NotificationType.bookingCancelled,
      );
      _notifications.add(notifStudent);
      _databaseService.saveNotification(notifStudent);

      final notifFaculty = AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-4',
        recipientUserId: booking.facultyId,
        title: 'Slot Freed / Consultation Cancelled',
        message: 'Group ${booking.groupId.replaceAll('grp-', '')} cancelled their consultation on ${booking.formattedDate}.',
        type: NotificationType.bookingCancelled,
      );
      _notifications.add(notifFaculty);
      _databaseService.saveNotification(notifFaculty);

      PushNotificationService.showNotification(
        title: notifStudent.title,
        body: notifStudent.message,
      );

      // Direct Cloud Push via FCM to Student & Faculty (delivers when app is closed)
      _dispatchPushNotificationToUser(
        recipientUserId: booking.studentId,
        title: notifStudent.title,
        body: notifStudent.message,
        data: {'type': 'bookingCancelled'},
      );
      _dispatchPushNotificationToUser(
        recipientUserId: booking.facultyId,
        title: notifFaculty.title,
        body: notifFaculty.message,
        data: {'type': 'bookingCancelled'},
      );

      notifyListeners();
    }

    return success;
  }

  bool addFacultySlot({
    required DateTime date,
    required String startTime,
    required String endTime,
    required ConsultationMode mode,
    required String locationOrLink,
    DateTime? now,
  }) {
    if (_currentUser is! FacultyMember) return false;
    final faculty = _currentUser as FacultyMember;

    final newSlot = _scheduleService.addFacultySlot(
      allSlots: _slots,
      facultyId: faculty.id,
      date: date,
      startTime: startTime,
      endTime: endTime,
      mode: mode,
      locationOrLink: locationOrLink,
      now: now,
    );

    if (newSlot != null) {
      _databaseService.saveSlot(newSlot);

      // Find all student groups under this faculty member (adviser, lead panelist, or panelist)
      final groupsUnderFaculty = _groups.where((g) {
        final fid = faculty.id.trim().toLowerCase();
        final fname = faculty.name.trim().toLowerCase();
        return g.allAssignedFacultyIds.any((id) {
          final cleanId = id.trim().toLowerCase();
          return cleanId == fid || cleanId == fname;
        });
      }).toList();

      final Set<String> notifiedStudentIds = {};
      final List<Student> studentsToNotify = [];

      for (final group in groupsUnderFaculty) {
        for (final student in studentList) {
          final matchesGroup = (student.groupId.isNotEmpty &&
                  (student.groupId.trim().toLowerCase() == group.id.trim().toLowerCase() ||
                   student.groupId.trim().toLowerCase() == group.groupNumber.trim().toLowerCase())) ||
              group.studentMembers.any((m) =>
                  m.trim().toLowerCase() == student.id.trim().toLowerCase() ||
                  m.trim().toLowerCase() == student.name.trim().toLowerCase());

          if (matchesGroup && !notifiedStudentIds.contains(student.id)) {
            notifiedStudentIds.add(student.id);
            studentsToNotify.add(student);
          }
        }
      }

      // If no capstone groups are configured yet, notify all students in the college
      if (groupsUnderFaculty.isEmpty && studentsToNotify.isEmpty) {
        studentsToNotify.addAll(studentList);
      }

      final modeText = mode == ConsultationMode.inPerson
          ? (locationOrLink.isNotEmpty ? 'In-Person: $locationOrLink' : 'In-Person')
          : 'Online: Google Meet';

      for (final student in studentsToNotify) {
        final notif = AppNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${student.id}',
          recipientUserId: student.id,
          title: 'New Consultation Slot Available',
          message: '${faculty.name} opened a consultation slot for ${newSlot.formattedDate} at ${newSlot.timeRange} ($modeText). Tap to book.',
          type: NotificationType.slotAdded,
        );
        _notifications.add(notif);
        _knownNotificationIds.add(notif.id);
        _databaseService.saveNotification(notif);
      }

      // Trigger native system push notification banner
      PushNotificationService.showNotification(
        title: 'Consultation Slot Published',
        body: 'Slot on ${newSlot.formattedDate} (${newSlot.timeRange}) opened. ${studentsToNotify.length} student(s) under you were notified.',
      );

      // Direct Cloud Push via FCM to target student devices (delivers when closed) & role topic
      FcmSenderService.sendPushToTopic(
        topic: 'role_student',
        title: 'New Consultation Slot Available',
        body: '${faculty.name} opened a consultation slot for ${newSlot.formattedDate} at ${newSlot.timeRange} ($modeText).',
        data: {'type': 'slotAdded', 'slotId': newSlot.id},
      );
      for (final student in studentsToNotify) {
        _dispatchPushNotificationToUser(
          recipientUserId: student.id,
          title: 'New Consultation Slot Available',
          body: '${faculty.name} opened a consultation slot for ${newSlot.formattedDate} at ${newSlot.timeRange}.',
          data: {'type': 'slotAdded', 'slotId': newSlot.id},
        );
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  bool removeFacultySlot(String slotId) {
    final removed = _scheduleService.removeSlot(
      allSlots: _slots,
      slotId: slotId,
    );
    if (removed) {
      _databaseService.deleteSlot(slotId);
      notifyListeners();
    }
    return removed;
  }

  void addBookingNote(ConsultationBooking booking, String notes) {
    booking.confirm(notes: notes);
    _databaseService.updateBooking(booking);

    final trimmed = notes.trim();
    final notifMessage = trimmed.isNotEmpty
        ? '${booking.facultyName} added a consultation note: "$trimmed"'
        : '${booking.facultyName} updated instructions for your consultation on ${booking.formattedDate}.';

    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      recipientUserId: booking.studentId,
      title: 'Adviser Added a Note',
      message: notifMessage,
      type: NotificationType.noteAdded,
    );
    _notifications.add(notif);
    _databaseService.saveNotification(notif);

    PushNotificationService.showNotification(
      title: notif.title,
      body: notif.message,
    );

    // Direct Cloud Push via FCM to Student (delivers when student's app is closed)
    _dispatchPushNotificationToUser(
      recipientUserId: booking.studentId,
      title: notif.title,
      body: notif.message,
      data: {'type': 'noteAdded', 'bookingId': booking.id},
    );

    notifyListeners();
  }

  void confirmBooking(ConsultationBooking booking, {String? notes}) {
    final wasAlreadyConfirmed = booking.status == BookingStatus.confirmed;
    booking.confirm(notes: notes);
    _databaseService.updateBooking(booking);

    final String title = wasAlreadyConfirmed ? 'Adviser Added a Note' : 'Consultation Approved';
    final String message = wasAlreadyConfirmed
        ? (notes != null && notes.trim().isNotEmpty
            ? '${booking.facultyName} added a consultation note: "${notes.trim()}"'
            : '${booking.facultyName} updated instructions for your consultation on ${booking.formattedDate}.')
        : '${booking.facultyName} has confirmed your consultation. Notes: ${notes ?? "See you on time."}';

    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      recipientUserId: booking.studentId,
      title: title,
      message: message,
      type: wasAlreadyConfirmed ? NotificationType.noteAdded : NotificationType.bookingConfirmed,
    );
    _notifications.add(notif);
    _databaseService.saveNotification(notif);

    PushNotificationService.showNotification(
      title: notif.title,
      body: notif.message,
    );

    // Direct Cloud Push via FCM to Student (delivers when student's app is closed)
    _dispatchPushNotificationToUser(
      recipientUserId: booking.studentId,
      title: notif.title,
      body: notif.message,
      data: {'type': 'bookingConfirmed', 'bookingId': booking.id},
    );

    notifyListeners();
  }

  void updateGroupAssignment({
    required String groupId,
    required String adviserId,
    required String leadPanelistId,
    required List<String> panelistIds,
  }) {
    final groupIndex = _groups.indexWhere((g) => g.id == groupId);
    if (groupIndex != -1) {
      _groups[groupIndex].setAdviser(adviserId);
      _groups[groupIndex].setLeadPanelist(leadPanelistId);
      _groups[groupIndex].setPanelists(panelistIds);
      _databaseService.saveGroup(_groups[groupIndex]);
      notifyListeners();
    }
  }

  /// Dean / Coordinator adds a new faculty member / teacher
  Future<bool> addFacultyByCoordinator({
    required FacultyMember faculty,
    required String password,
  }) async {
    try {
      if (_allUsers.any((u) => u.email.toLowerCase() == faculty.email.toLowerCase())) {
        debugPrint("addFacultyByCoordinator error: email ${faculty.email} already registered.");
        return false;
      }

      User? createdUser;
      if (_databaseService is FirebaseDatabaseService) {
        createdUser = await _databaseService
            .createFacultyUser(faculty, password);
      } else {
        final registered = await _databaseService.registerUser(faculty, password);
        if (registered) createdUser = faculty;
      }

      if (createdUser != null) {
        _allUsers.removeWhere((u) => u.id == createdUser!.id || u.email.toLowerCase() == createdUser.email.toLowerCase());
        _allUsers.add(createdUser);
        await refreshData();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error in addFacultyByCoordinator: $e");
    }
    return false;
  }

  /// Dean / Coordinator creates a new Capstone Group and pairs students with teachers
  Future<void> createCapstoneGroup({
    required CapstoneGroup group,
    required List<String> studentMemberUserIds,
  }) async {
    _groups.add(group);
    await _databaseService.saveGroup(group);

    // Update each student in state and database
    for (var studentId in studentMemberUserIds) {
      final idx = _allUsers.indexWhere((u) => u.id == studentId);
      if (idx != -1 && _allUsers[idx] is Student) {
        final currentStudent = _allUsers[idx] as Student;
        // Defense-in-depth: if student is already in another group, do not reassign
        if (currentStudent.groupId.trim().isNotEmpty && currentStudent.groupId != group.id) {
          debugPrint("Cannot reassign student ${currentStudent.name} ($studentId): already assigned to group ${currentStudent.groupId}");
          continue;
        }
        final updatedStudent = currentStudent.copyWith(
          groupId: group.id,
          capstoneTitle: group.title,
        );
        _allUsers[idx] = updatedStudent;
        if (_currentUser?.id == studentId) {
          _currentUser = updatedStudent;
        }

        if (_databaseService is FirebaseDatabaseService) {
          await _databaseService.updateStudentGroup(
            studentId: studentId,
            groupId: group.id,
            capstoneTitle: group.title,
          );
        }
      }
    }

    notifyListeners();
  }

  void markNotificationAsRead(String notifId) {
    final notif = _notifications.firstWhere((n) => n.id == notifId);
    notif.markAsRead();
    _databaseService.saveNotification(notif);
    notifyListeners();
  }

  void markAllNotificationsAsRead() {
    for (var n in userNotifications) {
      n.markAsRead();
      _databaseService.saveNotification(n);
    }
    notifyListeners();
  }
}
