// =============================================================================
// FILE: lib/screens/main_screen.dart
// PRODUCTION ROOT SCREEN: Role-based navigation for Student, Faculty, and Coordinator.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import 'availability_dashboard_screen.dart';
import 'panel_assignment_screen.dart';
import 'my_consultations_screen.dart';
import 'faculty_schedule_screen.dart';
import 'faculty_requests_screen.dart';
import 'coordinator_screen.dart';
import '../services/push_notification_service.dart';
import '../theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  final AppState appState;

  const MainScreen({super.key, required this.appState});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.requestPermission();
    });
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState.currentUser?.role != widget.appState.currentUser?.role) {
      _currentTabIndex = 0;
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final user = appState.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = user.role;
    List<Widget> screens;
    List<BottomNavigationBarItem> navItems;

    switch (role) {
      case UserRole.student:
        screens = [
          AvailabilityDashboardScreen(
            appState: appState,
            onNavigateTab: _onTabSelected,
          ),
          PanelAssignmentScreen(
            appState: appState,
            onNavigateTab: _onTabSelected,
          ),
          MyConsultationsScreen(appState: appState),
        ];
        navItems = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Availability',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: 'Panel & Adviser',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border_rounded),
            activeIcon: Icon(Icons.bookmark_rounded),
            label: 'My Bookings',
          ),
        ];
        break;

      case UserRole.faculty:
        screens = [
          AvailabilityDashboardScreen(
            appState: appState,
            onNavigateTab: _onTabSelected,
          ),
          FacultyScheduleScreen(appState: appState),
          FacultyRequestsScreen(appState: appState),
        ];
        navItems = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_time_rounded),
            activeIcon: Icon(Icons.more_time),
            label: 'My Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Student RSVPs',
          ),
        ];
        break;

      case UserRole.coordinator:
        screens = [
          AvailabilityDashboardScreen(
            appState: appState,
            onNavigateTab: _onTabSelected,
          ),
          CoordinatorScreen(appState: appState),
        ];
        navItems = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Campus View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Assign Panels',
          ),
        ];
        break;
    }

    if (_currentTabIndex >= screens.length) {
      _currentTabIndex = 0;
    }

    return Scaffold(
      appBar: AppHeader(appState: appState),
      body: screens[_currentTabIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey.shade600,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: navItems,
        ),
      ),
    );
  }
}
