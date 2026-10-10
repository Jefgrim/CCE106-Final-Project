// =============================================================================
// FILE: lib/widgets/app_header.dart
// PRODUCTION APP BAR: Displays UM IT College branding, active user info,
// notification bell, and session logout.
// Fully responsive to prevent overflow on mobile and tablet screens.
// Strictly adheres to CapSync brand palette (Navy, Primary Blue, Sky Blue).
// =============================================================================

import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/auth/login_screen.dart';
import '../theme/app_colors.dart';
import 'user_avatar.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final AppState appState;
  final String title;

  const AppHeader({
    super.key,
    required this.appState,
    this.title = 'CapSync',
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);


  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.primaryNavy),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your CapSync session?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await appState.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen(appState: appState)),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final unreadCount = appState.unreadNotificationCount;

    return AppBar(
      toolbarHeight: 64,
      elevation: 1.5,
      backgroundColor: AppColors.primaryNavy,
      foregroundColor: Colors.white,
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CapSync Logo Icon
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/capsync_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school_rounded,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Cap',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                TextSpan(
                  text: 'Sync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.skyBlue,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // User Profile Pill (Interactive: Opens Profile Management & Password Change)
        Tooltip(
          message: 'Manage Profile & Password',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ProfileScreen(appState: appState),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(
                      user: user,
                      radius: 10,
                      fontSize: 8.5,
                    ),
                    const SizedBox(width: 5),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.split(' ').first,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          user.role.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 7.5,
                            color: AppColors.skyBlue,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 2),

        // Notification Bell Icon with compact padding
        IconButton(
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white, size: 21),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => NotificationsScreen(appState: appState),
              ),
            );
          },
        ),

        // Session Logout Button with compact padding
        IconButton(
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
          tooltip: 'Sign Out',
          onPressed: () => _confirmLogout(context),
        ),

        const SizedBox(width: 8),
      ],
    );
  }
}
