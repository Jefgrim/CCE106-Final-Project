// =============================================================================
// FILE: lib/screens/auth/register_screen.dart
// Institutional registration for students and Research Coordinator/Dean.
// Note: Teachers/Faculty accounts are exclusively provisioned by the Coordinator/Dean.
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/email_otp_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AppState appState;

  const RegisterScreen({
    super.key,
    required this.appState,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _capstoneTitleController = TextEditingController();
  final _adminPasscodeController = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  bool _isLoading = false;
  String? _errorMessage;

  static const String _deanPasscode = 'DEAN2026';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _idNumberController.dispose();
    _capstoneTitleController.dispose();
    _adminPasscodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate Coordinator passcode
    if (_selectedRole == UserRole.coordinator) {
      if (_adminPasscodeController.text.trim() != _deanPasscode) {
        setState(() {
          _errorMessage = 'Invalid Administrative Passcode. Only authorized Research Coordinators and Deans may register this role.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final idNumber = _idNumberController.text.trim();
    final capstoneTitle = _capstoneTitleController.text.trim();

    // Strictly validate @umindanao.edu.ph domain
    if (!EmailOtpService.isAllowedDomain(email)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Registration is restricted strictly to official @umindanao.edu.ph institutional emails.';
      });
      return;
    }

    // Check if account already exists with this institutional email
    final exists = widget.appState.allUsers.any((u) => u.email.toLowerCase() == email);
    if (exists) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An account with this institutional email ($email) already exists. Please sign in instead.';
      });
      return;
    }

    final initials = name.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
    final newId = 'usr-${DateTime.now().millisecondsSinceEpoch}';

    User newUser;
    if (_selectedRole == UserRole.student) {
      newUser = Student(
        id: newId,
        name: name,
        email: email,
        avatarInitials: initials.isEmpty ? 'ST' : initials,
        studentIdNumber: idNumber,
        groupId: '', // Starts unassigned; Research Coordinator assigns group & faculty
        capstoneTitle: capstoneTitle.isEmpty ? 'Pending Group Assignment' : capstoneTitle,
        yearLevel: '4th Year BSIT',
      );
    } else {
      newUser = Coordinator(
        id: newId,
        name: name,
        email: email,
        avatarInitials: initials.isEmpty ? 'CR' : initials,
        officeLocation: idNumber.isEmpty ? 'Office of the Dean, 3rd Floor' : idNumber,
        academicYear: 'A.Y. 2026-2027',
      );
    }

    // Register user in Firebase Auth (which automatically dispatches the verification link)
    final registered = await widget.appState.register(newUser, password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (registered) {
      // Navigate to EmailVerificationScreen to await confirmation
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            appState: widget.appState,
            user: newUser,
            password: password,
          ),
        ),
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
      appBar: AppBar(
        title: const Text('Create New Account'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'UM IT College Registration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedRole == UserRole.student
                            ? 'Register a student account to consult with advisers and panel defense chairs.'
                            : 'Register as Dean or Capstone Research Coordinator.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(_errorMessage!, style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Role Selector: Student vs Research Coordinator/Dean
                      const Text('Account Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Student'),
                              selected: _selectedRole == UserRole.student,
                              selectedColor: AppColors.lightBlue,
                              labelStyle: TextStyle(
                                color: _selectedRole == UserRole.student ? AppColors.primaryBlue : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedRole = UserRole.student);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Dean / Coordinator'),
                              selected: _selectedRole == UserRole.coordinator,
                              selectedColor: AppColors.primaryNavy.withValues(alpha: 0.12),
                              labelStyle: TextStyle(
                                color: _selectedRole == UserRole.coordinator ? AppColors.primaryNavy : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedRole = UserRole.coordinator);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Notice regarding Faculty registration
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Teacher / Faculty accounts are provisioned exclusively by the Research Coordinator.',
                                style: TextStyle(fontSize: 11, color: AppColors.primaryNavy),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Admin Passcode field if Coordinator selected
                      if (_selectedRole == UserRole.coordinator) ...[
                        TextFormField(
                          controller: _adminPasscodeController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Administrative Passcode',
                            prefixIcon: const Icon(Icons.security, size: 20, color: AppColors.primaryNavy),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (val) {
                            if (_selectedRole == UserRole.coordinator && (val == null || val.trim().isEmpty)) {
                              return 'Administrative passcode is required for Coordinator role';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
                      ),

                      const SizedBox(height: 12),

                      // Institutional Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'UM Institutional Email',
                          hintText: 'e.g. carlos.mendoza@umindanao.edu.ph',
                          helperText: 'Must end with @umindanao.edu.ph',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter your institutional email';
                          }
                          if (!EmailOtpService.isAllowedDomain(val)) {
                            return 'Only official @umindanao.edu.ph emails are permitted';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ID Number / Office
                      TextFormField(
                        controller: _idNumberController,
                        decoration: InputDecoration(
                          labelText: _selectedRole == UserRole.student ? 'Student ID Number' : 'Office Location',
                          prefixIcon: Icon(_selectedRole == UserRole.student ? Icons.badge_outlined : Icons.room_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? (_selectedRole == UserRole.student ? 'Enter your student ID number' : 'Enter office location')
                            : null,
                      ),

                      if (_selectedRole == UserRole.student) ...[
                        const SizedBox(height: 12),
                        // Capstone Title
                        TextFormField(
                          controller: _capstoneTitleController,
                          decoration: InputDecoration(
                            labelText: 'Capstone Project Title',
                            prefixIcon: const Icon(Icons.school_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),

                      // Email verification notice
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.mark_email_read_outlined, size: 18, color: AppColors.primaryNavy),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'A verification link will be sent to your UM institutional email via Firebase.',
                                style: TextStyle(fontSize: 11, color: AppColors.primaryNavy, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Register Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryNavy,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Complete Registration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
