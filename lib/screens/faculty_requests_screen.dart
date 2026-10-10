// =============================================================================
// FILE: lib/screens/faculty_requests_screen.dart
// Displays consultation requests received by the faculty member.
// Allows confirming or adding feedback notes for students.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/consultation_booking.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

class FacultyRequestsScreen extends StatefulWidget {
  final AppState appState;

  const FacultyRequestsScreen({super.key, required this.appState});

  @override
  State<FacultyRequestsScreen> createState() => _FacultyRequestsScreenState();
}

class _FacultyRequestsScreenState extends State<FacultyRequestsScreen> {
  String _activeFilter = 'UPCOMING';

  void _showAddNotesDialog(BuildContext context, ConsultationBooking booking) {
    final notesController = TextEditingController(text: booking.facultyNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primaryNavy),
            SizedBox(width: 8),
            Text('Consultation Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add instructions for Group ${booking.groupId.replaceAll("grp-", "")} (${booking.studentName}):',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Preparation Instructions / Notes for Students',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.appState.addBookingNote(booking, notesController.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note saved and sent to students.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primaryNavy : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.lightBlue,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _activeFilter = key),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appState.currentUser is! FacultyMember) {
      return const Center(child: Text('Only faculty members can access this screen.'));
    }

    final allBookings = widget.appState.currentFacultyBookings;
    final upcomingBookings = allBookings.where((b) => b.isActive).toList();
    final pastBookings = allBookings.where((b) => b.isPastOrCompleted).toList();

    final filteredBookings = allBookings.where((b) {
      if (_activeFilter == 'UPCOMING') return b.isActive;
      if (_activeFilter == 'PAST') return b.isPastOrCompleted;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildFilterChip('UPCOMING', 'Upcoming (${upcomingBookings.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('PAST', 'Past (${pastBookings.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('ALL', 'All (${allBookings.length})'),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: filteredBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 50, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _activeFilter == 'UPCOMING'
                            ? 'No Active Upcoming Consultations'
                            : 'No $_activeFilter Consultations Found',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeFilter == 'UPCOMING'
                            ? 'Upcoming student consultations will appear here.'
                            : 'No consultations match this filter.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final b = filteredBookings[index];
                    final isPast = b.isPast();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isPast ? Colors.grey.shade200 : AppColors.lightBlue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    b.displayStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isPast ? Colors.grey.shade700 : AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${b.formattedDate} • ${b.timeRange}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Group ${b.groupId.replaceAll('grp-', '')} • ${b.studentName}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              b.capstoneTitle,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Agenda: ${b.agenda}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  if (b.documentUrl != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Materials: ${b.documentUrl}',
                                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (b.facultyNotes != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Your Notes: ${b.facultyNotes}',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primaryNavy),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showAddNotesDialog(context, b),
                                  icon: const Icon(Icons.note_add_outlined, size: 16),
                                  label: Text(
                                    b.facultyNotes != null ? 'Edit Note' : 'Add Note',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
