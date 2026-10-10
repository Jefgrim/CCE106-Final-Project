// =============================================================================
// FILE: lib/services/diagnostics/network_diagnostics_service.dart
// CAPSYNC NETWORK & FIREBASE CONNECTIVITY DIAGNOSTICS SERVICE
// Probes network reachability, DNS resolution, and Firebase service endpoints
// to deliver comprehensive diagnostic logs for instant troubleshooting.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import '../database/firebase_config.dart';

class NetworkDiagnosticsService {
  /// Safely masks an API key showing prefix and suffix for verification
  static String maskKey(String key) {
    if (key.isEmpty) return '(empty)';
    if (key.length <= 10) return '${key.substring(0, 3)}***';
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }

  /// Runs a complete battery of connection tests to Google and Firebase servers
  static Future<String> runFullDiagnosticReport({
    String? attemptedEmail,
    String? sdkPhaseStatus,
    String? restPhaseStatus,
    String? lastErrorDescription,
  }) async {
    final buffer = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();

    buffer.writeln('=== CapSync Connection Diagnostic Report ===');
    buffer.writeln('Generated: $now UTC');
    buffer.writeln('Target Platform: ${defaultTargetPlatform.name} (kIsWeb: $kIsWeb)');
    buffer.writeln('Firebase Initialized: ${Firebase.apps.isNotEmpty} (${Firebase.apps.length} app(s) registered)');
    buffer.writeln('Target Project ID: ${FirebaseConfig.projectId}');
    buffer.writeln('Primary API Key: ${maskKey(FirebaseConfig.apiKey)}');
    buffer.writeln('Android API Key: ${maskKey(FirebaseConfig.androidApiKey)}');
    if (attemptedEmail != null && attemptedEmail.isNotEmpty) {
      buffer.writeln('Attempted Account: $attemptedEmail');
    }
    buffer.writeln();

    // 1. General Internet Probe
    buffer.writeln('--- 1. General Internet Connectivity Probe ---');
    try {
      final sw = Stopwatch()..start();
      final probeUri = Uri.parse('https://clients3.google.com/generate_204');
      final resp = await http.get(probeUri).timeout(const Duration(seconds: 4));
      sw.stop();
      if (resp.statusCode == 204 || resp.statusCode == 200) {
        buffer.writeln('Status: SUCCESS - Internet reachable (${sw.elapsedMilliseconds} ms)');
      } else {
        buffer.writeln('Status: NOTICE - Unexpected HTTP ${resp.statusCode} from gateway probe (${sw.elapsedMilliseconds} ms)');
      }
    } catch (e) {
      buffer.writeln('Status: FAILED - Cannot reach public internet:');
      buffer.writeln('  Exception: ${e.runtimeType}: $e');
    }
    buffer.writeln();

    // 2. Firebase Auth REST Endpoint Probe
    buffer.writeln('--- 2. Firebase Auth REST Endpoint Probe ---');
    final activeKey = (!kIsWeb && FirebaseConfig.androidApiKey.isNotEmpty)
        ? FirebaseConfig.androidApiKey
        : FirebaseConfig.apiKey;
    final authUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$activeKey',
    );
    try {
      final sw = Stopwatch()..start();
      final resp = await http
          .post(
            authUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': 'probe_check_only@capsync.internal',
              'password': 'probe_dummy_check',
              'returnSecureToken': false,
            }),
          )
          .timeout(const Duration(seconds: 5));
      sw.stop();

      buffer.writeln('Endpoint: identitytoolkit.googleapis.com (${sw.elapsedMilliseconds} ms)');
      buffer.writeln('HTTP Status: ${resp.statusCode}');
      if (resp.statusCode == 400) {
        // Expected for dummy check
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final msg = data['error']?['message']?.toString() ?? resp.body;
          buffer.writeln('Server Response: $msg (Connection verified)');
        } catch (_) {
          buffer.writeln('Response: ${resp.body}');
        }
      } else {
        buffer.writeln('Response: ${resp.body}');
      }
    } catch (e) {
      buffer.writeln('Status: FAILED to connect to Firebase Auth server:');
      buffer.writeln('  Exception: ${e.runtimeType}: $e');
    }
    buffer.writeln();

    // 3. Cloud Firestore REST Endpoint Probe
    buffer.writeln('--- 3. Cloud Firestore REST Endpoint Probe ---');
    final firestoreUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents/${FirebaseConfig.usersCollection}?key=$activeKey',
    );
    try {
      final sw = Stopwatch()..start();
      final resp = await http.get(firestoreUri).timeout(const Duration(seconds: 5));
      sw.stop();

      buffer.writeln('Endpoint: firestore.googleapis.com (${sw.elapsedMilliseconds} ms)');
      buffer.writeln('HTTP Status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        buffer.writeln('Status: SUCCESS - Cloud Firestore is accessible.');
      } else {
        buffer.writeln('Server Response: ${resp.body}');
      }
    } catch (e) {
      buffer.writeln('Status: FAILED to connect to Cloud Firestore server:');
      buffer.writeln('  Exception: ${e.runtimeType}: $e');
    }
    buffer.writeln();

    // 4. Authentication Phases Context (if supplied)
    if (sdkPhaseStatus != null || restPhaseStatus != null || lastErrorDescription != null) {
      buffer.writeln('--- 4. Authentication Execution Phases ---');
      if (sdkPhaseStatus != null) {
        buffer.writeln('SDK Phase (5s timeout): $sdkPhaseStatus');
      }
      if (restPhaseStatus != null) {
        buffer.writeln('REST Phase (15s timeout): $restPhaseStatus');
      }
      if (lastErrorDescription != null) {
        buffer.writeln('Final Reported Error: $lastErrorDescription');
      }
      buffer.writeln();
    }

    // 5. Actionable Advice
    buffer.writeln('--- 5. Automated Diagnosis ---');
    final reportText = buffer.toString();
    if (reportText.contains('SocketException') || reportText.contains('Failed host lookup')) {
      buffer.writeln('• DNS / No Connection: The device cannot resolve Google hostnames.');
      buffer.writeln('  - Android Emulator: Wi-Fi inside the emulator may be in "Connected, no internet" state.');
      buffer.writeln('    Try: Cold Boot the emulator, or set emulator DNS to 8.8.8.8.');
      buffer.writeln('  - Physical Device: Check if campus Wi-Fi or mobile data requires login/captive portal.');
    } else if (reportText.contains('TimeoutException')) {
      buffer.writeln('• Connection Timeout: Packets to Google APIs were dropped or delayed beyond timeout limit.');
      buffer.writeln('  - Network firewall may be blocking outbound HTTPS/gRPC ports, or latency is very high.');
    } else if (reportText.contains('API_KEY_INVALID') || reportText.contains('API key not valid')) {
      buffer.writeln('• API Key Restriction: The API key is either expired, misspelled, or restricted to a specific package/SHA-1.');
    } else {
      buffer.writeln('• Network tests completed. Review the individual probe statuses above.');
    }

    return buffer.toString();
  }
}
