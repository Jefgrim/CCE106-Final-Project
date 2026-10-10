// =============================================================================
// FILE: lib/screens/faculty_schedule_screen.dart
// CORE REQUIREMENT: Faculty Availability Management
// Allows professors/advisers/panelists to set their consultation availability,
// open time slots, specify mode (Room vs Meet), and manage their schedule.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/time_slot.dart';
import '../models/user.dart';
import '../services/schedule_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';

class FacultyScheduleScreen extends StatefulWidget {
  final AppState appState;

  const FacultyScheduleScreen({super.key, required this.appState});

  @override
  State<FacultyScheduleScreen> createState() => _FacultyScheduleScreenState();
}

class _FacultyScheduleScreenState extends State<FacultyScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  void _showAddSlotDialog() {
    if (widget.appState.currentUser is! FacultyMember) return;
    final faculty = widget.appState.currentUser as FacultyMember;
    final scheduleService = widget.appState.scheduleService;

    DateTime slotDate = _selectedDate;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (slotDate.isBefore(today)) {
      slotDate = today;
    }

    String? startTime;
    String? endTime;
    ConsultationMode mode = ConsultationMode.inPerson;
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableStartTimes = scheduleService.getAvailableStartTimes(
            allSlots: widget.appState.slots,
            facultyId: faculty.id,
            date: slotDate,
          );

          if (availableStartTimes.isNotEmpty) {
            if (startTime == null || !availableStartTimes.contains(startTime)) {
              startTime = availableStartTimes.first;
            }
          } else {
            startTime = null;
          }

          final availableEndTimes = startTime != null
              ? scheduleService.getAvailableEndTimes(
                  allSlots: widget.appState.slots,
                  facultyId: faculty.id,
                  date: slotDate,
                  startTime: startTime!,
                )
              : <String>[];

          if (availableEndTimes.isNotEmpty) {
            if (endTime == null || !availableEndTimes.contains(endTime)) {
              endTime = availableEndTimes.first;
            }
          } else {
            endTime = null;
          }

          final canPublish = startTime != null && endTime != null;
          final durationMins = (startTime != null && endTime != null)
              ? ScheduleService.timeToMinutes(endTime!) - ScheduleService.timeToMinutes(startTime!)
              : 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Row(
              children: [
                Icon(Icons.more_time_rounded, color: AppColors.primaryNavy),
                SizedBox(width: 8),
                Text('Open Consultation Slot', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: slotDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              slotDate = picked;
                              startTime = null;
                              endTime = null;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('EEE, MMM d, yyyy').format(slotDate)),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // If no start times are available
                      if (availableStartTimes.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.primaryNavy, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  slotDate.year == DateTime.now().year &&
                                          slotDate.month == DateTime.now().month &&
                                          slotDate.day == DateTime.now().day
                                      ? 'All consultation hours for today have passed or are already opened. Please select tomorrow or a future date.'
                                      : 'All consultation hours on this date are already opened. Please select another date.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.primaryNavy, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        // Start & End Time
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Time:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('start-$slotDate-$startTime'),
                                    initialValue: startTime,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    hint: const Text('Start Time', style: TextStyle(fontSize: 11)),
                                    items: availableStartTimes.map((t) {
                                      return DropdownMenuItem(
                                        value: t,
                                        child: Text(
                                          t,
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          startTime = val;
                                          final newEnds = scheduleService.getAvailableEndTimes(
                                            allSlots: widget.appState.slots,
                                            facultyId: faculty.id,
                                            date: slotDate,
                                            startTime: val,
                                          );
                                          endTime = newEnds.isNotEmpty ? newEnds.first : null;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Time:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('end-$slotDate-$startTime-$endTime'),
                                    initialValue: endTime,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    hint: const Text('End Time', style: TextStyle(fontSize: 11)),
                                    items: availableEndTimes.map((t) {
                                      return DropdownMenuItem(
                                        value: t,
                                        child: Text(
                                          t,
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => endTime = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Slot Duration: $durationMins mins (Minimum 30 mins per slot)',
                          style: const TextStyle(fontSize: 10, color: AppColors.royalBlue, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Mode
                      const Text('Consultation Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('In-Person'),
                              selected: mode == ConsultationMode.inPerson,
                              selectedColor: AppColors.lightBlue,
                              onSelected: (sel) {
                                if (sel) {
                                  setDialogState(() {
                                    mode = ConsultationMode.inPerson;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Online (Meet)'),
                              selected: mode == ConsultationMode.online,
                              selectedColor: AppColors.lightBlue,
                              onSelected: (sel) {
                                if (sel) {
                                  setDialogState(() {
                                    mode = ConsultationMode.online;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Location / Link
                      Text(
                        mode == ConsultationMode.inPerson ? 'Room Location:' : 'Meeting Link:',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: mode == ConsultationMode.inPerson ? 'Room Location' : 'Meeting Link',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canPublish
                    ? () {
                        final added = widget.appState.addFacultySlot(
                          date: slotDate,
                          startTime: startTime!,
                          endTime: endTime!,
                          mode: mode,
                          locationOrLink: locationController.text.trim(),
                        );

                        Navigator.of(ctx).pop();

                        if (added) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Consultation slot ($startTime - $endTime) published for ${DateFormat('MMM d').format(slotDate)}.'),
                              backgroundColor: AppColors.primaryNavy,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cannot open slot: Time has already passed, overlaps an existing slot, or is under 30 minutes.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Publish Slot'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appState.currentUser is! FacultyMember) {
      return const Center(child: Text('Only faculty members can access this screen.'));
    }

    final faculty = widget.appState.currentUser as FacultyMember;
    final now = DateTime.now();
    final facultySlots = widget.appState.slots
        .where((s) => s.facultyId == faculty.id && !s.isPast(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      body: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.lightBlue.withValues(alpha: 0.5),
            child: Row(
              children: [
                UserAvatar(
                  user: faculty,
                  radius: 20,
                  fontSize: 13,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${faculty.name} Schedule',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Manage your open consultation blocks for student capstone groups.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddSlotDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Slot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Slots List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryNavy,
              onRefresh: () async {
                await widget.appState.refreshData();
              },
              child: facultySlots.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 50, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Consultation Slots Published',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Click "Add Slot" above to open consultation times, or swipe down to refresh.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: facultySlots.length,
                    itemBuilder: (context, index) {
                      final slot = facultySlots[index];
                      final isBooked = slot.isBooked;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isBooked ? Colors.amber.shade400 : Colors.grey.shade300,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isBooked ? Colors.amber.shade100 : Colors.green.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBooked ? Icons.lock : Icons.event_available,
                              size: 18,
                              color: isBooked ? Colors.amber.shade900 : Colors.green.shade800,
                            ),
                          ),
                          title: Text(
                            '${slot.formattedDate} • ${slot.timeRange}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${slot.mode.label} • ${slot.locationOrLink}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (isBooked)
                                Text(
                                  'Reserved by: Group ${slot.bookedByGroupId?.replaceAll('grp-', '')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                            ],
                          ),
                          trailing: isBooked
                              ? Chip(
                                  label: const Text('Booked', style: TextStyle(fontSize: 10, color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                                  backgroundColor: AppColors.lightBlue,
                                  visualDensity: VisualDensity.compact,
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'Delete Slot',
                                  onPressed: () {
                                    widget.appState.removeFacultySlot(slot.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Slot removed.')),
                                    );
                                  },
                                ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
