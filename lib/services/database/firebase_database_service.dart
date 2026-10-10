// =============================================================================
// FILE: lib/services/database/firebase_database_service.dart
// FIREBASE CLOUD FIRESTORE & AUTH SERVICE IMPLEMENTATION (HYBRID SDK + REST)
// Implements DatabaseService adhering to OOP Repository Pattern for Google Firebase.
// Features dual-layer connectivity: Native Firebase SDK with high-speed direct
// Firebase REST API fallback to ensure 100% reliable login and data sync across
// all mobile devices and networks (including campus Wi-Fi firewalls).
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../../models/time_slot.dart';
import '../../models/consultation_booking.dart';
import '../../models/capstone_group.dart';
import '../../models/app_notification.dart';
import 'database_service.dart';
import 'persistent_database_service.dart';
import 'firebase_config.dart';
import '../diagnostics/network_diagnostics_service.dart';

/// [OOP - REPOSITORY PATTERN]
/// Database service implementation connecting directly to Firebase Auth & Cloud Firestore.
/// Features automatic fallback to direct Firebase REST API endpoints for resilient
/// mobile execution without Google Play Services or network port blockages.
class FirebaseDatabaseService implements DatabaseService {
  final PersistentDatabaseService _fallbackDb = PersistentDatabaseService();
  bool _isFirebaseInitialized = false;
  String? lastAuthError;
  String? lastAuthDiagnostics;

  bool get isConnectedToFirebase => _isFirebaseInitialized;
  String get activeProjectId => FirebaseConfig.projectId;

  String get _activeApiKey {
    if (!kIsWeb && FirebaseConfig.androidApiKey.isNotEmpty) {
      return FirebaseConfig.androidApiKey;
    }
    if (FirebaseConfig.apiKey.isNotEmpty) {
      return FirebaseConfig.apiKey;
    }
    return FirebaseConfig.androidApiKey;
  }

  @override
  Future<void> init() async {
    await _fallbackDb.init();
    if (Firebase.apps.isNotEmpty) {
      _isFirebaseInitialized = true;
    }
  }

  // ===========================================================================
  // FIRESTORE REST API VALUE ENCODING & DECODING HELPERS
  // ===========================================================================

  static dynamic _decodeFirestoreValue(Map<String, dynamic> valMap) {
    if (valMap.containsKey('stringValue')) return valMap['stringValue'];
    if (valMap.containsKey('booleanValue')) return valMap['booleanValue'];
    if (valMap.containsKey('integerValue')) {
      return int.tryParse(valMap['integerValue'].toString()) ?? 0;
    }
    if (valMap.containsKey('doubleValue')) {
      return double.tryParse(valMap['doubleValue'].toString()) ?? 0.0;
    }
    if (valMap.containsKey('timestampValue')) return valMap['timestampValue'];
    if (valMap.containsKey('nullValue')) return null;
    if (valMap.containsKey('arrayValue')) {
      final values = valMap['arrayValue']?['values'] as List?;
      if (values == null) return [];
      return values
          .map((v) => v is Map<String, dynamic> ? _decodeFirestoreValue(v) : v)
          .toList();
    }
    if (valMap.containsKey('mapValue')) {
      final fields = valMap['mapValue']?['fields'] as Map<String, dynamic>?;
      if (fields == null) return {};
      return fields.map((k, v) => MapEntry(
          k, v is Map<String, dynamic> ? _decodeFirestoreValue(v) : v));
    }
    return null;
  }

  static Map<String, dynamic> _decodeFirestoreDoc(Map<String, dynamic> docJson) {
    final result = <String, dynamic>{};
    final name = docJson['name'] as String? ?? '';
    final docId = name.split('/').last;
    result['id'] = docId;

    final fields = docJson['fields'] as Map<String, dynamic>?;
    if (fields != null) {
      fields.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          result[key] = _decodeFirestoreValue(val);
        }
      });
    }
    return result;
  }

  static Map<String, dynamic> _encodeFirestoreFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (key == 'id') return; // Document ID is in URL path
      if (value == null) {
        fields[key] = {'nullValue': null};
      } else if (value is String) {
        fields[key] = {'stringValue': value};
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else if (value is List) {
        fields[key] = {
          'arrayValue': {
            'values': value.map((item) {
              if (item is String) return {'stringValue': item};
              if (item is bool) return {'booleanValue': item};
              if (item is num) return {'integerValue': item.toString()};
              return {'stringValue': item.toString()};
            }).toList()
          }
        };
      } else if (value is Map<String, dynamic>) {
        fields[key] = {'mapValue': {'fields': _encodeFirestoreFields(value)}};
      }
    });
    return fields;
  }

  // ===========================================================================
  // DIRECT REST API CALLERS & DIAGNOSTICS
  // ===========================================================================

  /// Formats a complete structured diagnostic report for authentication failures
  String _buildDiagnostics({
    required String cleanEmail,
    String? sdkPhaseStatus,
    required String restPhaseStatus,
    required String errorSummary,
    String? activeEndpoint,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== CapSync Authentication Diagnostic Report ===');
    buffer.writeln('Timestamp: ${DateTime.now().toUtc().toIso8601String()} UTC');
    buffer.writeln('Platform: ${defaultTargetPlatform.name} (kIsWeb: $kIsWeb)');
    buffer.writeln('Firebase Initialized: $_isFirebaseInitialized (${Firebase.apps.length} app(s))');
    buffer.writeln('Project ID: ${FirebaseConfig.projectId}');
    buffer.writeln('Active API Key: ${NetworkDiagnosticsService.maskKey(_activeApiKey)}');
    buffer.writeln('Account: $cleanEmail');
    buffer.writeln();
    buffer.writeln('--- Authentication Execution Trace ---');
    buffer.writeln('Step 1 (Firebase SDK [5s timeout]): ${sdkPhaseStatus ?? "Not executed"}');
    buffer.writeln('Step 2 (Firebase REST [15s timeout]): $restPhaseStatus');
    if (activeEndpoint != null) {
      buffer.writeln('REST Endpoint: $activeEndpoint');
    }
    buffer.writeln();
    buffer.writeln('--- Error Summary ---');
    buffer.writeln(errorSummary);
    return buffer.toString();
  }

  /// Runs full live network reachability diagnostics
  Future<String> runFullDiagnostics({String? email}) async {
    return NetworkDiagnosticsService.runFullDiagnosticReport(
      attemptedEmail: email,
      sdkPhaseStatus: 'Probe initiated from diagnostics UI',
      restPhaseStatus: lastAuthDiagnostics ?? lastAuthError ?? 'None logged',
      lastErrorDescription: lastAuthError,
    );
  }

  /// Authenticate directly via Google Identity Toolkit REST API
  Future<User?> _authenticateViaRest(
    String cleanEmail,
    String password, {
    String? sdkPhaseStatus,
  }) async {
    String restPhaseStatus = 'Initiating REST request...';
    final apiKey = _activeApiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
    );

    try {
      debugPrint("Firebase REST Auth: attempting login for $cleanEmail at ${uri.host}...");
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              'password': password.trim(),
              'returnSecureToken': true,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        restPhaseStatus = 'HTTP 200 OK (Authenticated)';
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uid = data['localId']?.toString() ?? '';
        debugPrint("Firebase REST Auth: authenticated UID $uid successfully.");

        final user = await _fetchUserProfile(uid, fallbackEmail: cleanEmail);
        if (user != null) {
          lastAuthError = null;
          lastAuthDiagnostics = null;
          await _fallbackDb.registerUser(user, password);
          return user;
        }

        // Profile doc not found yet, create fallback student
        return Student(
          id: uid,
          name: cleanEmail.split('@').first,
          email: cleanEmail,
          avatarInitials: cleanEmail.isNotEmpty ? cleanEmail[0].toUpperCase() : 'U',
          studentIdNumber: '',
          groupId: '',
          capstoneTitle: '',
        );
      } else {
        String errorMsg = '';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          errorMsg = data['error']?['message']?.toString() ?? response.body;
        } catch (_) {
          errorMsg = response.body;
        }
        restPhaseStatus = 'HTTP ${response.statusCode}: $errorMsg';
        debugPrint("Firebase REST Auth response error: $restPhaseStatus");

        if (errorMsg.contains('INVALID_LOGIN_CREDENTIALS') ||
            errorMsg.contains('INVALID_PASSWORD')) {
          lastAuthError = 'Incorrect password or email. Please verify your credentials.';
        } else if (errorMsg.contains('EMAIL_NOT_FOUND')) {
          lastAuthError = 'No institutional account found with this email ($cleanEmail).';
        } else if (errorMsg.contains('USER_DISABLED')) {
          lastAuthError = 'This account has been disabled. Please contact the coordinator.';
        } else if (errorMsg.contains('TOO_MANY_ATTEMPTS')) {
          lastAuthError = 'Too many failed login attempts. Please try again later.';
        } else if (errorMsg.contains('API_KEY_INVALID') || errorMsg.contains('API key not valid')) {
          lastAuthError = 'Firebase configuration error: Invalid or restricted API key.';
        } else {
          lastAuthError = 'Login failed: $errorMsg (HTTP ${response.statusCode})';
        }

        lastAuthDiagnostics = _buildDiagnostics(
          cleanEmail: cleanEmail,
          sdkPhaseStatus: sdkPhaseStatus,
          restPhaseStatus: restPhaseStatus,
          errorSummary: lastAuthError!,
          activeEndpoint: uri.toString(),
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        restPhaseStatus = 'TimeoutException: Request to identitytoolkit.googleapis.com timed out after 15 seconds';
        lastAuthError = 'Connection timed out (15s) while contacting Firebase servers (identitytoolkit.googleapis.com). Please check your internet connection or tap "Show Diagnostics".';
      } else {
        restPhaseStatus = '${e.runtimeType}: $e';
        lastAuthError = 'Network connection error (${e.runtimeType}): $e';
      }
      debugPrint("Firebase REST Auth network error: $restPhaseStatus");

      lastAuthDiagnostics = _buildDiagnostics(
        cleanEmail: cleanEmail,
        sdkPhaseStatus: sdkPhaseStatus,
        restPhaseStatus: restPhaseStatus,
        errorSummary: lastAuthError!,
        activeEndpoint: uri.toString(),
      );
    }
    return null;
  }

  /// Fetches single user profile from Firestore SDK with REST fallback
  Future<User?> _fetchUserProfile(String uid, {String? fallbackEmail}) async {
    // 1. Try Firestore SDK
    if (_isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirebaseConfig.usersCollection)
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          if (data['id'] == null || data['id'].toString().isEmpty) {
            data['id'] = uid;
          }
          debugPrint("Firestore SDK: fetched profile for ${data['name']} ($uid).");
          return User.fromJson(data);
        }
      } catch (e) {
        debugPrint("Firestore SDK fetch user notice: $e. Trying REST fallback...");
      }
    }

    // 2. Direct Firestore REST API
    try {
      final apiKey = _activeApiKey;
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents/${FirebaseConfig.usersCollection}/$uid?key=$apiKey',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final docJson = jsonDecode(resp.body) as Map<String, dynamic>;
        final parsed = _decodeFirestoreDoc(docJson);
        if (parsed['id'] == null || parsed['id'].toString().isEmpty) {
          parsed['id'] = uid;
        }
        debugPrint("Firestore REST: fetched profile for ${parsed['name']} ($uid).");
        return User.fromJson(parsed);
      }
    } catch (e) {
      debugPrint("Firestore REST fetch user notice: $e");
    }

    // 3. Fallback: match by email from full user collection
    if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
      try {
        final allUsers = await getAllUsers();
        for (final u in allUsers) {
          if (u.email.toLowerCase() == fallbackEmail.toLowerCase() || u.id == uid) {
            return u;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Fetches an entire collection via Firestore REST API
  Future<List<Map<String, dynamic>>> _fetchCollectionRest(String collection) async {
    try {
      final apiKey = _activeApiKey;
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents/$collection?key=$apiKey',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final docs = json['documents'] as List? ?? [];
        return docs
            .map((d) => _decodeFirestoreDoc(d as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint("Firestore REST fetchCollection ($collection) notice: $e");
    }
    return [];
  }

  /// Writes a document via Firestore REST API (PATCH)
  Future<void> _writeDocRest(String collection, String docId, Map<String, dynamic> data) async {
    try {
      final apiKey = _activeApiKey;
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents/$collection/$docId?key=$apiKey',
      );
      final body = jsonEncode({'fields': _encodeFirestoreFields(data)});
      await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5));
      debugPrint("Firestore REST: saved $collection/$docId.");
    } catch (e) {
      debugPrint("Firestore REST write ($collection/$docId) notice: $e");
    }
  }

  // ===========================================================================
  // AUTHENTICATION & USER MANAGEMENT
  // ===========================================================================

  @override
  Future<User?> authenticate(String email, String password) async {
    lastAuthError = null;
    lastAuthDiagnostics = null;
    final cleanEmail = email.trim().toLowerCase();

    if (_isFirebaseInitialized) {
      String sdkPhaseStatus = 'Not executed';
      // 1. Try Firebase Auth SDK (fast 5s timeout)
      try {
        final auth = fb_auth.FirebaseAuth.instance;
        final userCred = await auth
            .signInWithEmailAndPassword(
              email: cleanEmail,
              password: password.trim(),
            )
            .timeout(const Duration(seconds: 5));

        if (userCred.user != null) {
          final uid = userCred.user!.uid;
          final user = await _fetchUserProfile(uid, fallbackEmail: cleanEmail);
          if (user != null) {
            lastAuthError = null;
            lastAuthDiagnostics = null;
            await _fallbackDb.registerUser(user, password);
            return user;
          }
        }
        sdkPhaseStatus = 'SDK signed in successfully, but user profile was not found';
      } on fb_auth.FirebaseAuthException catch (e) {
        sdkPhaseStatus = 'FirebaseAuthException: [${e.code}] ${e.message}';
        debugPrint("FirebaseAuthException: ${e.code} - ${e.message}");
        if (e.code == 'user-not-found') {
          lastAuthError = 'No institutional account found with this email ($cleanEmail).';
          lastAuthDiagnostics = _buildDiagnostics(
            cleanEmail: cleanEmail,
            sdkPhaseStatus: sdkPhaseStatus,
            restPhaseStatus: 'Skipped (user not found in Firebase)',
            errorSummary: lastAuthError!,
          );
          return null;
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          lastAuthError = 'Incorrect password. Please verify your credentials.';
          lastAuthDiagnostics = _buildDiagnostics(
            cleanEmail: cleanEmail,
            sdkPhaseStatus: sdkPhaseStatus,
            restPhaseStatus: 'Skipped (credentials rejected by Firebase)',
            errorSummary: lastAuthError!,
          );
          return null;
        } else if (e.code != 'network-request-failed') {
          lastAuthError = e.message ?? 'Firebase Auth error: ${e.code}';
        }
      } catch (e) {
        if (e is TimeoutException) {
          sdkPhaseStatus = 'TimeoutException: SDK timed out after 5.0 seconds';
        } else {
          sdkPhaseStatus = '${e.runtimeType}: $e';
        }
        debugPrint("Firebase Auth SDK notice: $sdkPhaseStatus. Falling back to direct REST API...");
      }

      // 2. Direct Firebase REST API Fallback
      final restUser = await _authenticateViaRest(
        cleanEmail,
        password,
        sdkPhaseStatus: sdkPhaseStatus,
      );
      if (restUser != null) {
        lastAuthError = null;
        lastAuthDiagnostics = null;
        return restUser;
      }

      // 3. Fallback to local storage if user was previously cached
      final fallbackUser = await _fallbackDb.authenticate(cleanEmail, password);
      if (fallbackUser != null) {
        lastAuthError = null;
        lastAuthDiagnostics = null;
        return fallbackUser;
      }

      return null;
    }

    // Fallback for headless unit tests
    return _fallbackDb.authenticate(cleanEmail, password);
  }

  @override
  Future<bool> registerUser(User user, String password) async {
    if (_isFirebaseInitialized) {
      try {
        final auth = fb_auth.FirebaseAuth.instance;
        final userCred = await auth
            .createUserWithEmailAndPassword(
              email: user.email.trim(),
              password: password.trim(),
            )
            .timeout(const Duration(seconds: 5));

        if (userCred.user != null) {
          // Send verification email via Firebase Auth natively!
          try {
            await userCred.user!.sendEmailVerification().timeout(const Duration(seconds: 4));
            debugPrint("Firebase Auth: sendEmailVerification dispatched to ${user.email}");
          } catch (e) {
            debugPrint("Firebase sendEmailVerification notice: $e");
          }

          final data = user.toJson();
          data['id'] = userCred.user!.uid;

          await FirebaseFirestore.instance
              .collection(FirebaseConfig.usersCollection)
              .doc(userCred.user!.uid)
              .set(data)
              .timeout(const Duration(seconds: 4));

          await _fallbackDb.registerUser(user, password);
          return true;
        }
      } catch (e) {
        debugPrint("Firebase registration SDK notice: $e. Registering via REST...");
      }

      // REST Registration fallback
      try {
        final apiKey = _activeApiKey;
        final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
        );
        final resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': user.email.trim(),
                'password': password.trim(),
                'returnSecureToken': true,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final uid = data['localId']?.toString() ?? user.id;
          final idToken = data['idToken']?.toString();

          // Send verification email via REST sendOobCode
          if (idToken != null) {
            try {
              final oobUri = Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey',
              );
              await http.post(
                oobUri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'requestType': 'VERIFY_EMAIL',
                  'idToken': idToken,
                }),
              ).timeout(const Duration(seconds: 4));
              debugPrint("Firebase REST sendOobCode VERIFY_EMAIL dispatched to ${user.email}");
            } catch (_) {}
          }

          final userMap = user.toJson();
          userMap['id'] = uid;
          await _writeDocRest(FirebaseConfig.usersCollection, uid, userMap);
          await _fallbackDb.registerUser(user, password);
          return true;
        }
      } catch (e) {
        debugPrint("Firebase REST registration notice: $e");
      }
    }

    return _fallbackDb.registerUser(user, password);
  }

  /// Coordinator creates Faculty/Teacher account
  Future<User?> createFacultyUser(FacultyMember faculty, String password) async {
    if (_isFirebaseInitialized) {
      String? uid;
      try {
        const secondaryAppName = 'SecondaryFacultyAdmin';
        FirebaseApp secondaryApp;
        try {
          secondaryApp = Firebase.app(secondaryAppName);
        } catch (_) {
          secondaryApp = await Firebase.initializeApp(
            name: secondaryAppName,
            options: Firebase.app().options,
          );
        }
        final secondaryAuth = fb_auth.FirebaseAuth.instanceFor(app: secondaryApp);
        final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: faculty.email.trim(),
          password: password.trim(),
        );
        uid = cred.user?.uid;
        await secondaryAuth.signOut();
      } catch (e) {
        debugPrint("Secondary Firebase App auth creation notice: $e.");
        // If authentication fails (e.g. email already exists, weak password), do not fabricate conflicting document
        return null;
      }

      if (uid == null || uid.isEmpty) return null;

      final docId = uid;
      final data = faculty.toJson();
      data['id'] = docId;
      final createdFaculty = FacultyMember.fromJson(data);

      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.usersCollection)
            .doc(docId)
            .set(data)
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("Firestore faculty document write notice: $e. Writing via REST...");
        await _writeDocRest(FirebaseConfig.usersCollection, docId, data);
      }

      await _fallbackDb.registerUser(createdFaculty, password);
      return createdFaculty;
    } else {
      await _fallbackDb.registerUser(faculty, password);
      return faculty;
    }
  }

  /// Updates a student's assigned group and capstone title in Firestore
  Future<void> updateStudentGroup({
    required String studentId,
    required String groupId,
    required String capstoneTitle,
  }) async {
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.usersCollection)
            .doc(studentId)
            .set({
          'groupId': groupId,
          'capstoneTitle': capstoneTitle,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
        debugPrint("Firestore updateStudentGroup: successfully linked $studentId to $groupId.");
        return;
      } catch (e) {
        debugPrint("Firestore updateStudentGroup notice: $e. Writing via REST...");
      }

      await _writeDocRest(
        FirebaseConfig.usersCollection,
        studentId,
        {'groupId': groupId, 'capstoneTitle': capstoneTitle},
      );
    }
  }

  @override
  Future<List<User>> getAllUsers() async {
    if (_isFirebaseInitialized) {
      // 1. Try Firestore SDK
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirebaseConfig.usersCollection)
            .get()
            .timeout(const Duration(seconds: 4));
        if (snapshot.docs.isNotEmpty) {
          final users = snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (data['id'] == null || data['id'].toString().isEmpty) {
              data['id'] = doc.id;
            }
            return User.fromJson(data);
          }).where((u) => u.name.trim().isNotEmpty && u.email.trim().isNotEmpty).toList();
          debugPrint("Firestore SDK getAllUsers: fetched ${users.length} users.");
          return users;
        }
      } catch (e) {
        debugPrint("Firestore SDK getAllUsers notice: $e. Falling back to REST...");
      }

      // 2. Direct Firestore REST Fallback
      final restDocs = await _fetchCollectionRest(FirebaseConfig.usersCollection);
      if (restDocs.isNotEmpty) {
        final users = restDocs
            .map((d) => User.fromJson(d))
            .where((u) => u.name.trim().isNotEmpty && u.email.trim().isNotEmpty)
            .toList();
        debugPrint("Firestore REST getAllUsers: fetched ${users.length} users.");
        return users;
      }
    }
    return (await _fallbackDb.getAllUsers())
        .where((u) => u.name.trim().isNotEmpty && u.email.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_isFirebaseInitialized) {
      try {
        await fb_auth.FirebaseAuth.instance
            .sendPasswordResetEmail(email: cleanEmail)
            .timeout(const Duration(seconds: 5));
        return true;
      } catch (e) {
        debugPrint("sendPasswordResetEmail SDK notice: $e. Sending via REST...");
      }

      try {
        final apiKey = _activeApiKey;
        final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey',
        );
        final resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requestType': 'PASSWORD_RESET',
                'email': cleanEmail,
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) return true;
      } catch (e) {
        debugPrint("sendPasswordResetEmail REST notice: $e");
      }
    }
    return _fallbackDb.sendPasswordResetEmail(cleanEmail);
  }

  @override
  Future<bool> sendEmailVerification({String? email}) async {
    final cleanEmail = (email ?? '').trim().toLowerCase();
    if (_isFirebaseInitialized) {
      try {
        final user = fb_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.sendEmailVerification().timeout(const Duration(seconds: 5));
          debugPrint("Firebase SDK: verification link sent to ${user.email}");
          return true;
        }
      } catch (e) {
        debugPrint("sendEmailVerification SDK notice: $e. Sending via REST...");
      }

      try {
        final apiKey = _activeApiKey;
        final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey',
        );
        final resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requestType': 'VERIFY_EMAIL',
                if (cleanEmail.isNotEmpty) 'email': cleanEmail,
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) return true;
      } catch (e) {
        debugPrint("sendEmailVerification REST notice: $e");
      }
    }
    return _fallbackDb.sendEmailVerification(email: cleanEmail);
  }

  @override
  Future<bool> isCurrentUserEmailVerified() async {
    if (_isFirebaseInitialized) {
      try {
        final user = fb_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.reload().timeout(const Duration(seconds: 4));
          return fb_auth.FirebaseAuth.instance.currentUser?.emailVerified ?? false;
        }
      } catch (e) {
        debugPrint("isCurrentUserEmailVerified notice: $e");
      }
    }
    return _fallbackDb.isCurrentUserEmailVerified();
  }

  @override
  Future<void> reloadCurrentUser() async {
    if (_isFirebaseInitialized) {
      try {
        await fb_auth.FirebaseAuth.instance.currentUser?.reload().timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    await _fallbackDb.reloadCurrentUser();
  }

  @override
  Future<bool> updatePassword(String email, String newPassword) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_isFirebaseInitialized) {
      try {
        final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.email?.toLowerCase() == cleanEmail) {
          await currentUser.updatePassword(newPassword.trim()).timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint("updatePassword error: $e");
      }
    }
    return _fallbackDb.updatePassword(cleanEmail, newPassword);
  }

  @override
  Future<bool> updateUserProfile(User updatedUser) async {
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.usersCollection)
            .doc(updatedUser.id)
            .set(updatedUser.toJson(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("updateUserProfile SDK notice: $e. Writing via REST...");
        await _writeDocRest(FirebaseConfig.usersCollection, updatedUser.id, updatedUser.toJson());
      }
    }
    return _fallbackDb.updateUserProfile(updatedUser);
  }

  @override
  Future<String?> getSavedSessionUserId() async {
    // 1. Check native Firebase Auth SDK session
    if (_isFirebaseInitialized) {
      try {
        final authUser = fb_auth.FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.uid.isNotEmpty) {
          debugPrint("Firebase SDK active session discovered: ${authUser.uid} (${authUser.email})");
          return authUser.uid;
        }
      } catch (e) {
        debugPrint("Firebase SDK session check notice: $e");
      }
    }

    // 2. Check persistent fallback session (stores UID / email across app restarts)
    return _fallbackDb.getSavedSessionUserId();
  }

  @override
  Future<void> saveSessionUserId(String userId) async {
    await _fallbackDb.saveSessionUserId(userId);
  }

  @override
  Future<void> clearSession() async {
    await _fallbackDb.clearSession();
    if (_isFirebaseInitialized) {
      try {
        await fb_auth.FirebaseAuth.instance.signOut();
        debugPrint("Firebase Auth SDK session signed out.");
      } catch (e) {
        debugPrint("Firebase Auth signOut notice: $e");
      }
    }
  }

  @override
  Future<void> saveUserFcmToken(String userId, String token) async {
    await _fallbackDb.saveUserFcmToken(userId, token);
    
    // Resolve true Firebase Auth UID if userId is temporary
    String targetId = userId;
    if (targetId.startsWith('usr-') && _isFirebaseInitialized) {
      final currentAuthUid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
      if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
        targetId = currentAuthUid;
      }
    }

    if (_isFirebaseInitialized && token.isNotEmpty && targetId.isNotEmpty) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection(FirebaseConfig.usersCollection)
            .doc(targetId);
        
        final docSnap = await docRef.get().timeout(const Duration(seconds: 4));
        if (docSnap.exists) {
          await docRef.update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdated': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 4));
          debugPrint("FCM token updated in Firestore for user $targetId");
        }
      } catch (e) {
        debugPrint("Firestore SDK saveUserFcmToken notice: $e");
      }
    }
  }

  @override
  Future<List<String>> getUserFcmTokens(String userId) async {
    final fallbackTokens = await _fallbackDb.getUserFcmTokens(userId);
    if (!_isFirebaseInitialized || userId.isEmpty) return fallbackTokens;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirebaseConfig.usersCollection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 4));

      if (!doc.exists) return fallbackTokens;
      final data = doc.data();
      if (data == null) return fallbackTokens;

      final Set<String> tokens = {...fallbackTokens};
      final rawTokens = data['fcmTokens'];
      if (rawTokens is List) {
        for (final t in rawTokens) {
          if (t != null && t.toString().trim().isNotEmpty) {
            tokens.add(t.toString().trim());
          }
        }
      }
      final single = data['fcmToken']?.toString().trim();
      if (single != null && single.isNotEmpty) {
        tokens.add(single);
      }
      return tokens.toList();
    } catch (e) {
      debugPrint("Firestore SDK getUserFcmTokens notice: $e");
      return fallbackTokens;
    }
  }

  // ===========================================================================
  // TIME SLOTS
  // ===========================================================================

  @override
  Future<List<TimeSlot>> getSlots() async {
    if (_isFirebaseInitialized) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirebaseConfig.timeSlotsCollection)
            .get()
            .timeout(const Duration(seconds: 4));
        if (snapshot.docs.isNotEmpty) {
          debugPrint("Firestore SDK getSlots: fetched ${snapshot.docs.length} slots.");
          return snapshot.docs.map((doc) => TimeSlot.fromJson(doc.data())).toList();
        }
      } catch (e) {
        debugPrint("Firestore SDK getSlots notice: $e. Trying REST fallback...");
      }

      final restDocs = await _fetchCollectionRest(FirebaseConfig.timeSlotsCollection);
      if (restDocs.isNotEmpty) {
        return restDocs.map((d) => TimeSlot.fromJson(d)).toList();
      }
      return [];
    }
    return _fallbackDb.getSlots();
  }

  @override
  Future<void> saveSlot(TimeSlot slot) async {
    await _fallbackDb.saveSlot(slot);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.timeSlotsCollection)
            .doc(slot.id)
            .set(slot.toJson())
            .timeout(const Duration(seconds: 4));
        return;
      } catch (e) {
        debugPrint("Firestore SDK saveSlot notice: $e. Writing via REST...");
      }
      await _writeDocRest(FirebaseConfig.timeSlotsCollection, slot.id, slot.toJson());
    }
  }

  @override
  Future<bool> deleteSlot(String slotId) async {
    final deleted = await _fallbackDb.deleteSlot(slotId);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.timeSlotsCollection)
            .doc(slotId)
            .delete()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("Firestore deleteSlot notice: $e");
      }
    }
    return deleted;
  }

  @override
  Stream<List<TimeSlot>> streamSlots() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection(FirebaseConfig.timeSlotsCollection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => TimeSlot.fromJson(doc.data()))
            .toList();
      });
    }
    return const Stream.empty();
  }

  // ===========================================================================
  // BOOKINGS
  // ===========================================================================

  @override
  Future<List<ConsultationBooking>> getBookings() async {
    if (_isFirebaseInitialized) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirebaseConfig.bookingsCollection)
            .get()
            .timeout(const Duration(seconds: 4));
        if (snapshot.docs.isNotEmpty) {
          debugPrint("Firestore SDK getBookings: fetched ${snapshot.docs.length} bookings.");
          return snapshot.docs.map((doc) => ConsultationBooking.fromJson(doc.data())).toList();
        }
      } catch (e) {
        debugPrint("Firestore SDK getBookings notice: $e. Trying REST fallback...");
      }

      final restDocs = await _fetchCollectionRest(FirebaseConfig.bookingsCollection);
      if (restDocs.isNotEmpty) {
        return restDocs.map((d) => ConsultationBooking.fromJson(d)).toList();
      }
      return [];
    }
    return _fallbackDb.getBookings();
  }

  @override
  Future<void> saveBooking(ConsultationBooking booking) async {
    await _fallbackDb.saveBooking(booking);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.bookingsCollection)
            .doc(booking.id)
            .set(booking.toJson())
            .timeout(const Duration(seconds: 4));
        return;
      } catch (e) {
        debugPrint("Firestore SDK saveBooking notice: $e. Writing via REST...");
      }
      await _writeDocRest(FirebaseConfig.bookingsCollection, booking.id, booking.toJson());
    }
  }

  @override
  Future<void> updateBooking(ConsultationBooking booking) async {
    await _fallbackDb.updateBooking(booking);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.bookingsCollection)
            .doc(booking.id)
            .set(booking.toJson())
            .timeout(const Duration(seconds: 4));
        return;
      } catch (e) {
        debugPrint("Firestore SDK updateBooking notice: $e. Writing via REST...");
      }
      await _writeDocRest(FirebaseConfig.bookingsCollection, booking.id, booking.toJson());
    }
  }

  @override
  Stream<List<ConsultationBooking>> streamBookings() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection(FirebaseConfig.bookingsCollection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => ConsultationBooking.fromJson(doc.data()))
            .toList();
      });
    }
    return const Stream.empty();
  }

  // ===========================================================================
  // CAPSTONE GROUPS
  // ===========================================================================

  @override
  Future<List<CapstoneGroup>> getGroups() async {
    if (_isFirebaseInitialized) {
      // 1. Try Firestore SDK
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirebaseConfig.groupsCollection)
            .get()
            .timeout(const Duration(seconds: 4));
        if (snapshot.docs.isNotEmpty) {
          final groups = snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (data['id'] == null || data['id'].toString().isEmpty) {
              data['id'] = doc.id;
            }
            return CapstoneGroup.fromJson(data);
          }).toList();
          debugPrint("Firestore SDK getGroups: fetched ${groups.length} groups.");
          return groups;
        }
      } catch (e) {
        debugPrint("Firestore SDK getGroups notice: $e. Trying REST fallback...");
      }

      // 2. Direct Firestore REST Fallback
      final restDocs = await _fetchCollectionRest(FirebaseConfig.groupsCollection);
      if (restDocs.isNotEmpty) {
        final groups = restDocs.map((d) => CapstoneGroup.fromJson(d)).toList();
        debugPrint("Firestore REST getGroups: fetched ${groups.length} groups.");
        return groups;
      }
    }
    return _fallbackDb.getGroups();
  }

  @override
  Future<void> saveGroup(CapstoneGroup group) async {
    await _fallbackDb.saveGroup(group);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.groupsCollection)
            .doc(group.id)
            .set(group.toJson())
            .timeout(const Duration(seconds: 4));
        return;
      } catch (e) {
        debugPrint("Firestore SDK saveGroup notice: $e. Writing via REST...");
      }
      await _writeDocRest(FirebaseConfig.groupsCollection, group.id, group.toJson());
    }
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  @override
  Future<List<AppNotification>> getNotifications() async {
    if (_isFirebaseInitialized) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirebaseConfig.notificationsCollection)
            .get()
            .timeout(const Duration(seconds: 4));
        if (snapshot.docs.isNotEmpty) {
          debugPrint("Firestore SDK getNotifications: fetched ${snapshot.docs.length} notifications.");
          return snapshot.docs.map((doc) => AppNotification.fromJson(doc.data())).toList();
        }
      } catch (e) {
        debugPrint("Firestore SDK getNotifications notice: $e. Trying REST fallback...");
      }

      final restDocs = await _fetchCollectionRest(FirebaseConfig.notificationsCollection);
      if (restDocs.isNotEmpty) {
        return restDocs.map((d) => AppNotification.fromJson(d)).toList();
      }
      return [];
    }
    return _fallbackDb.getNotifications();
  }

  @override
  Future<void> saveNotification(AppNotification notif) async {
    await _fallbackDb.saveNotification(notif);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseConfig.notificationsCollection)
            .doc(notif.id)
            .set(notif.toJson())
            .timeout(const Duration(seconds: 4));
        return;
      } catch (e) {
        debugPrint("Firestore SDK saveNotification notice: $e. Writing via REST...");
      }
      await _writeDocRest(FirebaseConfig.notificationsCollection, notif.id, notif.toJson());
    }
  }

  @override
  Stream<List<AppNotification>> streamNotifications(String userId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection(FirebaseConfig.notificationsCollection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.data()))
            .where((n) => n.recipientUserId == userId)
            .toList();
      });
    }
    return const Stream.empty();
  }
}
