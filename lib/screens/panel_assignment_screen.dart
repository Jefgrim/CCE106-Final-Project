// =============================================================================
// FILE: lib/screens/panel_assignment_screen.dart
// CORE REQUIREMENT: Panel & Adviser Assignment Viewer
// Allows students to instantly view officially assigned advisers and panel members,
// ensuring requests route to the correct faculty.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/faculty_card.dart';

class PanelAssignmentScreen extends StatelessWidget {
  final AppState appState;
  final Function(int) onNavigateTab;

  const PanelAssignmentScreen({
    super.key,
    required this.appState,
    required this.onNavigateTab,
  });

  void _navigateToFacultyCalendar(BuildContext context, FacultyMember faculty) {
    appState.setFacultyFilter(faculty.id);
    onNavigateTab(0); // Switch to Availability Dashboard tab
  }

  @override
  Widget build(BuildContext context) {
    final group = appState.currentStudentGroup;
    final adviser = appState.currentAssignedAdviser;
    final leadPanelist = appState.currentAssignedLeadPanelist;
    final panelists = appState.currentAssignedPanelists;

    if (group == null) {
      return RefreshIndicator(
        onRefresh: () => appState.refreshData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_off_outlined, size: 52, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Awaiting Capstone Group Assignment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You are not yet assigned to an official Capstone Group. The Research Coordinator / Dean will officially organize your group and assign your Capstone Adviser and Defense Panelists in the coordination portal.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => appState.refreshData(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Check for Assignment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Capstone Project Overview Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryNavy, AppColors.royalBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    group.groupNumber.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Group Members:',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: group.studentMembers.map((member) {
                    final isLeader = member.contains('(Leader)');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        member,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: isLeader ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Section Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 18, color: AppColors.primaryNavy),
                SizedBox(width: 6),
                Text(
                  'Officially Assigned Faculty',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Endorsed by the IT College Capstone Coordinator. Consultations are routed strictly to these faculty members.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Assigned Project Adviser
          if (adviser != null)
            FacultyCard(
              faculty: adviser,
              roleBadgeTitle: 'Official Capstone Adviser',
              roleColor: AppColors.primaryNavy,
              appState: appState,
              onSelectFaculty: () => _navigateToFacultyCalendar(context, adviser),
            ),

          // 3. Assigned Lead Panelist
          if (leadPanelist != null)
            FacultyCard(
              faculty: leadPanelist,
              roleBadgeTitle: 'Lead Panelist / Defense Chair',
              roleColor: AppColors.primaryBlue,
              appState: appState,
              onSelectFaculty: () => _navigateToFacultyCalendar(context, leadPanelist),
            ),

          // 4. Assigned Panel Members
          ...panelists.map((panelist) {
            return FacultyCard(
              faculty: panelist,
              roleBadgeTitle: 'Capstone Panel Member',
              roleColor: AppColors.royalBlue,
              appState: appState,
              onSelectFaculty: () => _navigateToFacultyCalendar(context, panelist),
            );
          }),
        ],
      ),
    ),
    );
  }
}
