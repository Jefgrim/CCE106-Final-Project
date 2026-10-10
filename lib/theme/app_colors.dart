// =============================================================================
// FILE: lib/theme/app_colors.dart
// CAPSYNC OFFICIAL BRAND COLOR PALETTE & DESIGN TOKENS
// Extracted from official logo and brand storyboard:
// "Cap" = Deep Academic Navy (#0D254C)
// "Sync" = Vibrant Electric Blue (#1877F2)
// Tagline: "Connect • Consult • Complete"
// =============================================================================

import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primaryNavy = Color(0xFF0D254C);    // Deep Academic Navy ("Cap")
  static const Color primaryBlue = Color(0xFF1877F2);    // Vibrant Electric Blue ("Sync")
  static const Color darkNavy = Color(0xFF071731);       // Midnight Background / Accents
  static const Color royalBlue = Color(0xFF0066E0);      // High-contrast Accent
  static const Color lightBlue = Color(0xFFEBF5FF);      // Subtle Card / Chip Tint
  static const Color skyBlue = Color(0xFF38BDF8);        // Halo & Glow Accent

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC);     // Clean Slate White
  static const Color surface = Colors.white;             // Card Surface
  static const Color border = Color(0xFFE2E8F0);          // Subtle Border Gray
  static const Color textPrimary = Color(0xFF0F172A);    // Slate Dark Text
  static const Color textSecondary = Color(0xFF64748B);  // Muted Label Gray

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color pending = Color(0xFF0284C7);

  // Brand Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryNavy, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkAmbientGradient = LinearGradient(
    colors: [Color(0xFF051124), Color(0xFF0B2144), Color(0xFF0E2F60)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueWaveGradient = LinearGradient(
    colors: [Color(0xFF0077E6), Color(0xFF1877F2), Color(0xFF38BDF8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Official Tagline
  static const String tagline = 'Connect • Consult • Complete';
}
