// =============================================================================
// FILE: lib/screens/auth/otp_verification_screen.dart
// Institutional email OTP verification screen for CapSync.
// Provides 6-digit PIN input with auto-advance, clipboard paste support,
// resend countdown timer, evaluation demo helpers, and atomic registration completion.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../services/email_otp_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../main_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final AppState appState;
  final User pendingUser;
  final String password;
  final EmailOtpService otpService;

  const OtpVerificationScreen({
    super.key,
    required this.appState,
    required this.pendingUser,
    required this.password,
    required this.otpService,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _digitControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _cooldownSeconds = EmailOtpService.resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();

    // Auto-focus first digit on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCooldownTimer() {
    _countdownTimer?.cancel();
    setState(() => _cooldownSeconds = EmailOtpService.resendCooldownSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentEnteredOtp {
    return _digitControllers.map((c) => c.text.trim()).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handles pasting multiple digits into a box
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        _fillDigits(digits);
      }
      return;
    }

    if (value.isNotEmpty) {
      // Move to next digit
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Automatically verify when all 6 digits are entered
        if (_currentEnteredOtp.length == 6) {
          _handleVerifyOtp();
        }
      }
    }
  }

  void _fillDigits(String code) {
    final cleanDigits = code.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < 6; i++) {
      if (i < cleanDigits.length) {
        _digitControllers[i].text = cleanDigits[i];
      } else {
        _digitControllers[i].clear();
      }
    }
    if (cleanDigits.length >= 6) {
      _focusNodes[5].unfocus();
      _handleVerifyOtp();
    } else {
      _focusNodes[cleanDigits.length].requestFocus();
    }
    setState(() {});
  }

  Future<void> _handleResendCode() async {
    if (_cooldownSeconds > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await widget.otpService.sendRegistrationOtp(
      email: widget.pendingUser.email,
      userName: widget.pendingUser.name,
      forceNew: true,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res.success) {
      _startCooldownTimer();
      // Clear inputs
      for (final c in _digitControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.primaryNavy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _errorMessage = res.message);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final enteredCode = _currentEnteredOtp;
    if (enteredCode.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of your verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Verify OTP with service
    final verifyResult = widget.otpService.verifyOtp(
      email: widget.pendingUser.email,
      code: enteredCode,
    );

    if (!verifyResult.isSuccess) {
      setState(() {
        _isLoading = false;
        _errorMessage = verifyResult.message;
      });
      return;
    }

    // 2. Complete Account Registration in AppState
    final success = await widget.appState.register(widget.pendingUser, widget.password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email verified! Welcome to CapSync, ${widget.pendingUser.name}.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainScreen(appState: widget.appState)),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = 'An account with this email already exists or registration could not be completed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Institutional Header Badge
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.5), width: 2),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 38,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Verify Your Institutional Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'We have generated and dispatched a 6-digit One-Time Password (OTP) to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),

                    // Target email badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.email, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.pendingUser.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primaryNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.primaryNavy),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Please check your @umindanao.edu.ph inbox (and Spam/Junk folder) for the 6-digit verification code.',
                              style: TextStyle(fontSize: 11, color: AppColors.primaryNavy, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 18, color: Colors.red.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6 Digit PIN Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 44,
                          height: 54,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey == LogicalKeyboardKey.backspace &&
                                  _digitControllers[index].text.isEmpty &&
                                  index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                            },
                            child: TextFormField(
                              controller: _digitControllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                filled: true,
                                fillColor: Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
                                ),
                              ),
                              onChanged: (val) => _onDigitChanged(index, val),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Verify Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Verify & Complete Registration',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Resend Code and Timer (Wrap prevents horizontal RenderFlex overflow)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _cooldownSeconds > 0
                              ? 'Didn\'t receive code? Resend in ${_cooldownSeconds}s'
                              : 'Didn\'t receive the code? ',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (_cooldownSeconds == 0)
                          TextButton(
                            onPressed: _isLoading ? null : _handleResendCode,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Registration Details', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
