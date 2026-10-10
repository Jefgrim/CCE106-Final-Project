// =============================================================================
// FILE: test/widget_test.dart
// Unit & Widget Tests for CapSync: OOP Architecture, Database, & Authentication
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capsync/main.dart';
import 'package:capsync/models/user.dart';
import 'package:capsync/models/time_slot.dart';
import 'package:capsync/models/consultation_booking.dart';
import 'package:capsync/models/capstone_group.dart';
import 'package:capsync/services/booking_service.dart';
import 'package:capsync/services/database/persistent_database_service.dart';
import 'package:capsync/services/database/firebase_config.dart';
import 'package:capsync/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:capsync/screens/auth/login_screen.dart';
import 'package:capsync/screens/auth/register_screen.dart';
import 'package:capsync/screens/auth/email_verification_screen.dart';
import 'package:capsync/services/email_otp_service.dart';
import 'package:capsync/screens/main_screen.dart';
import 'package:capsync/screens/profile_screen.dart';
import 'package:capsync/screens/splash_screen.dart';
import 'package:capsync/screens/coordinator_screen.dart';
import 'package:capsync/screens/faculty_schedule_screen.dart';
import 'package:capsync/services/schedule_service.dart';
import 'package:capsync/state/app_state.dart';
import 'package:capsync/services/diagnostics/network_diagnostics_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. OOP Principles & Models', () {
    test('Polymorphism: getRoleDescription behaves differently across User subclasses', () {
      final student = Student(
        id: 's1',
        name: 'Juan',
        email: 'juan@umindanao.edu.ph',
        avatarInitials: 'JD',
        studentIdNumber: 'UM-2022-8492',
        groupId: '',
        capstoneTitle: 'CapSync',
        yearLevel: '4th Year BSIT',
      );

      final faculty = FacultyMember(
        id: 'f1',
        name: 'Engr. Santos',
        email: 'santos@umindanao.edu.ph',
        avatarInitials: 'RS',
        facultyIdNumber: 'FAC-0142',
        academicRank: 'Associate Professor',
        consultationRoom: 'Room 304',
        expertiseTags: ['Mobile Dev'],
      );

      final coordinator = Coordinator(
        id: 'c1',
        name: 'Prof. Rivera',
        email: 'rivera@umindanao.edu.ph',
        avatarInitials: 'MR',
        officeLocation: 'Dean\'s Office',
      );

      expect(student.getRoleDescription(), contains('Capstone Student'));
      expect(faculty.getRoleDescription(), contains('Faculty Adviser & Panelist'));
      expect(coordinator.getRoleDescription(), contains('Capstone Coordinator'));
    });

    test('Encapsulation: TimeSlot state mutations and database serialization', () {
      final slot = TimeSlot(
        id: 'slot-test-1',
        facultyId: 'f1',
        date: DateTime(2026, 9, 15),
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
      );

      expect(slot.isBooked, isFalse);
      expect(slot.bookSlot('grp-04', 'book-01'), isTrue);
      expect(slot.isBooked, isTrue);

      // Verify serialization round-trip
      final json = slot.toJson();
      final restored = TimeSlot.fromJson(json);
      expect(restored.id, slot.id);
      expect(restored.isBooked, isTrue);
      expect(restored.bookedByGroupId, 'grp-04');
    });

    test('Database Serialization: ConsultationBooking and CapstoneGroup', () {
      final group = CapstoneGroup(
        id: 'grp-01',
        groupNumber: 'Group 1',
        title: 'Smart Campus',
        studentMembers: ['Alice', 'Bob'],
        adviserId: 'fac-01',
        leadPanelistId: 'fac-02',
        panelistIds: ['fac-03'],
      );

      final json = group.toJson();
      final restored = CapstoneGroup.fromJson(json);
      expect(restored.id, 'grp-01');
      expect(restored.adviserId, 'fac-01');
    });
  });

  group('2. Double-Booking Prevention Tests', () {
    test('BookingService rejects reservation if slot is already occupied', () {
      final service = BookingService();
      final slot = TimeSlot(
        id: 'slot-101',
        facultyId: 'fac-01',
        date: DateTime(2026, 9, 20),
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        isBooked: true,
      );

      final result = service.validateAndBook(
        slot: slot,
        existingBookings: [],
        studentId: 'stud-01',
        studentName: 'Juan Dela Cruz',
        groupId: 'grp-04',
        capstoneTitle: 'CapSync',
        facultyId: 'fac-01',
        facultyName: 'Engr. Santos',
        type: ConsultationType.prototypeDemo,
        agenda: 'Review prototype architecture and double booking mechanism',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Double-booking prevented'));
    });
  });

  group('3. Persistent Database Service Tests', () {
    test('PersistentDatabaseService registers, persists, and authenticates without demo data', () async {
      final db = PersistentDatabaseService();
      await db.init();

      // Starts completely empty (no mock data seeded)
      final initialUsers = await db.getAllUsers();
      expect(initialUsers.isEmpty, isTrue);

      final student = Student(
        id: 'stud-101',
        name: 'Maria Clara Santos',
        email: 'maria.santos@umindanao.edu.ph',
        avatarInitials: 'MS',
        studentIdNumber: 'UM-2022-8493',
        groupId: '',
        capstoneTitle: 'RoutePump',
        yearLevel: '4th Year BSIT',
      );

      final registered = await db.registerUser(student, 'MySecretPass123!');
      expect(registered, isTrue);

      // Authenticate with real credentials
      final authUser = await db.authenticate('maria.santos@umindanao.edu.ph', 'MySecretPass123!');
      expect(authUser, isNotNull);
      expect(authUser!.name, 'Maria Clara Santos');
      expect(authUser.role, UserRole.student);

      // Wrong password fails
      final wrongAuth = await db.authenticate('maria.santos@umindanao.edu.ph', 'wrong-pass');
      expect(wrongAuth, isNull);
    });
  });

  group('4. Authentication & UI Smoke Test', () {
    testWidgets('CapSync renders Splash Screen initially with logo and loading animation', (WidgetTester tester) async {
      await tester.pumpWidget(const CapSyncApp());
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LoginScreen renders clean inputs and no demo buttons', (WidgetTester tester) async {
      final appState = AppState();
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(appState: appState),
      ));
      await tester.pumpAndSettle();

      // Verify CapSync branding and official tagline on Login Screen
      expect(find.text('Connect • Consult • Complete'), findsOneWidget);
      expect(find.text('University of Mindanao • IT College'), findsOneWidget);
      expect(find.text('Account Sign In'), findsOneWidget);
      expect(find.text('Institutional Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register Here'), findsOneWidget);

      // Verify quick demo buttons are completely removed
      expect(find.text('Quick Demo Sign-In (1-Tap for Evaluation)'), findsNothing);
    });

    testWidgets('Completing registration navigates to OTP verification and then to MainScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(MaterialApp(
        home: RegisterScreen(appState: appState),
      ));
      await tester.pumpAndSettle();

      // Fill out registration form for a new student
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Carlos Mendoza');
      await tester.enterText(find.widgetWithText(TextFormField, 'UM Institutional Email'), 'carlos.mendoza@umindanao.edu.ph');
      await tester.enterText(find.widgetWithText(TextFormField, 'Student ID Number'), 'UM-2022-9999');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

      // Tap Complete Registration to initiate email verification
      final registerBtn = find.text('Complete Registration');
      await tester.ensureVisible(registerBtn);
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      // Verify navigation to EmailVerificationScreen
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(find.text('carlos.mendoza@umindanao.edu.ph'), findsOneWidget);

      // Tap "I Have Verified My Email"
      final verifyBtn = find.text('I Have Verified My Email');
      await tester.ensureVisible(verifyBtn);
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      // Verify navigation to MainScreen
      expect(find.byType(MainScreen), findsOneWidget);
      expect(appState.isAuthenticated, isTrue);
      expect(appState.currentUser?.name, 'Carlos Mendoza');
      // Verify student starts with no hardcoded group
      expect((appState.currentUser as Student).groupId, isEmpty);
    });
  });

  group('5. Environment Configuration (.env) Tests', () {
    tearDown(() {
      dotenv.clean();
    });

    test('FirebaseConfig dynamically loads credentials from dotenv', () {
      dotenv.loadFromString(envString: '''
FIREBASE_API_KEY=test-api-key-from-env
FIREBASE_APP_ID=test-app-id-987
FIREBASE_MESSAGING_SENDER_ID=987654321
FIREBASE_PROJECT_ID=custom-test-project
FIREBASE_AUTH_DOMAIN=custom-test-project.firebaseapp.com
''');

      expect(FirebaseConfig.apiKey, equals('test-api-key-from-env'));
      expect(FirebaseConfig.appId, equals('test-app-id-987'));
      expect(FirebaseConfig.messagingSenderId, equals('987654321'));
      expect(FirebaseConfig.projectId, equals('custom-test-project'));
      expect(FirebaseConfig.authDomain, equals('custom-test-project.firebaseapp.com'));
    });

    test('FirebaseConfig returns safe defaults when dotenv is cleared', () {
      dotenv.clean();
      expect(FirebaseConfig.apiKey, equals(''));
      expect(FirebaseConfig.projectId, equals('capsync-813b5'));
      expect(FirebaseConfig.authDomain, equals('capsync-813b5.firebaseapp.com'));
    });

    test('DefaultFirebaseOptions dynamically resolves from environment variables', () {
      dotenv.loadFromString(envString: '''
FIREBASE_API_KEY=dynamic-opt-key
FIREBASE_APP_ID=dynamic-app-id
FIREBASE_MESSAGING_SENDER_ID=777888999
FIREBASE_PROJECT_ID=capsync-813b5
FIREBASE_AUTH_DOMAIN=capsync-813b5.firebaseapp.com
''');

      final webOptions = DefaultFirebaseOptions.web;
      expect(webOptions.apiKey, equals('dynamic-opt-key'));
      expect(webOptions.appId, equals('dynamic-app-id'));
      expect(webOptions.projectId, equals('capsync-813b5'));
      expect(webOptions.storageBucket, isNull);

      final androidOptions = DefaultFirebaseOptions.android;
      expect(androidOptions.apiKey, equals('dynamic-opt-key'));
      expect(androidOptions.projectId, equals('capsync-813b5'));
      expect(androidOptions.storageBucket, isNull);

      final currentPlatformOptions = DefaultFirebaseOptions.currentPlatform;
      expect(currentPlatformOptions.projectId, equals('capsync-813b5'));
      expect(currentPlatformOptions.storageBucket, isNull);
    });
  });

  group('6. Form Cleanliness & Student Search UX Tests', () {
    test('Student model handles empty assignment cleanly without hardcoded fallbacks', () {
      final s = Student(
        id: 'st-01',
        name: 'Jefgrim Alvar',
        email: 'j.alvar@umindanao.edu.ph',
        avatarInitials: 'JA',
        studentIdNumber: '488699',
        groupId: '',
        capstoneTitle: '',
      );
      expect(s.groupId, isEmpty);
      expect(s.capstoneTitle, isEmpty);
      expect(s.toJson()['groupId'], isEmpty);
    });

    test('Student filtering by query works for name, ID, and email', () {
      final students = [
        Student(id: 's1', name: 'Jefgrim Alvar', email: 'j.alvar.488699@umindanao.edu.ph', avatarInitials: 'JA', studentIdNumber: '488699', groupId: '', capstoneTitle: ''),
        Student(id: 's2', name: 'Qiim Yasser S. Cagalawan', email: 'q.cagalawan.524171@umindanao.edu.ph', avatarInitials: 'QC', studentIdNumber: '524171', groupId: '', capstoneTitle: ''),
      ];

      // Query by ID
      final byId = students.where((s) => s.studentIdNumber.contains('488699')).toList();
      expect(byId.length, 1);
      expect(byId.first.name, 'Jefgrim Alvar');

      // Query by partial name
      final byName = students.where((s) => s.name.toLowerCase().contains('yasser')).toList();
      expect(byName.length, 1);
      expect(byName.first.studentIdNumber, '524171');
    });
  });

  group('7. Profile Management & Password Change Tests', () {
    testWidgets('LoginScreen renders Forgot Password button and dialog', (WidgetTester tester) async {
      final appState = AppState();
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(appState: appState),
      ));
      await tester.pumpAndSettle();

      final forgotBtn = find.text('Forgot Password?');
      expect(forgotBtn, findsOneWidget);

      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    test('PersistentDatabaseService updates password and profile', () async {
      SharedPreferences.setMockInitialValues({});
      final db = PersistentDatabaseService();
      await db.init();

      final teacher = FacultyMember(
        id: 'f1',
        name: 'Prof. Test',
        email: 'prof.test@umindanao.edu.ph',
        avatarInitials: 'PT',
        facultyIdNumber: 'FAC-999',
        consultationRoom: 'Room 101',
      );

      final registered = await db.registerUser(teacher, 'tempPass123');
      expect(registered, isTrue);

      // Verify authentication with initial password
      final auth1 = await db.authenticate('prof.test@umindanao.edu.ph', 'tempPass123');
      expect(auth1, isNotNull);

      // Faculty changes password
      final changed = await db.updatePassword('prof.test@umindanao.edu.ph', 'permanentPass2026');
      expect(changed, isTrue);

      // Old password fails, new password succeeds
      final oldAuth = await db.authenticate('prof.test@umindanao.edu.ph', 'tempPass123');
      expect(oldAuth, isNull);

      final newAuth = await db.authenticate('prof.test@umindanao.edu.ph', 'permanentPass2026');
      expect(newAuth, isNotNull);

      // Update Profile Details (Room and Tags)
      final updatedTeacher = FacultyMember(
        id: 'f1',
        name: 'Prof. Test Updated',
        email: 'prof.test@umindanao.edu.ph',
        avatarInitials: 'PU',
        facultyIdNumber: 'FAC-999',
        consultationRoom: 'Room 505',
        expertiseTags: ['AI Systems'],
      );
      final profileSaved = await db.updateUserProfile(updatedTeacher);
      expect(profileSaved, isTrue);

      final fetchedUsers = await db.getAllUsers();
      final userInDb = fetchedUsers.firstWhere((u) => u.id == 'f1') as FacultyMember;
      expect(userInDb.name, 'Prof. Test Updated');
      expect(userInDb.consultationRoom, 'Room 505');
      expect(userInDb.expertiseTags, contains('AI Systems'));
    });

    testWidgets('ProfileScreen renders user profile and password change cards', (WidgetTester tester) async {
      final appState = AppState();
      final student = Student(
        id: 'st-test',
        name: 'Elena Gilbert',
        email: 'elena@umindanao.edu.ph',
        avatarInitials: 'EG',
        studentIdNumber: '112233',
        groupId: '',
        capstoneTitle: 'SafeCampus IoT',
      );
      appState.setCurrentUserForTesting(student);

      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(appState: appState),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Profile Management'), findsOneWidget);
      expect(find.text('Elena Gilbert'), findsNWidgets(2));
      expect(find.text('Profile Information'), findsOneWidget);
      expect(find.text('Change Account Password'), findsOneWidget);
      expect(find.text('Save Profile Changes'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });
  });

  group('8. Multi-Panelist & Dialog Overflow Tests', () {
    test('CapstoneGroup and AppState support multiple panel members', () {
      final group = CapstoneGroup(
        id: 'grp-multi',
        groupNumber: 'Group 99',
        title: 'Multi Panelist Capstone',
        studentMembers: ['Student A', 'Student B'],
        adviserId: 'fac-01',
        leadPanelistId: 'fac-02',
        panelistIds: ['fac-03', 'fac-04', 'fac-05'],
      );

      expect(group.panelistIds.length, 3);
      expect(group.panelistIds, containsAll(['fac-03', 'fac-04', 'fac-05']));
      expect(group.allAssignedFacultyIds.length, 5);

      // Mutate panelists dynamically
      group.setPanelists(['fac-03', 'fac-06']);
      expect(group.panelistIds.length, 2);
      expect(group.panelistIds, contains('fac-06'));

      // Verify serialization round trip
      final json = group.toJson();
      final restored = CapstoneGroup.fromJson(json);
      expect(restored.panelistIds.length, 2);
      expect(restored.panelistIds, contains('fac-06'));
    });

    testWidgets('CoordinatorScreen renders dialog with Add Panel Member button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppState();
      await appState.initializeDatabase();

      final faculty = FacultyMember(
        id: 'f1',
        name: 'Engr. Santos',
        email: 'santos@umindanao.edu.ph',
        avatarInitials: 'RS',
        facultyIdNumber: 'FAC-101',
        academicRank: '',
        consultationRoom: 'Room 304',
        expertiseTags: [],
      );
      final coordinator = Coordinator(
        id: 'coord-1',
        name: 'Dean Smith',
        email: 'dean@umindanao.edu.ph',
        avatarInitials: 'DS',
        officeLocation: 'Dean Office',
      );
      appState.setUsersForTesting([faculty, coordinator]);
      appState.setCurrentUserForTesting(coordinator);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoordinatorScreen(appState: appState),
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Groups & Assignments tab
      final groupsTabFinder = find.text('Groups & Assignments');
      expect(groupsTabFinder, findsOneWidget);
      await tester.tap(groupsTabFinder);
      await tester.pumpAndSettle();

      // Tap "Create Capstone Group & Assign Faculty"
      final createGroupButtonFinder = find.text('Create Capstone Group & Assign Faculty');
      expect(createGroupButtonFinder, findsOneWidget);
      await tester.tap(createGroupButtonFinder);
      await tester.pumpAndSettle();

      // Verify dialog renders
      expect(find.text('Create Capstone Group'), findsOneWidget);
      expect(find.text('Assigned Adviser'), findsOneWidget);
      expect(find.text('Lead Panelist / Chair'), findsOneWidget);

      // Verify multiple panel members section exists
      await tester.ensureVisible(find.text('Add Panel Member'));
      expect(find.text('Add Panel Member'), findsOneWidget);
      expect(find.text('Panel Member 1'), findsOneWidget);

      // Tap "Add Panel Member" to add a second panelist
      await tester.tap(find.text('Add Panel Member'));
      await tester.pumpAndSettle();

      // Now Panel Member 2 should also be present!
      await tester.ensureVisible(find.text('Panel Member 2'));
      expect(find.text('Panel Member 2'), findsOneWidget);
    });
  });

  group('9. Faculty Slot Availability & Validation Tests', () {
    test('ScheduleService rejects adding a slot in the past', () {
      final scheduleService = ScheduleService();
      final slots = <TimeSlot>[];
      final targetDate = DateTime(2026, 9, 20);
      final simulatedNow = DateTime(2026, 9, 20, 10, 15); // 10:15 AM

      // 09:00 AM is in the past relative to 10:15 AM
      final pastSlot = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(pastSlot, isNull);
      expect(slots.isEmpty, isTrue);

      // 10:30 AM is in the future relative to 10:15 AM
      final futureSlot = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '10:30 AM',
        endTime: '11:30 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(futureSlot, isNotNull);
      expect(slots.length, 1);
    });

    test('ScheduleService rejects slots under 30 minutes duration', () {
      final scheduleService = ScheduleService();
      final slots = <TimeSlot>[];
      final targetDate = DateTime(2026, 9, 25);
      final simulatedNow = DateTime(2026, 9, 20);

      // Same start and end time (0 minutes)
      final zeroMinSlot = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:00 AM',
        endTime: '09:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(zeroMinSlot, isNull);

      // Exactly 30 minutes is allowed
      final thirtyMinSlot = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:00 AM',
        endTime: '09:30 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(thirtyMinSlot, isNotNull);
    });

    test('ScheduleService rejects overlapping and duplicate free slots', () {
      final scheduleService = ScheduleService();
      final targetDate = DateTime(2026, 9, 25);
      final simulatedNow = DateTime(2026, 9, 20);

      final existingSlot = TimeSlot(
        id: 'slot-1',
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
      );
      final slots = <TimeSlot>[existingSlot];

      // Attempt 1: Exact duplicate start time
      final duplicateStart = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:00 AM',
        endTime: '09:30 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(duplicateStart, isNull);

      // Attempt 2: Overlaps existing slot (09:30 AM - 10:30 AM overlaps 09:00 AM - 10:00 AM)
      final overlapping = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:30 AM',
        endTime: '10:30 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(overlapping, isNull);

      // Non-overlapping slot after 10:00 AM is permitted
      final validNonOverlap = scheduleService.addFacultySlot(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '10:00 AM',
        endTime: '10:30 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 304',
        now: simulatedNow,
      );
      expect(validNonOverlap, isNotNull);
      expect(slots.length, 2);
    });

    test('getAvailableStartTimes and getAvailableEndTimes filter unopened slots correctly', () {
      final scheduleService = ScheduleService();
      final targetDate = DateTime(2026, 9, 20);
      final simulatedNow = DateTime(2026, 9, 20, 09, 15); // 09:15 AM

      // Suppose 10:00 AM - 11:00 AM is already opened
      final slots = <TimeSlot>[
        TimeSlot(
          id: 'slot-1',
          facultyId: 'fac-1',
          date: targetDate,
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          mode: ConsultationMode.inPerson,
          locationOrLink: 'Room 304',
        ),
      ];

      final availableStarts = scheduleService.getAvailableStartTimes(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        now: simulatedNow,
      );

      // 08:00 AM, 08:30 AM, 09:00 AM are past -> excluded
      expect(availableStarts, isNot(contains('08:00 AM')));
      expect(availableStarts, isNot(contains('08:30 AM')));
      expect(availableStarts, isNot(contains('09:00 AM')));

      // 09:30 AM is future and has 30 mins before 10:00 AM -> included
      expect(availableStarts, contains('09:30 AM'));

      // 10:00 AM and 10:30 AM are already opened -> excluded
      expect(availableStarts, isNot(contains('10:00 AM')));
      expect(availableStarts, isNot(contains('10:30 AM')));

      // 11:00 AM onwards is free -> included
      expect(availableStarts, contains('11:00 AM'));

      // Available end times for 09:30 AM: only 10:00 AM (because next slot begins at 10:00 AM)
      final endTimesFor930 = scheduleService.getAvailableEndTimes(
        allSlots: slots,
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '09:30 AM',
      );
      expect(endTimesFor930, equals(['10:00 AM']));
    });

    testWidgets('FacultyScheduleScreen renders slot dialog with smart unopened times', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppState();
      await appState.initializeDatabase();

      final faculty = FacultyMember(
        id: 'f-test-1',
        name: 'Dr. Alan Turing',
        email: 'turing@umindanao.edu.ph',
        avatarInitials: 'AT',
        facultyIdNumber: 'FAC-701',
        academicRank: '',
        consultationRoom: 'Room 201',
        expertiseTags: ['Algorithms'],
      );

      appState.setUsersForTesting([faculty]);
      appState.setCurrentUserForTesting(faculty);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FacultyScheduleScreen(appState: appState),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap "Add Slot" button
      final openSlotBtnFinder = find.text('Add Slot');
      expect(openSlotBtnFinder, findsOneWidget);
      await tester.tap(openSlotBtnFinder);
      await tester.pumpAndSettle();

      // Verify dialog is rendered with "Open Consultation Slot"
      expect(find.text('Open Consultation Slot'), findsOneWidget);
      expect(find.text('Consultation Mode:'), findsOneWidget);
      expect(find.text('Room Location:'), findsOneWidget);
      expect(find.text('Publish Slot'), findsOneWidget);
    });
  });

  group('10. Daily Booking Limit, Past Booking Exclusion & Adviser Note Notification Tests', () {
    test('BookingService enforces single booking per day rule for each group', () {
      final service = BookingService();
      final targetDate = DateTime.now().add(const Duration(days: 2));

      final slot1 = TimeSlot(
        id: 'slot-m1',
        facultyId: 'fac-1',
        date: targetDate,
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Lab 1',
      );

      final slot2 = TimeSlot(
        id: 'slot-m2',
        facultyId: 'fac-2',
        date: targetDate,
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        mode: ConsultationMode.online,
        locationOrLink: 'https://meet.google.com/test',
      );

      final slotNextDay = TimeSlot(
        id: 'slot-m3',
        facultyId: 'fac-2',
        date: targetDate.add(const Duration(days: 1)),
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        mode: ConsultationMode.online,
        locationOrLink: 'https://meet.google.com/test2',
      );

      // 1. Group 1 books morning slot -> Succeeds
      final result1 = service.validateAndBook(
        slot: slot1,
        existingBookings: [],
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-10',
        capstoneTitle: 'AI Capstone',
        facultyId: 'fac-1',
        facultyName: 'Prof. Smith',
        type: ConsultationType.prototypeDemo,
        agenda: 'Initial consultation on methodology',
      );
      expect(result1.isSuccess, isTrue);

      // 2. Group 1 attempts to book afternoon slot ON THE SAME DAY -> Rejection with Daily Limit message
      final result2 = service.validateAndBook(
        slot: slot2,
        existingBookings: [result1.booking!],
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-10',
        capstoneTitle: 'AI Capstone',
        facultyId: 'fac-2',
        facultyName: 'Prof. Davis',
        type: ConsultationType.manuscriptReview,
        agenda: 'Panel consultation on methodology',
      );
      expect(result2.isSuccess, isFalse);
      expect(result2.message, contains('Daily limit reached'));

      // 3. Different group (Group 2) CAN book the afternoon slot on that same day
      final resultGroup2 = service.validateAndBook(
        slot: slot2,
        existingBookings: [result1.booking!],
        studentId: 'stud-2',
        studentName: 'Bob',
        groupId: 'grp-20',
        capstoneTitle: 'CyberSec Capstone',
        facultyId: 'fac-2',
        facultyName: 'Prof. Davis',
        type: ConsultationType.manuscriptReview,
        agenda: 'Discussion on system testing',
      );
      expect(resultGroup2.isSuccess, isTrue);

      // 4. Group 1 CAN book on the next day
      final resultNextDay = service.validateAndBook(
        slot: slotNextDay,
        existingBookings: [result1.booking!, resultGroup2.booking!],
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-10',
        capstoneTitle: 'AI Capstone',
        facultyId: 'fac-2',
        facultyName: 'Prof. Davis',
        type: ConsultationType.prototypeDemo,
        agenda: 'Next day follow up consultation',
      );
      expect(resultNextDay.isSuccess, isTrue);
    });

    test('ConsultationBooking filters past bookings from active view', () {
      final now = DateTime(2026, 9, 21, 14, 0); // 2:00 PM

      final pastBookingYesterday = ConsultationBooking(
        id: 'b-past-1',
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-1',
        capstoneTitle: 'Project Alpha',
        facultyId: 'fac-1',
        facultyName: 'Prof. X',
        timeSlotId: 'ts-1',
        date: DateTime(2026, 9, 20),
        timeRange: '10:00 AM - 11:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
        type: ConsultationType.prototypeDemo,
        agenda: 'Sprint review for prototype',
        status: BookingStatus.confirmed,
      );

      final pastBookingEarlierToday = ConsultationBooking(
        id: 'b-past-2',
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-1',
        capstoneTitle: 'Project Alpha',
        facultyId: 'fac-1',
        facultyName: 'Prof. X',
        timeSlotId: 'ts-2',
        date: DateTime(2026, 9, 21),
        timeRange: '08:00 AM - 09:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
        type: ConsultationType.prototypeDemo,
        agenda: 'Early morning review',
        status: BookingStatus.confirmed,
      );

      final upcomingBookingLaterToday = ConsultationBooking(
        id: 'b-upcoming-1',
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-1',
        capstoneTitle: 'Project Alpha',
        facultyId: 'fac-1',
        facultyName: 'Prof. X',
        timeSlotId: 'ts-3',
        date: DateTime(2026, 9, 21),
        timeRange: '03:00 PM - 04:00 PM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
        type: ConsultationType.prototypeDemo,
        agenda: 'Late afternoon review',
        status: BookingStatus.confirmed,
      );

      final upcomingBookingTomorrow = ConsultationBooking(
        id: 'b-upcoming-2',
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-1',
        capstoneTitle: 'Project Alpha',
        facultyId: 'fac-1',
        facultyName: 'Prof. X',
        timeSlotId: 'ts-4',
        date: DateTime(2026, 9, 22),
        timeRange: '09:00 AM - 10:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
        type: ConsultationType.prototypeDemo,
        agenda: 'Tomorrow consultation',
        status: BookingStatus.confirmed,
      );

      // Test isPast()
      expect(pastBookingYesterday.isPast(now), isTrue);
      expect(pastBookingEarlierToday.isPast(now), isTrue);
      expect(upcomingBookingLaterToday.isPast(now), isFalse);
      expect(upcomingBookingTomorrow.isPast(now), isFalse);

      // Test displayStatus
      expect(pastBookingYesterday.getDisplayStatus(now), equals('PAST / CONCLUDED'));
      expect(pastBookingEarlierToday.getDisplayStatus(now), equals('PAST / CONCLUDED'));
      expect(upcomingBookingTomorrow.getDisplayStatus(now), equals('CONFIRMED'));
    });

    test('AppState.addBookingNote sends Adviser Added a Note notification and not Consultation Approved', () {
      final appState = AppState();
      final student = Student(
        id: 'stud-99',
        name: 'Maria Santos',
        email: 'msantos@umindanao.edu.ph',
        avatarInitials: 'MS',
        studentIdNumber: 'UM-999',
        groupId: 'grp-55',
        capstoneTitle: 'IoT Flood Sensor',
      );
      final faculty = FacultyMember(
        id: 'fac-99',
        name: 'Engr. Cruz',
        email: 'cruz@umindanao.edu.ph',
        avatarInitials: 'EC',
        facultyIdNumber: 'FAC-99',
        academicRank: '',
        consultationRoom: 'Room 401',
        expertiseTags: ['IoT'],
      );

      appState.setUsersForTesting([student, faculty]);
      appState.setCurrentUserForTesting(faculty);

      final booking = ConsultationBooking(
        id: 'b-note-1',
        studentId: student.id,
        studentName: student.name,
        groupId: student.groupId,
        capstoneTitle: student.capstoneTitle,
        facultyId: faculty.id,
        facultyName: faculty.name,
        timeSlotId: 'ts-99',
        date: DateTime(2026, 9, 25),
        timeRange: '10:00 AM - 11:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 401',
        type: ConsultationType.prototypeDemo,
        agenda: 'Review sensor wiring schematic',
        status: BookingStatus.confirmed,
      );

      // Adviser adds a note
      appState.addBookingNote(booking, 'Please bring the ESP32 hardware and Chapter 3 draft.');

      // Verify booking note was saved
      expect(booking.facultyNotes, equals('Please bring the ESP32 hardware and Chapter 3 draft.'));

      // Verify notification title is "Adviser Added a Note" and NOT "Consultation Approved"
      final notifs = appState.notifications;
      expect(notifs.isNotEmpty, isTrue);
      final noteNotif = notifs.last;
      expect(noteNotif.title, equals('Adviser Added a Note'));
      expect(noteNotif.type.name, equals('noteAdded'));
      expect(noteNotif.message, contains('Please bring the ESP32 hardware'));
    });
  });

  group('11. Network Diagnostics & Enhanced Auth Error Reporting Tests', () {
    test('NetworkDiagnosticsService.maskKey hides sensitive parts of credentials', () {
      expect(NetworkDiagnosticsService.maskKey(''), equals('(empty)'));
      expect(NetworkDiagnosticsService.maskKey('12345'), equals('123***'));
      expect(
        NetworkDiagnosticsService.maskKey('AIzaSyBT_agnDiPAd3J7qRLu-UHcjDt8vPO3snU'),
        equals('AIzaSy...3snU'),
      );
    });

    test('NetworkDiagnosticsService generates comprehensive report containing system info', () async {
      final report = await NetworkDiagnosticsService.runFullDiagnosticReport(
        attemptedEmail: 'test.student@umindanao.edu.ph',
        sdkPhaseStatus: 'TimeoutException: 5s timeout',
        restPhaseStatus: 'HTTP 400: INVALID_LOGIN_CREDENTIALS',
        lastErrorDescription: 'Incorrect password or email.',
      );

      expect(report, contains('CapSync Connection Diagnostic Report'));
      expect(report, contains('test.student@umindanao.edu.ph'));
      expect(report, contains('Target Project ID: capsync-813b5'));
      expect(report, contains('General Internet Connectivity Probe'));
      expect(report, contains('Firebase Auth REST Endpoint Probe'));
      expect(report, contains('Cloud Firestore REST Endpoint Probe'));
      expect(report, contains('Automated Diagnosis'));
    });

    test('AppState exposes lastLoginDiagnostics and runConnectionDiagnostics', () async {
      final appState = AppState();
      expect(appState.lastLoginDiagnostics, isNull);

      final diagReport = await appState.runConnectionDiagnostics(email: 'user@umindanao.edu.ph');
      expect(diagReport, isNotEmpty);
      expect(diagReport, contains('CapSync Connection Diagnostic Report'));
    });
  });

  group('12. Session Persistence & Slot Availability Notification Tests', () {
    test('PersistentDatabaseService saves, retrieves, and clears session user ID', () async {
      final db = PersistentDatabaseService();
      await db.init();

      await db.saveSessionUserId('user-persisted-123');
      final saved = await db.getSavedSessionUserId();
      expect(saved, equals('user-persisted-123'));

      await db.clearSession();
      final cleared = await db.getSavedSessionUserId();
      expect(cleared, isNull);
    });

    test('AppState.addFacultySlot notifies assigned students under the faculty member', () {
      final appState = AppState();

      final faculty = FacultyMember(
        id: 'fac-prof-1',
        name: 'Dr. Santos',
        email: 'dr.santos@umindanao.edu.ph',
        avatarInitials: 'DS',
        facultyIdNumber: 'UM-FAC-001',
        consultationRoom: 'Lab 301',
        expertiseTags: ['AI', 'Mobile'],
      );

      final studentUnderFaculty = Student(
        id: 'stud-assigned-1',
        name: 'Student Advisee',
        email: 'advisee@umindanao.edu.ph',
        avatarInitials: 'SA',
        studentIdNumber: 'UM-2022-001',
        groupId: 'grp-test-1',
        capstoneTitle: 'Smart Campus System',
      );

      final studentOther = Student(
        id: 'stud-other-2',
        name: 'Student Other Group',
        email: 'other@umindanao.edu.ph',
        avatarInitials: 'SO',
        studentIdNumber: 'UM-2022-002',
        groupId: 'grp-test-2',
        capstoneTitle: 'Other Capstone',
      );

      appState.setUsersForTesting([faculty, studentUnderFaculty, studentOther]);

      // Create groups
      final groupUnder = CapstoneGroup(
        id: 'grp-test-1',
        groupNumber: 'Group 1',
        title: 'Smart Campus System',
        studentMembers: [studentUnderFaculty.id],
        adviserId: faculty.id,
        leadPanelistId: 'other-fac',
        panelistIds: [],
      );

      final groupOther = CapstoneGroup(
        id: 'grp-test-2',
        groupNumber: 'Group 2',
        title: 'Other Capstone',
        studentMembers: [studentOther.id],
        adviserId: 'different-fac',
        leadPanelistId: 'other-fac-2',
        panelistIds: [],
      );

      // Add group into state via testing helper or createCapstoneGroup
      appState.createCapstoneGroup(
        group: groupUnder,
        studentMemberUserIds: [studentUnderFaculty.id],
      );
      appState.createCapstoneGroup(
        group: groupOther,
        studentMemberUserIds: [studentOther.id],
      );

      appState.setCurrentUserForTesting(faculty);

      final slotDate = DateTime(2026, 10, 15);
      final added = appState.addFacultySlot(
        date: slotDate,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Lab 301',
        now: DateTime(2026, 10, 1, 8, 0),
      );

      expect(added, isTrue);

      // Check notifications
      final notifs = appState.notifications;
      expect(notifs.isNotEmpty, isTrue);

      final slotNotif = notifs.firstWhere(
        (n) => n.recipientUserId == studentUnderFaculty.id,
      );
      expect(slotNotif.title, equals('New Consultation Slot Available'));
      expect(slotNotif.type.name, equals('slotAdded'));
      expect(slotNotif.message, contains('Dr. Santos opened a consultation slot'));
      expect(slotNotif.message, contains('10:00 AM - 11:00 AM'));

      // Ensure student from the other group did NOT receive this notification
      final otherNotifs = notifs.where((n) => n.recipientUserId == studentOther.id).toList();
      expect(otherNotifs.isEmpty, isTrue);
    });
  });

  group('13. Institutional Email Verification (Firebase Auth Link) Tests', () {
    test('AppState.sendEmailVerification dispatches verification request', () async {
      final appState = AppState();
      final sent = await appState.sendEmailVerification(email: 'juan.delacruz@umindanao.edu.ph');
      expect(sent, isTrue);
    });

    testWidgets('EmailVerificationScreen displays target email and instructions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      final testStudent = Student(
        id: 'test-s1',
        name: 'Ana Santos',
        email: 'ana.santos@umindanao.edu.ph',
        avatarInitials: 'AS',
        studentIdNumber: 'UM-2022-7777',
        groupId: '',
        capstoneTitle: 'Smart Campus',
      );

      await tester.pumpWidget(MaterialApp(
        home: EmailVerificationScreen(
          appState: appState,
          user: testStudent,
          password: 'password123',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify email address appears on screen
      expect(find.text('ana.santos@umindanao.edu.ph'), findsOneWidget);
      expect(find.text('Verify Your Institutional Email'), findsOneWidget);
      expect(find.text('I Have Verified My Email'), findsOneWidget);

      // Tap "I Have Verified My Email"
      final verifyBtn = find.text('I Have Verified My Email');
      await tester.ensureVisible(verifyBtn);
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      // Should complete activation and transition to MainScreen
      expect(find.byType(MainScreen), findsOneWidget);
      expect(appState.isAuthenticated, isTrue);
      expect(appState.currentUser?.email, equals('ana.santos@umindanao.edu.ph'));
    });

    test('EmailOtpService strictly enforces @umindanao.edu.ph domain restriction', () {
      expect(EmailOtpService.isAllowedDomain('student@gmail.com'), isFalse);
      expect(EmailOtpService.isAllowedDomain('student@yahoo.com'), isFalse);
      expect(EmailOtpService.isAllowedDomain('student@umindanao.edu'), isFalse);
      expect(EmailOtpService.isAllowedDomain('carlos.mendoza@umindanao.edu.ph'), isTrue);
    });

    testWidgets('RegisterScreen form rejects non-umindanao.edu.ph email addresses', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(MaterialApp(
        home: RegisterScreen(appState: appState),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Carlos Mendoza');
      await tester.enterText(find.widgetWithText(TextFormField, 'UM Institutional Email'), 'carlos@gmail.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Student ID Number'), 'UM-2022-9999');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

      final registerBtn = find.text('Complete Registration');
      await tester.ensureVisible(registerBtn);
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      // Form validation error should appear and NOT navigate to EmailVerificationScreen
      expect(find.textContaining('Only official @umindanao.edu.ph emails are permitted'), findsOneWidget);
      expect(find.byType(EmailVerificationScreen), findsNothing);
    });
  });

  group('14. Strict Available Slots & Past Exclusion Tests', () {
    test('TimeSlot.isPast and isAvailable correctly evaluate past, future, and booked states', () {
      final simNow = DateTime(2026, 9, 25, 11, 0); // 11:00 AM

      // Yesterday slot (unbooked)
      final slotYesterday = TimeSlot(
        id: 'ts-yest',
        facultyId: 'fac-1',
        date: DateTime(2026, 9, 24),
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
      );
      expect(slotYesterday.isPast(simNow), isTrue);
      expect(slotYesterday.isAvailable(simNow), isFalse);

      // Earlier today slot (unbooked, 08:00 AM)
      final slotEarlierToday = TimeSlot(
        id: 'ts-earlier',
        facultyId: 'fac-1',
        date: DateTime(2026, 9, 25),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
      );
      expect(slotEarlierToday.isPast(simNow), isTrue);
      expect(slotEarlierToday.isAvailable(simNow), isFalse);

      // Later today slot (unbooked, 02:00 PM)
      final slotLaterToday = TimeSlot(
        id: 'ts-later',
        facultyId: 'fac-1',
        date: DateTime(2026, 9, 25),
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
      );
      expect(slotLaterToday.isPast(simNow), isFalse);
      expect(slotLaterToday.isAvailable(simNow), isTrue);

      // Later today slot (booked, 03:00 PM)
      final slotBookedLaterToday = TimeSlot(
        id: 'ts-booked-later',
        facultyId: 'fac-1',
        date: DateTime(2026, 9, 25),
        startTime: '03:00 PM',
        endTime: '04:00 PM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
        isBooked: true,
      );
      expect(slotBookedLaterToday.isPast(simNow), isFalse);
      expect(slotBookedLaterToday.isAvailable(simNow), isFalse);

      // Tomorrow slot (unbooked)
      final slotTomorrow = TimeSlot(
        id: 'ts-tomorrow',
        facultyId: 'fac-1',
        date: DateTime(2026, 9, 26),
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
      );
      expect(slotTomorrow.isPast(simNow), isFalse);
      expect(slotTomorrow.isAvailable(simNow), isTrue);
    });

    test('AppState.getDashboardFilteredSlots strictly includes only available and non-past slots', () {
      final appState = AppState();
      final simNow = DateTime(2026, 9, 25, 11, 0); // 11:00 AM
      final targetDate = DateTime(2026, 9, 25);
      appState.setSelectedDate(targetDate);

      final faculty = FacultyMember(
        id: 'fac-test',
        name: 'Dr. Santos',
        email: 'dr.santos@umindanao.edu.ph',
        department: 'CS',
        avatarInitials: 'DS',
        facultyIdNumber: 'FAC-999',
        consultationRoom: 'Room 401',
      );
      final student = Student(
        id: 'stud-avail',
        name: 'Test Student',
        email: 'stud.avail@umindanao.edu.ph',
        avatarInitials: 'TS',
        studentIdNumber: '99999',
        groupId: 'grp-test',
        capstoneTitle: 'CapSync',
      );
      final group = CapstoneGroup(
        id: 'grp-test',
        groupNumber: 'Group Test',
        title: 'CapSync',
        studentMembers: [student.name],
        adviserId: faculty.id,
        leadPanelistId: faculty.id,
        panelistIds: [],
      );

      appState.setCurrentUserForTesting(student);
      appState.setUsersForTesting([faculty, student]);
      appState.setGroupsForTesting([group]);

      // Slot 1: Earlier today (08:00 AM) -> unbooked but past -> MUST BE EXCLUDED
      final pastSlot = TimeSlot(
        id: 's-past',
        facultyId: faculty.id,
        date: targetDate,
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 401',
      );

      // Slot 2: Later today (01:00 PM) -> booked -> MUST BE EXCLUDED
      final bookedSlot = TimeSlot(
        id: 's-booked',
        facultyId: faculty.id,
        date: targetDate,
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 401',
        isBooked: true,
      );

      // Slot 3: Later today (03:00 PM) -> unbooked and future -> MUST BE INCLUDED
      final validAvailableSlot = TimeSlot(
        id: 's-avail',
        facultyId: faculty.id,
        date: targetDate,
        startTime: '03:00 PM',
        endTime: '04:00 PM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 401',
      );

      appState.setSlotsForTesting([pastSlot, bookedSlot, validAvailableSlot]);

      final filtered = appState.getDashboardFilteredSlots(simNow);
      expect(filtered.length, 1);
      expect(filtered.first.id, equals('s-avail'));
    });

    test('BookingService rejects attempting to book a past consultation slot', () {
      final service = BookingService();
      final simNow = DateTime(2026, 9, 25, 11, 0);

      final pastSlot = TimeSlot(
        id: 'slot-expired',
        facultyId: 'fac-1',
        date: DateTime(2026, 9, 25),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        mode: ConsultationMode.inPerson,
        locationOrLink: 'Room 101',
      );

      final result = service.validateAndBook(
        slot: pastSlot,
        existingBookings: [],
        studentId: 'stud-1',
        studentName: 'Alice',
        groupId: 'grp-1',
        capstoneTitle: 'Project Alpha',
        facultyId: 'fac-1',
        facultyName: 'Prof. X',
        type: ConsultationType.prototypeDemo,
        agenda: 'Review sprint progress',
        now: simNow,
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('already passed'));
    });
  });
}



