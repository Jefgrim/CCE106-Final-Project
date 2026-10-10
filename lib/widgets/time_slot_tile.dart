// =============================================================================
// FILE: lib/widgets/time_slot_tile.dart
// Renders an individual consultation time slot item inside ListView.builder.
// Displays time window, mode, location, faculty info, and dynamic booking CTA.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/time_slot.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../screens/booking_form_screen.dart';
import '../theme/app_colors.dart';
import 'user_avatar.dart';

class TimeSlotTile extends StatelessWidget {
  final TimeSlot slot;
  final AppState appState;

  const TimeSlotTile({
    super.key,
    required this.slot,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final faculty = appState.getFacultyById(slot.facultyId);
    final isStudent = appState.currentUser is Student;
    final isFacultyOwner = appState.currentUser?.id == slot.facultyId;

    // Check relationship with student
    String facultyRoleTag = 'Faculty Member';
    Color tagColor = Colors.grey.shade700;

    if (appState.currentAssignedAdviser?.id == slot.facultyId) {
      facultyRoleTag = 'Assigned Adviser';
      tagColor = AppColors.primaryNavy;
    } else if (appState.currentAssignedLeadPanelist?.id == slot.facultyId) {
      facultyRoleTag = 'Lead Panelist';
      tagColor = AppColors.primaryBlue;
    } else if (appState.currentAssignedPanelists.any((p) => p.id == slot.facultyId)) {
      facultyRoleTag = 'Panel Member';
      tagColor = const Color(0xFF0284C7);
    }

    final isBooked = slot.isBooked;

    return Card(
      elevation: isBooked ? 0.5 : 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isBooked ? Colors.grey.shade300 : AppColors.primaryBlue.withValues(alpha: 0.25),
          width: isBooked ? 1 : 1.5,
        ),
      ),
      color: isBooked ? Colors.grey.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Time, Mode & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time Range
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: isBooked ? Colors.grey : AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      slot.timeRange,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isBooked ? Colors.grey.shade700 : const Color(0xFF212121),
                      ),
                    ),
                  ],
                ),

                // Availability Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? Colors.red.shade50
                        : AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isBooked ? Colors.red.shade200 : AppColors.skyBlue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBooked ? Icons.lock_clock_rounded : Icons.check_circle_outline_rounded,
                        size: 12,
                        color: isBooked ? AppColors.error : AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBooked ? 'BOOKED' : 'AVAILABLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isBooked ? AppColors.error : AppColors.primaryBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Faculty Information & Role Tag
            Row(
              children: [
                UserAvatar(
                  user: faculty,
                  radius: 16,
                  fontSize: 11,
                  backgroundColor: isBooked ? Colors.grey.shade400 : AppColors.primaryNavy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faculty?.name ?? 'Faculty Member',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isBooked ? Colors.grey.shade700 : Colors.black87,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          facultyRoleTag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tagColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 3: Location / Google Meet & Action Button
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        slot.mode == ConsultationMode.inPerson
                            ? Icons.meeting_room_outlined
                            : Icons.video_camera_front_outlined,
                        size: 15,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          slot.locationOrLink,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Dynamic Action Button
                if (isStudent)
                  ElevatedButton(
                    onPressed: isBooked
                        ? null // Prevent clicking booked slots
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => BookingFormScreen(
                                  slot: slot,
                                  appState: appState,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade500,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: isBooked ? 0 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isBooked ? 'Reserved' : 'Book Slot',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isFacultyOwner)
                  if (!isBooked)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(fontSize: 12, color: Colors.red)),
                      onPressed: () {
                        appState.removeFacultySlot(slot.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Time slot removed.')),
                        );
                      },
                    )
                  else
                    const Text(
                      'Booked by Students',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
