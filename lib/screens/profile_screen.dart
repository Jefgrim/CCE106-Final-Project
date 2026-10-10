// =============================================================================
// FILE: lib/screens/profile_screen.dart
// UNIVERSAL PROFILE MANAGEMENT & SECURITY SCREEN
// Allows Students, Faculty Members, and Coordinators/Deans to update their
// profile details and change account passwords.
// Strictly adheres to CapSync official brand palette and design system.
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final AppState appState;

  const ProfileScreen({
    super.key,
    required this.appState,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _roomController;
  late TextEditingController _expertiseController;
  late TextEditingController _titleController;
  late TextEditingController _officeController;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isSavingProfile = false;
  bool _isUpdatingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = widget.appState.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');

    if (user is FacultyMember) {
      _roomController = TextEditingController(text: user.consultationRoom);
      _expertiseController = TextEditingController(text: user.expertiseTags.join(', '));
    } else {
      _roomController = TextEditingController();
      _expertiseController = TextEditingController();
    }

    if (user is Student) {
      _titleController = TextEditingController(text: user.capstoneTitle);
    } else {
      _titleController = TextEditingController();
    }

    if (user is Coordinator) {
      _officeController = TextEditingController(text: user.officeLocation);
    } else {
      _officeController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _expertiseController.dispose();
    _titleController.dispose();
    _officeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return AppColors.primaryBlue;
      case UserRole.faculty:
        return AppColors.royalBlue;
      case UserRole.coordinator:
        return AppColors.primaryNavy;
    }
  }

  Future<void> _handleSaveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _isSavingProfile = true);

    final user = widget.appState.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    final initials = newName.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
    final newInitials = initials.isEmpty ? user.avatarInitials : initials;

    User updatedUser;
    if (user is FacultyMember) {
      final tags = _expertiseController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      updatedUser = user.copyWith(
        name: newName,
        avatarInitials: newInitials,
        consultationRoom: _roomController.text.trim(),
        expertiseTags: tags,
      );
    } else if (user is Student) {
      updatedUser = user.copyWith(
        name: newName,
        avatarInitials: newInitials,
        capstoneTitle: _titleController.text.trim(),
      );
    } else if (user is Coordinator) {
      updatedUser = user.copyWith(
        name: newName,
        avatarInitials: newInitials,
        officeLocation: _officeController.text.trim(),
      );
    } else {
      setState(() => _isSavingProfile = false);
      return;
    }

    final success = await widget.appState.updateUserProfile(updatedUser);

    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Profile changes saved successfully!' : 'Failed to update profile. Please try again.'),
        backgroundColor: success ? AppColors.primaryNavy : AppColors.error,
      ),
    );
  }

  Future<void> _handleUpdatePhoto(String? newPhotoUrl) async {
    final user = widget.appState.currentUser;
    if (user == null) return;
    setState(() => _isSavingProfile = true);

    User updatedUser;
    if (user is Student) {
      updatedUser = user.copyWith(photoUrl: newPhotoUrl);
    } else if (user is FacultyMember) {
      updatedUser = user.copyWith(photoUrl: newPhotoUrl);
    } else if (user is Coordinator) {
      updatedUser = user.copyWith(photoUrl: newPhotoUrl);
    } else {
      setState(() => _isSavingProfile = false);
      return;
    }

    final success = await widget.appState.updateUserProfile(updatedUser);
    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (newPhotoUrl != null
                  ? 'Profile photo updated and saved online!'
                  : 'Profile photo removed successfully.')
              : 'Failed to update photo. Please try again.',
        ),
        backgroundColor: success ? AppColors.primaryNavy : AppColors.error,
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 75,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await _handleUpdatePhoto(base64String);
    } catch (e) {
      debugPrint("Error picking profile photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPhotoOptionsSheet() {
    final user = widget.appState.currentUser;
    final hasPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lightBlue,
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.primaryNavy),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Use your phone camera'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lightBlue,
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primaryNavy),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an image from device gallery'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                  subtitle: const Text('Revert back to role initials avatar'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _handleUpdatePhoto(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isUpdatingPassword = true);

    final newPassword = _newPasswordController.text.trim();
    final success = await widget.appState.changePassword(newPassword);

    if (!mounted) return;
    setState(() => _isUpdatingPassword = false);

    if (success) {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password successfully changed! Your new password is now active.'),
          backgroundColor: AppColors.primaryNavy,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update password. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Management')),
        body: const Center(child: Text('No active session.')),
      );
    }

    final roleColor = _getRoleColor(user.role);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. User Identity Header Card
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            UserAvatar(
                              user: user,
                              radius: 36,
                              fontSize: 22,
                              showBorder: true,
                              borderColor: roleColor.withValues(alpha: 0.35),
                              borderWidth: 2,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: AppColors.primaryNavy,
                                shape: const CircleBorder(),
                                elevation: 2,
                                child: InkWell(
                                  onTap: _showPhotoOptionsSheet,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      user.role.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: roleColor,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _showPhotoOptionsSheet,
                                    icon: const Icon(Icons.photo_camera_rounded, size: 13, color: AppColors.primaryBlue),
                                    label: Text(
                                      user.photoUrl != null && user.photoUrl!.isNotEmpty ? 'Change' : 'Upload',
                                      style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user.name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.department,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Profile Details Form Card
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _profileFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 20, color: roleColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Profile Information',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Full Name (All Users)
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter full name' : null,
                          ),
                          const SizedBox(height: 14),

                          // Student-Specific Details
                          if (user is Student) ...[
                            TextFormField(
                              initialValue: user.studentIdNumber,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Student ID Number (Verified)',
                                prefixIcon: Icon(Icons.credit_card, size: 20),
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Capstone Project Title',
                                prefixIcon: Icon(Icons.school_outlined, size: 20),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.group_outlined, size: 18, color: AppColors.primaryBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      user.groupId.isNotEmpty
                                          ? 'Capstone Group: ${user.groupId}'
                                          : 'Group Assignment: Awaiting Research Coordinator group organization',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primaryNavy),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Faculty-Specific Details
                          if (user is FacultyMember) ...[
                            TextFormField(
                              initialValue: user.facultyIdNumber,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Faculty ID Number',
                                prefixIcon: Icon(Icons.badge, size: 20),
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                labelText: 'Consultation Room / Office',
                                prefixIcon: Icon(Icons.room_outlined, size: 20),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _expertiseController,
                              decoration: const InputDecoration(
                                labelText: 'Expertise / Tags (Comma separated)',
                                prefixIcon: Icon(Icons.label_outlined, size: 20),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],

                          // Coordinator-Specific Details
                          if (user is Coordinator) ...[
                            TextFormField(
                              controller: _officeController,
                              decoration: const InputDecoration(
                                labelText: 'Dean / Coordinator Office Location',
                                prefixIcon: Icon(Icons.apartment_outlined, size: 20),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isSavingProfile ? null : _handleSaveProfile,
                              icon: _isSavingProfile
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Security & Password Change Card
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 20, color: AppColors.primaryNavy),
                              SizedBox(width: 8),
                              Text(
                                'Change Account Password',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          if (user is FacultyMember) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'If you were registered with a temporary password by the Coordinator, set your permanent password below.',
                                      style: TextStyle(fontSize: 11, color: AppColors.primaryNavy),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // New Password
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPass,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              helperText: 'Minimum 6 characters',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter new password';
                              if (v.trim().length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Confirm New Password
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPass,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Confirm your new password';
                              if (v.trim() != _newPasswordController.text.trim()) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isUpdatingPassword ? null : _handleUpdatePassword,
                              icon: _isUpdatingPassword
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.key_rounded, size: 18),
                              label: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
