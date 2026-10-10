// =============================================================================
// FILE: lib/screens/coordinator_screen.dart
// RESEARCH COORDINATOR & DEAN MANAGEMENT PORTAL
// Allows the Coordinator/Dean to:
// 1. Add and manage Faculty Members / Teachers in Firebase.
// 2. Create Capstone Groups and officially pair students with Advisers and Panelists.
// Strictly adheres to official CapSync branding (Navy, Electric Blue, Sky Blue).
// =============================================================================

import 'package:flutter/material.dart';
import '../models/capstone_group.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';

class CoordinatorScreen extends StatefulWidget {
  final AppState appState;

  const CoordinatorScreen({super.key, required this.appState});

  @override
  State<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

class _CoordinatorScreenState extends State<CoordinatorScreen> {
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    widget.appState.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          title: const Text(
            'Research Coordination & Dean Portal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: () async {
                await widget.appState.refreshData();
                if (mounted) setState(() {});
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.skyBlue,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.people_alt_outlined, size: 20),
                text: 'Faculty & Teachers',
              ),
              Tab(
                icon: Icon(Icons.assignment_outlined, size: 20),
                text: 'Groups & Assignments',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFacultyTab(),
            _buildGroupsTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: FACULTY & TEACHERS MANAGEMENT
  // ===========================================================================
  Widget _buildFacultyTab() {
    final facultyList = widget.appState.facultyList;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with official brand gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.school, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Faculty Roster Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${facultyList.length} Faculty Members registered in Firebase. Teachers can only be added by the Coordinator/Dean.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Button: Add Faculty
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddFacultyDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Teacher / Adviser / Panelist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Faculty List
          const Text(
            'Registered Teachers & Panelists:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          if (facultyList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.person_off_outlined, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No Teachers Added Yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click "+ Add Teacher / Adviser / Panelist" above to register faculty in Firebase.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: facultyList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final faculty = facultyList[index];
                return Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              user: faculty,
                              radius: 20,
                              fontSize: 13,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                faculty.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                faculty.facultyIdNumber,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                faculty.email,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (faculty.consultationRoom.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.room_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  faculty.consultationRoom,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (faculty.expertiseTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: faculty.expertiseTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBlue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 10, color: AppColors.primaryNavy, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddFacultyDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final idNumberCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final expertiseCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Add Teacher / Faculty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'This creates a teacher account in Firebase. Only the Coordinator/Dean can add teachers.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Faculty Full Name',
                          prefixIcon: Icon(Icons.badge, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter faculty name' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Institutional Email',
                          prefixIcon: Icon(Icons.email, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporary Password',
                          helperText: 'Minimum 6 characters',
                          prefixIcon: Icon(Icons.lock, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'At least 6 characters' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: idNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Faculty ID Number',
                          prefixIcon: Icon(Icons.credit_card, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter faculty ID' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: roomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Consultation Room / Office (Optional)',
                          prefixIcon: Icon(Icons.meeting_room, size: 20),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: expertiseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Expertise / Tags (Optional, comma separated)',
                          prefixIcon: Icon(Icons.label, size: 20),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);

                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim().toLowerCase();

                        // Validate email is not already taken by student or other user
                        if (widget.appState.allUsers.any((u) => u.email.toLowerCase() == email)) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('An account with this institutional email already exists in CapSync.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          setDialogState(() => isSaving = false);
                          return;
                        }

                        final password = passwordCtrl.text.trim();
                        final idNumber = idNumberCtrl.text.trim();
                        final room = roomCtrl.text.trim();
                        final tags = expertiseCtrl.text
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();

                        final initials = name.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
                        final faculty = FacultyMember(
                          id: 'fac-${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          email: email,
                          avatarInitials: initials.isEmpty ? 'FC' : initials,
                          facultyIdNumber: idNumber,
                          academicRank: '',
                          consultationRoom: room,
                          expertiseTags: tags,
                        );

                        final success = await widget.appState.addFacultyByCoordinator(
                          faculty: faculty,
                          password: password,
                        );

                        if (!mounted) return;
                        nav.pop();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Faculty member $name registered in Firebase!' : 'Failed to register faculty (email may already be in use).'),
                            backgroundColor: success ? AppColors.primaryNavy : AppColors.error,
                          ),
                        );
                        await widget.appState.refreshData();
                        if (mounted) setState(() {});
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save & Register Faculty'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 2: GROUPS & ASSIGNMENTS
  // ===========================================================================
  Widget _buildGroupsTab() {
    final groups = widget.appState.groups;
    final facultyList = widget.appState.facultyList;

    CapstoneGroup? activeGroup;
    if (groups.isNotEmpty) {
      activeGroup = groups.firstWhere(
        (g) => g.id == _selectedGroupId,
        orElse: () => groups.first,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with brand styling
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryNavy,
                  child: Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capstone Group & Defense Pairings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        '${groups.length} Capstone Groups. Group students and assign their adviser and defense panelists.',
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Button: Create Capstone Group
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: facultyList.isEmpty
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add at least one Faculty member first in the Faculty tab.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  : _showCreateGroupDialog,
              icon: const Icon(Icons.group_add),
              label: const Text('Create Capstone Group & Assign Faculty'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (groups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.folder_open_outlined, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No Capstone Groups Created Yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Click "+ Create Capstone Group & Assign Faculty" to bundle students into groups and assign their advisers & panel.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Select Group Dropdown
            const Text(
              'Select Capstone Group to Configure:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: activeGroup?.id,
                  items: groups.map((g) {
                    return DropdownMenuItem(
                      value: g.id,
                      child: Text('${g.groupNumber}: ${g.title}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGroupId = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Group Members Overview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Members for ${activeGroup!.groupNumber}:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeGroup.studentMembers.isEmpty ? 'No student names attached.' : activeGroup.studentMembers.join(' • '),
                    style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 1. Assign Capstone Adviser
            _buildFacultyAssignmentCard(
              title: 'Officially Assigned Capstone Adviser',
              roleColor: AppColors.primaryNavy,
              currentFacultyId: activeGroup.adviserId,
              facultyList: facultyList,
              onChanged: (newId) {
                if (newId != null) {
                  widget.appState.updateGroupAssignment(
                    groupId: activeGroup!.id,
                    adviserId: newId,
                    leadPanelistId: activeGroup.leadPanelistId,
                    panelistIds: activeGroup.panelistIds,
                  );
                  setState(() {});
                }
              },
            ),

            const SizedBox(height: 14),

            // 2. Assign Lead Panelist
            _buildFacultyAssignmentCard(
              title: 'Lead Panelist / Defense Chair',
              roleColor: AppColors.primaryBlue,
              currentFacultyId: activeGroup.leadPanelistId,
              facultyList: facultyList,
              onChanged: (newId) {
                if (newId != null) {
                  widget.appState.updateGroupAssignment(
                    groupId: activeGroup!.id,
                    adviserId: activeGroup.adviserId,
                    leadPanelistId: newId,
                    panelistIds: activeGroup.panelistIds,
                  );
                  setState(() {});
                }
              },
            ),

            const SizedBox(height: 14),

            // 3. Assign Panel Members
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Panel Members (${activeGroup.panelistIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.royalBlue),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            final currentGroup = activeGroup;
                            if (currentGroup == null) return;
                            final updatedPanel = List<String>.from(currentGroup.panelistIds);
                            final available = facultyList.where((f) =>
                              f.id != currentGroup.adviserId &&
                              f.id != currentGroup.leadPanelistId &&
                              !updatedPanel.contains(f.id),
                            ).toList();
                            if (available.isNotEmpty) {
                              updatedPanel.add(available.first.id);
                            } else if (facultyList.isNotEmpty) {
                              updatedPanel.add(facultyList.first.id);
                            }
                            widget.appState.updateGroupAssignment(
                              groupId: currentGroup.id,
                              adviserId: currentGroup.adviserId,
                              leadPanelistId: currentGroup.leadPanelistId,
                              panelistIds: updatedPanel,
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Panel Member', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (activeGroup.panelistIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No panel members assigned yet. Tap "Add Panel Member" above.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...activeGroup.panelistIds.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final currentId = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: facultyList.any((f) => f.id == currentId) ? currentId : null,
                                  decoration: InputDecoration(
                                    labelText: 'Panelist ${idx + 1}',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: facultyList.map((f) {
                                    return DropdownMenuItem(
                                      value: f.id,
                                      child: Text(
                                        f.name,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newVal) {
                                    if (newVal != null) {
                                      final updatedPanel = List<String>.from(activeGroup!.panelistIds);
                                      updatedPanel[idx] = newVal;
                                      widget.appState.updateGroupAssignment(
                                        groupId: activeGroup.id,
                                        adviserId: activeGroup.adviserId,
                                        leadPanelistId: activeGroup.leadPanelistId,
                                        panelistIds: updatedPanel,
                                      );
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                tooltip: 'Remove panel member',
                                onPressed: () {
                                  final updatedPanel = List<String>.from(activeGroup!.panelistIds);
                                  updatedPanel.removeAt(idx);
                                  widget.appState.updateGroupAssignment(
                                    groupId: activeGroup.id,
                                    adviserId: activeGroup.adviserId,
                                    leadPanelistId: activeGroup.leadPanelistId,
                                    panelistIds: updatedPanel,
                                  );
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save Confirmation
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Official assignment updated in Firebase for ${activeGroup!.groupNumber}.'),
                      backgroundColor: AppColors.primaryNavy,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save & Confirm Assignments'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCreateGroupDialog() {
    final formKey = GlobalKey<FormState>();
    final groupNumberCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final studentSearchCtrl = TextEditingController();
    final studentList = widget.appState.studentList
        .where((s) => s.name.trim().isNotEmpty && s.email.trim().isNotEmpty)
        .toList();
    final facultyList = widget.appState.facultyList;
    final selectedStudentIds = <String>{};
    String studentSearchQuery = '';
    bool unassignedOnly = false;
    String? selectedAdviserId;
    String? selectedLeadPanelistId;
    final selectedPanelistIds = <String?>[null];

    CapstoneGroup? findStudentGroup(Student student) {
      if (student.groupId.trim().isNotEmpty) {
        try {
          return widget.appState.groups.firstWhere(
            (g) =>
                g.id.trim().toLowerCase() == student.groupId.trim().toLowerCase() ||
                g.groupNumber.trim().toLowerCase() == student.groupId.trim().toLowerCase(),
          );
        } catch (_) {}
      }
      try {
        return widget.appState.groups.firstWhere(
          (g) => g.studentMembers.any((m) {
            final memberStr = m.trim().toLowerCase();
            final sName = student.name.trim().toLowerCase();
            return memberStr == sName ||
                (student.id.isNotEmpty && memberStr.contains(student.id.toLowerCase())) ||
                (student.studentIdNumber.isNotEmpty && memberStr.contains(student.studentIdNumber.toLowerCase()));
          }),
        );
      } catch (_) {
        return null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableHeight = MediaQuery.of(context).size.height;
          final isSmallScreen = availableHeight < 700;

          final filteredStudents = studentList.where((student) {
            if (student.name.trim().isEmpty || student.email.trim().isEmpty) {
              return false;
            }
            final isAssigned = student.groupId.trim().isNotEmpty || findStudentGroup(student) != null;
            if (unassignedOnly && isAssigned) {
              return false;
            }
            if (studentSearchQuery.isEmpty) return true;
            final q = studentSearchQuery.toLowerCase();
            return student.name.toLowerCase().contains(q) ||
                student.studentIdNumber.toLowerCase().contains(q) ||
                student.email.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.group_add, color: AppColors.primaryNavy),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Create Capstone Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: isSmallScreen ? availableHeight * 0.56 : availableHeight * 0.66,
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: groupNumberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Group Code / Number',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter group code' : null,
                          ),
                          const SizedBox(height: 10),

                          TextFormField(
                            controller: titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Capstone Project Title',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter capstone title' : null,
                          ),
                          const SizedBox(height: 14),

                          // Select Students Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Select Students (${selectedStudentIds.length} selected):',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedStudentIds.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setDialogState(() => selectedStudentIds.clear());
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 24),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Clear All', style: TextStyle(fontSize: 11, color: AppColors.error)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Selected Students Chips Tray
                          if (selectedStudentIds.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: selectedStudentIds.map((id) {
                                final st = studentList.firstWhere(
                                  (s) => s.id == id,
                                  orElse: () => Student(id: id, name: 'Student', email: '', avatarInitials: 'ST', studentIdNumber: '', groupId: '', capstoneTitle: ''),
                                );
                                return Chip(
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 160),
                                    child: Text(
                                      st.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  avatar: CircleAvatar(
                                    backgroundColor: AppColors.primaryNavy,
                                    child: Text(st.avatarInitials, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () {
                                    setDialogState(() => selectedStudentIds.remove(id));
                                  },
                                  backgroundColor: AppColors.lightBlue,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Search & Filter Row
                          TextFormField(
                            controller: studentSearchCtrl,
                            decoration: InputDecoration(
                              labelText: 'Search Students by Name, ID, or Email',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: studentSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        setDialogState(() {
                                          studentSearchCtrl.clear();
                                          studentSearchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) {
                              setDialogState(() => studentSearchQuery = val.trim().toLowerCase());
                            },
                          ),
                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${filteredStudents.length} student${filteredStudents.length == 1 ? '' : 's'} available',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Unassigned Only', style: TextStyle(fontSize: 11)),
                                selected: unassignedOnly,
                                onSelected: (val) => setDialogState(() => unassignedOnly = val),
                                selectedColor: AppColors.lightBlue,
                                checkmarkColor: AppColors.primaryNavy,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Constrained Scrollable Student List
                          if (studentList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No registered students found in Firebase yet. Once students register, they will appear here.',
                                style: TextStyle(fontSize: 11, color: AppColors.warning),
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: filteredStudents.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No students match search or filter.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    )
                                  : Scrollbar(
                                      child: ListView.separated(
                                        itemCount: filteredStudents.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                                        itemBuilder: (ctx, i) {
                                          final student = filteredStudents[i];
                                          final isSelected = selectedStudentIds.contains(student.id);
                                          final assignedGroup = findStudentGroup(student);
                                          final isAssigned = student.groupId.trim().isNotEmpty || assignedGroup != null;
                                          final groupLabel = (assignedGroup != null && assignedGroup.groupNumber.isNotEmpty)
                                              ? assignedGroup.groupNumber
                                              : (student.groupId.trim().isNotEmpty ? student.groupId : '');

                                          return Tooltip(
                                            message: isAssigned
                                                ? '${student.name} is already assigned to Group ${groupLabel.isNotEmpty ? groupLabel : "another group"} and cannot be assigned to another group.'
                                                : 'Tap to select ${student.name}',
                                            child: InkWell(
                                              onTap: isAssigned
                                                  ? () {
                                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '${student.name} is already assigned to Group ${groupLabel.isNotEmpty ? groupLabel : "another group"} and cannot be assigned to another group.',
                                                          ),
                                                          backgroundColor: AppColors.error,
                                                          duration: const Duration(seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                              child: IgnorePointer(
                                                ignoring: isAssigned,
                                                child: CheckboxListTile(
                                                  enabled: !isAssigned,
                                                  dense: true,
                                                  value: isAssigned ? false : isSelected,
                                                  activeColor: AppColors.primaryNavy,
                                                  onChanged: isAssigned
                                                      ? null
                                                      : (checked) {
                                                          setDialogState(() {
                                                            if (checked == true) {
                                                              selectedStudentIds.add(student.id);
                                                            } else {
                                                              selectedStudentIds.remove(student.id);
                                                            }
                                                          });
                                                        },
                                                  title: Text(
                                                    student.name,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isAssigned ? AppColors.textSecondary : AppColors.textPrimary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  subtitle: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'ID: ${student.studentIdNumber} • ${student.email}',
                                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: isAssigned ? Colors.grey.shade200 : const Color(0xFFDCFCE7),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(
                                                            color: isAssigned ? Colors.grey.shade400 : const Color(0xFF86EFAC),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (isAssigned) ...[
                                                              Icon(Icons.lock, size: 9, color: Colors.grey.shade700),
                                                              const SizedBox(width: 3),
                                                            ],
                                                            Text(
                                                              isAssigned
                                                                  ? (groupLabel.isNotEmpty ? 'In Group $groupLabel' : 'In Group')
                                                                  : 'Available',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                                color: isAssigned ? Colors.grey.shade700 : const Color(0xFF166534),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),

                          const SizedBox(height: 14),

                          // Adviser
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedAdviserId,
                            decoration: const InputDecoration(
                              labelText: 'Assigned Adviser',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Select Assigned Adviser', overflow: TextOverflow.ellipsis),
                            validator: (v) => v == null ? 'Please select an adviser' : null,
                            items: facultyList.map((f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                f.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )).toList(),
                            onChanged: (val) => setDialogState(() => selectedAdviserId = val),
                          ),
                          const SizedBox(height: 10),

                          // Lead Panelist
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedLeadPanelistId,
                            decoration: const InputDecoration(
                              labelText: 'Lead Panelist / Chair',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Select Lead Panelist', overflow: TextOverflow.ellipsis),
                            validator: (v) => v == null ? 'Please select a lead panelist' : null,
                            items: facultyList.map((f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                f.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )).toList(),
                            onChanged: (val) => setDialogState(() => selectedLeadPanelistId = val),
                          ),
                          const SizedBox(height: 14),

                          // Panel Members Section (Multiple Panel Members Support)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Panel Members (${selectedPanelistIds.where((id) => id != null && id.isNotEmpty).length}):',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.royalBlue),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedPanelistIds.add(null);
                                  });
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Panel Member', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          if (selectedPanelistIds.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text(
                                'No panel members assigned yet. Tap "+ Add Panel Member" to add faculty reviewers.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            )
                          else
                            ...selectedPanelistIds.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final currentId = entry.value;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: currentId,
                                        decoration: InputDecoration(
                                          labelText: 'Panel Member ${idx + 1}',
                                          border: const OutlineInputBorder(),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        hint: Text('Select Panel Member ${idx + 1}', overflow: TextOverflow.ellipsis),
                                        items: facultyList.map((f) {
                                          return DropdownMenuItem(
                                            value: f.id,
                                            child: Text(
                                              f.name,
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            selectedPanelistIds[idx] = val;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22),
                                      tooltip: 'Remove panel member',
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedPanelistIds.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedStudentIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one student for this group.')),
                    );
                    return;
                  }

                  // Strict validation: Verify no selected student is already in a group
                  final alreadyAssigned = studentList.where((s) {
                    if (!selectedStudentIds.contains(s.id)) return false;
                    return s.groupId.trim().isNotEmpty || findStudentGroup(s) != null;
                  }).toList();

                  if (alreadyAssigned.isNotEmpty) {
                    final names = alreadyAssigned.map((s) => s.name).join(', ');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cannot assign: $names is already assigned to another group.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  if (selectedAdviserId == null || selectedLeadPanelistId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an Adviser and Lead Panelist.')),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);

                  final newGroupId = 'grp-${DateTime.now().millisecondsSinceEpoch}';
                  final studentMembers = studentList
                      .where((s) => selectedStudentIds.contains(s.id))
                      .map((s) => s.name)
                      .toList();

                  final validPanelistIds = selectedPanelistIds
                      .where((id) => id != null && id.trim().isNotEmpty)
                      .cast<String>()
                      .toSet()
                      .toList();

                  final newGroup = CapstoneGroup(
                    id: newGroupId,
                    groupNumber: groupNumberCtrl.text.trim(),
                    title: titleCtrl.text.trim(),
                    studentMembers: studentMembers,
                    adviserId: selectedAdviserId!,
                    leadPanelistId: selectedLeadPanelistId!,
                    panelistIds: validPanelistIds,
                  );

                  await widget.appState.createCapstoneGroup(
                    group: newGroup,
                    studentMemberUserIds: selectedStudentIds.toList(),
                  );

                  if (!mounted) return;
                  nav.pop();
                  setState(() => _selectedGroupId = newGroupId);

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Capstone Group "${newGroup.groupNumber}" created and faculty assigned!'),
                      backgroundColor: AppColors.primaryNavy,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create & Assign Group'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFacultyAssignmentCard({
    required String title,
    required Color roleColor,
    required String currentFacultyId,
    required List<FacultyMember> facultyList,
    required ValueChanged<String?> onChanged,
  }) {
    final validCurrentId = facultyList.any((f) => f.id == currentFacultyId) ? currentFacultyId : null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: roleColor),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: validCurrentId,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: facultyList.map((f) {
                return DropdownMenuItem(
                  value: f.id,
                  child: Text(
                    f.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
