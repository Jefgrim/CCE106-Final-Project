// =============================================================================
// FILE: lib/widgets/user_avatar.dart
// Unified User Avatar Widget supporting Base64 online photos, Network URLs,
// and Initial-based colored fallbacks with graceful error handling.
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final User? user;
  final String? photoUrl;
  final String? initials;
  final double radius;
  final Color? backgroundColor;
  final double? fontSize;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.user,
    this.photoUrl,
    this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.fontSize,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  Color _resolveColor() {
    if (backgroundColor != null) return backgroundColor!;
    if (user != null) {
      switch (user!.role) {
        case UserRole.student:
          return AppColors.primaryBlue;
        case UserRole.faculty:
          return AppColors.royalBlue;
        case UserRole.coordinator:
          return AppColors.primaryNavy;
      }
    }
    return AppColors.primaryNavy;
  }

  String _resolveInitials() {
    if (initials != null && initials!.isNotEmpty) return initials!;
    if (user != null && user!.avatarInitials.isNotEmpty) return user!.avatarInitials;
    return 'U';
  }

  String? _resolvePhoto() {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) return photoUrl!.trim();
    if (user != null && user!.photoUrl != null && user!.photoUrl!.trim().isNotEmpty) {
      return user!.photoUrl!.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = _resolvePhoto();
    final effectiveInitials = _resolveInitials();
    final effectiveColor = _resolveColor();
    final effectiveFontSize = fontSize ?? (radius * 0.75);

    Widget fallbackContent = Text(
      effectiveInitials,
      style: TextStyle(
        fontSize: effectiveFontSize,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    Widget? avatarChild;

    if (photo != null) {
      try {
        if (photo.startsWith('data:image') || photo.length > 100) {
          // Base64 encoded online image
          final base64String = photo.contains(',') ? photo.split(',').last : photo;
          final bytes = base64Decode(base64String.trim());
          avatarChild = ClipOval(
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(child: fallbackContent),
            ),
          );
        } else if (photo.startsWith('http')) {
          // Standard web HTTPS image
          avatarChild = ClipOval(
            child: Image.network(
              photo,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(child: fallbackContent),
            ),
          );
        }
      } catch (_) {
        avatarChild = null;
      }
    }

    final avatarWidget = CircleAvatar(
      radius: radius,
      backgroundColor: effectiveColor,
      child: avatarChild ?? fallbackContent,
    );

    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white,
            width: borderWidth,
          ),
        ),
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
