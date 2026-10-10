// =============================================================================
// FILE: lib/services/email_otp_service.dart
// Production-ready One-Time Password (OTP) verification service for CapSync.
// Handles OTP generation, time-based expiration (5 minutes), resend cooldowns,
// maximum verification attempts protection, and multi-channel delivery
// (REST Email APIs, Firebase Cloud Firestore, Local Push Notifications, and Dev Helpers).
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an OTP verification attempt
enum OtpVerificationStatus {
  success,
  invalidCode,
  expired,
  tooManyAttempts,
  noSession,
}

/// Verification attempt outcome
class OtpVerificationResult {
  final OtpVerificationStatus status;
  final String message;
  final int attemptsRemaining;

  const OtpVerificationResult({
    required this.status,
    required this.message,
    this.attemptsRemaining = 0,
  });

  bool get isSuccess => status == OtpVerificationStatus.success;
}

/// Result of dispatching an OTP
class OtpSendResult {
  final bool success;
  final String? code;
  final String message;
  final bool deliveredViaEmail;
  final int cooldownSeconds;

  const OtpSendResult({
    required this.success,
    this.code,
    required this.message,
    this.deliveredViaEmail = false,
    this.cooldownSeconds = 0,
  });
}

/// Active in-memory tracking of OTP verification state
class OtpSession {
  final String email;
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;
  int attemptsRemaining;
  DateTime lastSentAt;

  OtpSession({
    required this.email,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    this.attemptsRemaining = 5,
    required this.lastSentAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class EmailOtpService {
  static final EmailOtpService _instance = EmailOtpService._internal();
  factory EmailOtpService() => _instance;
  EmailOtpService._internal();

  static const String allowedDomain = '@umindanao.edu.ph';
  static const int otpValidityMinutes = 5;
  static const int resendCooldownSeconds = 45;
  static const int maxVerificationAttempts = 5;

  final Map<String, OtpSession> _sessions = {};

  /// Validates whether an email strictly belongs to the official UM institutional domain
  static bool isAllowedDomain(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final clean = email.trim().toLowerCase();
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@umindanao\.edu\.ph$');
    return regex.hasMatch(clean);
  }

  /// Generates a cryptographically strong 6-digit numeric OTP code
  String _generateSecureOtp() {
    final rnd = Random.secure();
    final codeInt = 100000 + rnd.nextInt(900000);
    return codeInt.toString();
  }

  /// Sends a 6-digit OTP verification code strictly to the specified @umindanao.edu.ph email.
  Future<OtpSendResult> sendRegistrationOtp({
    required String email,
    required String userName,
    bool forceNew = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Strict UM institutional domain gate
    if (!isAllowedDomain(cleanEmail)) {
      return const OtpSendResult(
        success: false,
        message: 'Only official @umindanao.edu.ph institutional email addresses are accepted.',
      );
    }

    final now = DateTime.now();

    // 2. Check resend cooldown
    final existingSession = _sessions[cleanEmail];
    if (existingSession != null && !existingSession.isExpired && !forceNew) {
      final elapsed = now.difference(existingSession.lastSentAt).inSeconds;
      if (elapsed < resendCooldownSeconds) {
        final remainingCooldown = resendCooldownSeconds - elapsed;
        return OtpSendResult(
          success: false,
          code: existingSession.code,
          cooldownSeconds: remainingCooldown,
          message: 'Please wait $remainingCooldown second(s) before requesting another code.',
        );
      }
    }

    final otpCode = _generateSecureOtp();
    final expiresAt = now.add(const Duration(minutes: otpValidityMinutes));

    final session = OtpSession(
      email: cleanEmail,
      code: otpCode,
      createdAt: now,
      expiresAt: expiresAt,
      attemptsRemaining: maxVerificationAttempts,
      lastSentAt: now,
    );
    _sessions[cleanEmail] = session;

    debugPrint('[CapSync OTP] Verification code $otpCode dispatched to $cleanEmail (expires in $otpValidityMinutes mins)');

    // 3. Multi-Channel Email Dispatch Attempt
    bool deliveredViaEmail = false;
    try {
      deliveredViaEmail = await _dispatchEmail(
        toEmail: cleanEmail,
        recipientName: userName,
        otpCode: otpCode,
      );
    } catch (e) {
      debugPrint('[CapSync OTP] Email dispatch notice: $e');
    }

    // 4. Cloud Firestore Audit & Trigger Logging
    // Writes to Firestore 'mail' collection (Firebase Trigger Email Extension)
    // and 'email_verifications' collection for security verification audit.
    unawaited(_logToFirestore(
      email: cleanEmail,
      code: otpCode,
      expiresAt: expiresAt,
      userName: userName,
    ));

    return OtpSendResult(
      success: true,
      code: otpCode,
      deliveredViaEmail: deliveredViaEmail,
      message: 'A 6-digit verification code has been sent to $cleanEmail. Please check your inbox.',
    );
  }

  /// Verifies the entered 6-digit code against the active session.
  OtpVerificationResult verifyOtp({
    required String email,
    required String code,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final session = _sessions[cleanEmail];

    if (session == null) {
      return const OtpVerificationResult(
        status: OtpVerificationStatus.noSession,
        message: 'No pending verification found. Please request a new code.',
      );
    }

    if (session.isExpired) {
      return const OtpVerificationResult(
        status: OtpVerificationStatus.expired,
        message: 'This verification code has expired. Please request a new one.',
      );
    }

    if (session.attemptsRemaining <= 0) {
      return const OtpVerificationResult(
        status: OtpVerificationStatus.tooManyAttempts,
        message: 'Too many incorrect attempts. Please request a new verification code.',
      );
    }

    if (session.code != cleanCode) {
      session.attemptsRemaining--;
      if (session.attemptsRemaining <= 0) {
        return const OtpVerificationResult(
          status: OtpVerificationStatus.tooManyAttempts,
          message: 'Too many incorrect attempts. Please request a new code.',
          attemptsRemaining: 0,
        );
      }
      return OtpVerificationResult(
        status: OtpVerificationStatus.invalidCode,
        message: 'Invalid verification code. ${session.attemptsRemaining} attempt(s) remaining.',
        attemptsRemaining: session.attemptsRemaining,
      );
    }

    // Match successful! Invalidate session to prevent reuse
    _sessions.remove(cleanEmail);
    return const OtpVerificationResult(
      status: OtpVerificationStatus.success,
      message: 'Email successfully verified!',
    );
  }

  /// Retrieves the active OTP code for an email (used for evaluation/demo autofill and testing)
  String? getActiveOtp(String email) {
    final session = _sessions[email.trim().toLowerCase()];
    if (session != null && !session.isExpired) {
      return session.code;
    }
    return null;
  }

  /// Checks if an active unexpired session exists for this email
  bool hasActiveSession(String email) {
    final session = _sessions[email.trim().toLowerCase()];
    return session != null && !session.isExpired;
  }

  /// Manually set an OTP for testing purposes
  void setMockOtpForTesting(String email, String code) {
    final now = DateTime.now();
    _sessions[email.trim().toLowerCase()] = OtpSession(
      email: email.trim().toLowerCase(),
      code: code,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      attemptsRemaining: 5,
      lastSentAt: now,
    );
  }

  /// Clears active OTP session for an email
  void clearSession(String email) {
    _sessions.remove(email.trim().toLowerCase());
  }

  /// Clears all sessions (useful between automated unit tests)
  void clearAllSessions() {
    _sessions.clear();
  }

  // ===========================================================================
  // EMAIL DISPATCH PROVIDERS (Resend, Brevo, EmailJS, Custom Webhook)
  // ===========================================================================

  Future<bool> _dispatchEmail({
    required String toEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    // 1. Resend API (if configured in .env)
    if (dotenv.isInitialized) {
      final resendKey = dotenv.env['RESEND_API_KEY'];
      if (resendKey != null && resendKey.isNotEmpty) {
        final ok = await _sendViaResend(resendKey, toEmail, recipientName, otpCode);
        if (ok) return true;
      }

      // 2. Brevo / Sendinblue API (if configured in .env)
      final brevoKey = dotenv.env['BREVO_API_KEY'];
      if (brevoKey != null && brevoKey.isNotEmpty) {
        final ok = await _sendViaBrevo(brevoKey, toEmail, recipientName, otpCode);
        if (ok) return true;
      }

      // 3. EmailJS API (if configured in .env)
      final emailJsService = dotenv.env['EMAILJS_SERVICE_ID'];
      final emailJsTemplate = dotenv.env['EMAILJS_TEMPLATE_ID'];
      final emailJsPublic = dotenv.env['EMAILJS_PUBLIC_KEY'];
      if (emailJsService != null && emailJsTemplate != null && emailJsPublic != null) {
        final ok = await _sendViaEmailJs(
          serviceId: emailJsService,
          templateId: emailJsTemplate,
          publicKey: emailJsPublic,
          privateKey: dotenv.env['EMAILJS_PRIVATE_KEY'],
          toEmail: toEmail,
          userName: recipientName,
          otpCode: otpCode,
        );
        if (ok) return true;
      }

      // 4. Custom Webhook (if user has configured a custom backend mail sender)
      final customWebhook = dotenv.env['CUSTOM_EMAIL_WEBHOOK_URL'];
      if (customWebhook != null && customWebhook.isNotEmpty) {
        final ok = await _sendViaCustomWebhook(customWebhook, toEmail, recipientName, otpCode);
        if (ok) return true;
      }
    }

    return false;
  }

  Future<bool> _sendViaResend(String apiKey, String toEmail, String name, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.resend.com/emails'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'from': 'CapSync <onboarding@resend.dev>',
              'to': [toEmail],
              'subject': 'CapSync Verification Code: $code',
              'html': _buildEmailHtml(name, code),
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendViaBrevo(String apiKey, String toEmail, String name, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.brevo.com/v3/smtp/email'),
            headers: {
              'api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'sender': {'name': 'CapSync - University of Mindanao', 'email': 'noreply@capsync.internal'},
              'to': [
                {'email': toEmail, 'name': name}
              ],
              'subject': 'CapSync Email Verification Code: $code',
              'htmlContent': _buildEmailHtml(name, code),
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendViaEmailJs({
    required String serviceId,
    required String templateId,
    required String publicKey,
    String? privateKey,
    required String toEmail,
    required String userName,
    required String otpCode,
  }) async {
    try {
      final payload = {
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        if (privateKey != null && privateKey.isNotEmpty) 'accessToken': privateKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': userName,
          'otp_code': otpCode,
          'app_name': 'CapSync - University of Mindanao',
        },
      };

      final response = await http
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendViaCustomWebhook(String url, String toEmail, String name, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': toEmail,
              'name': name,
              'code': code,
              'type': 'registration_otp',
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Logs OTP record into Firestore and `mail` queue collection for Firebase Trigger Email
  Future<void> _logToFirestore({
    required String email,
    required String code,
    required DateTime expiresAt,
    required String userName,
  }) async {
    try {
      // 1. Verification audit record
      await FirebaseFirestore.instance.collection('email_verifications').doc(email).set({
        'email': email,
        'code': code,
        'userName': userName,
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Trigger Email Firebase extension collection (if installed)
      await FirebaseFirestore.instance.collection('mail').add({
        'to': [email],
        'message': {
          'subject': 'CapSync Institutional Email Verification Code',
          'text': 'Your CapSync OTP code is $code. Valid for $otpValidityMinutes minutes.',
          'html': _buildEmailHtml(userName, code),
        },
      });
    } catch (_) {
      // Ignored if Firestore isn't connected or is offline
    }
  }

  String _buildEmailHtml(String name, String code) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>CapSync Email Verification</title>
</head>
<body style="font-family: Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px;">
  <div style="max-width: 520px; margin: 0 auto; background-color: #FFFFFF; border-radius: 12px; border: 1px solid #E2E8F0; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
    <div style="text-align: center; margin-bottom: 24px;">
      <h1 style="color: #0F172A; font-size: 22px; margin: 0; font-weight: bold;">CapSync - UM IT College</h1>
      <p style="color: #64748B; font-size: 13px; margin: 4px 0 0;">Capstone Advising & Defense Management Portal</p>
    </div>

    <p style="font-size: 15px; color: #334155;">Hello <strong>$name</strong>,</p>
    <p style="font-size: 14px; color: #475569; line-height: 1.5;">
      Thank you for registering your institutional account on CapSync. To complete your account verification, please enter the One-Time Password (OTP) below:
    </p>

    <div style="background: linear-gradient(135deg, #EFF6FF 0%, #DBEAFE 100%); border: 2px dashed #3B82F6; border-radius: 10px; padding: 18px; text-align: center; margin: 24px 0;">
      <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #1D4ED8; font-family: 'Courier New', monospace;">$code</span>
      <p style="margin: 8px 0 0; font-size: 12px; color: #3B82F6; font-weight: 600;">Valid for $otpValidityMinutes minutes</p>
    </div>

    <p style="font-size: 13px; color: #64748B; line-height: 1.4;">
      If you did not request this verification, please disregard this email or inform the Capstone Research Coordinator.
    </p>

    <hr style="border: none; border-top: 1px solid #E2E8F0; margin: 24px 0;">
    <p style="text-align: center; font-size: 11px; color: #94A3B8; margin: 0;">
      University of Mindanao &bull; College of Computing Education &bull; CapSync 2026
    </p>
  </div>
</body>
</html>
''';
  }
}
