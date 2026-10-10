// =============================================================================
// FILE: lib/screens/booking_form_screen.dart
// CORE REQUIREMENT: Consultation Booking (RSVP) with Form Validation
// and Double-Booking Prevention.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/time_slot.dart';
import '../models/consultation_booking.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';

class BookingFormScreen extends StatefulWidget {
  final TimeSlot slot;
  final AppState appState;

  const BookingFormScreen({
    super.key,
    required this.slot,
    required this.appState,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agendaController = TextEditingController();
  final _documentUrlController = TextEditingController();

  ConsultationType? _selectedType;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _agendaController.dispose();
    _documentUrlController.dispose();
    super.dispose();
  }

  void _submitBooking() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a consultation purpose / stage.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Call encapsulated business logic via AppState
    final result = widget.appState.bookConsultation(
      slot: widget.slot,
      type: _selectedType!,
      agenda: _agendaController.text,
      documentUrl: _documentUrlController.text,
    );

    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 28),
              SizedBox(width: 8),
              Text('RSVP Confirmed!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your consultation slot has been successfully booked in real-time!',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty: ${widget.appState.getFacultyById(widget.slot.facultyId)?.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date & Time: ${widget.slot.formattedDate} • ${widget.slot.timeRange}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mode: ${widget.slot.mode.label}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Push notifications have been sent to both you and your adviser.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to dashboard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
              ),
              child: const Text('View My Bookings'),
            ),
          ],
        ),
      );
    } else {
      // Double-booking or validation error
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Booking Failed', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final faculty = widget.appState.getFacultyById(widget.slot.facultyId);
    final group = widget.appState.currentStudentGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RSVP Consultation Slot'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Slot Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          user: faculty,
                          radius: 18,
                          fontSize: 12,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faculty?.name ?? 'Faculty Member',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (faculty?.email != null && faculty!.email.isNotEmpty)
                                Text(
                                  faculty.email,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          widget.slot.formattedDate,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.access_time, size: 14, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          widget.slot.timeRange,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          widget.slot.mode == ConsultationMode.inPerson
                              ? Icons.location_on_outlined
                              : Icons.videocam_outlined,
                          size: 14,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.slot.mode.label} • ${widget.slot.locationOrLink}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Capstone Group Auto-Filled Info
              if (group != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group_work_outlined, size: 18, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Booking for ${group.groupNumber}: ${group.title}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // 3. Form Input: Consultation Type
              const Text(
                'Consultation Purpose / Stage *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<ConsultationType>(
                isExpanded: true,
                initialValue: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                hint: const Text('Select Consultation Purpose / Stage', overflow: TextOverflow.ellipsis),
                validator: (val) => val == null ? 'Please select consultation purpose' : null,
                items: ConsultationType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.label,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedType = val);
                },
              ),

              const SizedBox(height: 16),

              // 4. Form Input: Agenda & Discussion Points (Validated)
              const Text(
                'Meeting Agenda & Specific Questions *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'State what specific modules, chapters, or questions your group wants to consult on.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _agendaController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your consultation agenda.';
                  }
                  if (value.trim().length < 10) {
                    return 'Agenda must be at least 10 characters long.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 5. Form Input: Document / Manuscript Link (Optional)
              const Text(
                'Google Drive / GitHub / Manuscript Link (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _documentUrlController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.link, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              // 6. Double-Booking Guarantee Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: Color(0xFF1976D2)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CapSync prevents double-booking. When confirmed, this slot will be locked immediately for other groups.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF0D47A1)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 7. Submit RSVP Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Confirming RSVP...' : 'Submit Consultation Request',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
