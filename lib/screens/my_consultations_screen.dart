// =============================================================================
// FILE: lib/screens/my_consultations_screen.dart
// Displays student consultation history, active status, notes, and allows
// real-time cancellation (which releases the slot back to available).
// =============================================================================

import 'package:flutter/material.dart';
import '../models/consultation_booking.dart';
import '../models/time_slot.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

class MyConsultationsScreen extends StatefulWidget {
  final AppState appState;

  const MyConsultationsScreen({super.key, required this.appState});

  @override
  State<MyConsultationsScreen> createState() => _MyConsultationsScreenState();
}

class _MyConsultationsScreenState extends State<MyConsultationsScreen> {
  String _activeFilter = 'ALL';

  Color _getStatusColor(ConsultationBooking booking) {
    if (booking.isCancelled) return AppColors.error;
    if (booking.isPastOrCompleted) return AppColors.primaryNavy.withValues(alpha: 0.6);
    switch (booking.status) {
      case BookingStatus.confirmed:
        return AppColors.success;
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.completed:
        return AppColors.primaryBlue;
      case BookingStatus.cancelled:
        return AppColors.error;
    }
  }

  void _confirmCancel(ConsultationBooking booking) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Consultation?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel your consultation with ${booking.facultyName} on ${booking.formattedDate}?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'The reserved time slot will immediately be released and made available to other students.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final success = widget.appState.cancelBooking(
                booking,
                reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
              );
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consultation cancelled. Slot is now freed.'),
                    backgroundColor: AppColors.primaryNavy,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allBookings = widget.appState.currentStudentBookings;
    final activeBookings = allBookings.where((b) => b.isActive).toList();
    final pastBookings = allBookings.where((b) => b.isPastOrCompleted).toList();
    final cancelledBookings = allBookings.where((b) => b.isCancelled).toList();

    final filteredBookings = allBookings.where((b) {
      if (_activeFilter == 'ACTIVE') return b.isActive;
      if (_activeFilter == 'PAST') return b.isPastOrCompleted;
      if (_activeFilter == 'CANCELLED') return b.isCancelled;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All (${allBookings.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('ACTIVE', 'Active (${activeBookings.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('PAST', 'Past (${pastBookings.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('CANCELLED', 'Cancelled (${cancelledBookings.length})'),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryNavy,
            onRefresh: () async {
              await widget.appState.refreshData();
            },
            child: filteredBookings.isEmpty
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
                                Icon(Icons.event_note_outlined, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Consultations Found',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _activeFilter == 'ALL'
                                      ? 'You have not booked any consultations yet. Browse open slots in the Availability tab.'
                                      : 'No $_activeFilter consultations in your history. Swipe down to refresh.',
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    final statusColor = _getStatusColor(booking);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status & Time Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    booking.displayStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Booked ${booking.formattedCreatedAt}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Faculty Name & Type
                            Text(
                              booking.facultyName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              booking.type.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Date & Time
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryNavy),
                                const SizedBox(width: 6),
                                Text(
                                  booking.formattedDate,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.access_time, size: 14, color: AppColors.primaryNavy),
                                const SizedBox(width: 6),
                                Text(
                                  booking.timeRange,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Mode & Location
                            Row(
                              children: [
                                Icon(
                                  booking.mode == ConsultationMode.inPerson
                                      ? Icons.location_on_outlined
                                      : Icons.videocam_outlined,
                                  size: 14,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${booking.mode.label} • ${booking.locationOrLink}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Agenda Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Consultation Agenda:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    booking.agenda,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                  ),
                                  if (booking.documentUrl != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.link, size: 12, color: Color(0xFF1976D2)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            booking.documentUrl!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1976D2),
                                              decoration: TextDecoration.underline,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Faculty Remarks (if present)
                            if (booking.facultyNotes != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Text(
                                  'Faculty Notes: ${booking.facultyNotes}',
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                ),
                              ),
                            ],

                            // Action: Cancel Button
                            if (booking.isActive) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmCancel(booking),
                                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                                  label: const Text(
                                    'Cancel Consultation',
                                    style: TextStyle(fontSize: 11, color: Colors.red),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _activeFilter == filterKey;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.lightBlue,
      checkmarkColor: AppColors.primaryNavy,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryNavy : Colors.black87,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _activeFilter = filterKey);
      },
    );
  }
}
