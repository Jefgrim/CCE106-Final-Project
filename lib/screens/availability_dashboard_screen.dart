// =============================================================================
// FILE: lib/screens/availability_dashboard_screen.dart
// CORE REQUIREMENT: Displays real-time schedules of advisers and panelists,
// highlighting open dates and time slots with ListView.builder.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/time_slot_tile.dart';

class AvailabilityDashboardScreen extends StatelessWidget {
  final AppState appState;
  final Function(int)? onNavigateTab;

  const AvailabilityDashboardScreen({
    super.key,
    required this.appState,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDate = appState.selectedDate;
    final filteredSlots = appState.dashboardFilteredSlots;
    final isStudent = appState.currentUser is Student;
    final assignedFaculty = isStudent
        ? appState.allAssignedFacultyForStudent
        : appState.facultyList;

    // Generate next 7 days for the horizontal calendar selector
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysList = List.generate(7, (i) => today.add(Duration(days: i)));

    return Column(
      children: [
        // 1. Calendar Day Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: today,
                          lastDate: today.add(const Duration(days: 60)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primaryNavy,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.black87,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          appState.setSelectedDate(picked);
                        }
                      },
                      icon: const Icon(Icons.date_range, size: 16, color: AppColors.primaryNavy),
                      label: const Text(
                        'Select Date',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryNavy),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Horizontal Date Selector
              SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: daysList.length,
                  itemBuilder: (context, index) {
                    final date = daysList[index];
                    final isSelected = date.year == selectedDate.year &&
                        date.month == selectedDate.month &&
                        date.day == selectedDate.day;

                    final dayName = DateFormat('EEE').format(date); // e.g. Mon
                    final dayNum = DateFormat('d').format(date);    // e.g. 15

                    return GestureDetector(
                      onTap: () => appState.setSelectedDate(date),
                      child: Container(
                        width: 58,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryNavy : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryNavy : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryNavy.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.skyBlue : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayNum,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 2. Faculty Filter Chips Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Assigned Faculty'),
                  selected: appState.selectedFacultyFilterId == null,
                  selectedColor: AppColors.lightBlue,
                  checkmarkColor: AppColors.primaryNavy,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: appState.selectedFacultyFilterId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: appState.selectedFacultyFilterId == null
                        ? AppColors.primaryNavy
                        : Colors.black87,
                  ),
                  onSelected: (selected) {
                    if (selected) appState.setFacultyFilter(null);
                  },
                ),
                const SizedBox(width: 8),
                ...assignedFaculty.map((faculty) {
                  final isSelected = appState.selectedFacultyFilterId == faculty.id;
                  final isAdviser = appState.currentAssignedAdviser?.id == faculty.id;
                  final isLead = appState.currentAssignedLeadPanelist?.id == faculty.id;

                  String suffix = '';
                  if (isAdviser) suffix = ' (Adviser)';
                  if (isLead) suffix = ' (Lead)';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${faculty.name.split(' ').first}$suffix'),
                      selected: isSelected,
                      selectedColor: AppColors.lightBlue,
                      checkmarkColor: AppColors.primaryNavy,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primaryNavy : Colors.black87,
                      ),
                      onSelected: (selected) {
                        appState.setFacultyFilter(selected ? faculty.id : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Header Summary with Double-Booking Safety Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.background,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Schedule for ${DateFormat('EEE, MMM d').format(selectedDate)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
              ),
              Text(
                '${filteredSlots.length} Available Slots',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),

        // 4. Slots ListView.builder (Core Requirement from Chapter 1 with Pull-to-Refresh)
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryNavy,
            onRefresh: () async {
              await appState.refreshData();
            },
            child: filteredSlots.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy_rounded,
                                  size: 56,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  appState.currentStudentGroup == null && isStudent
                                      ? 'Awaiting Faculty Assignment'
                                      : 'No Available Consultation Slots on ${DateFormat('MMMM d').format(selectedDate)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isStudent
                                      ? (appState.currentStudentGroup == null
                                          ? 'You are not yet assigned to an official Capstone Group. The Research Coordinator / Dean will assign your group along with your adviser and panel members.'
                                          : 'Your assigned adviser and panelists have no upcoming available consultation slots for this date. Past slots and booked slots are excluded. Try choosing another date on the calendar above or swipe down to refresh.')
                                      : 'You have no upcoming available consultation slots for this date. Open slots in the "My Schedule" tab.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: filteredSlots.length,
                    itemBuilder: (context, index) {
                      final slot = filteredSlots[index];
                      return TimeSlotTile(
                        slot: slot,
                        appState: appState,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
