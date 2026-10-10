// =============================================================================
// FILE: lib/widgets/faculty_card.dart
// Renders officially assigned faculty member cards for the Assignment Viewer.
// Displays rank, room, expertise tags, and quick-action to jump to their calendar.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'user_avatar.dart';

class FacultyCard extends StatelessWidget {
  final FacultyMember faculty;
  final String roleBadgeTitle;
  final Color roleColor;
  final AppState appState;
  final VoidCallback onSelectFaculty;

  const FacultyCard({
    super.key,
    required this.faculty,
    required this.roleBadgeTitle,
    required this.roleColor,
    required this.appState,
    required this.onSelectFaculty,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: roleColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Role Badge & Avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  user: faculty,
                  radius: 26,
                  fontSize: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleBadgeTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: roleColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        faculty.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Office / Room (if set)
            if (faculty.consultationRoom.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      faculty.consultationRoom,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Email
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    faculty.email,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),

            // Expertise Chips (if set)
            if (faculty.expertiseTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: faculty.expertiseTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(fontSize: 10, color: AppColors.primaryNavy, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),

            // Action Button: View Availability
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSelectFaculty,
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text(
                  'View Consultation Hours & Slots',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
