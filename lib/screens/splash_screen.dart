// =============================================================================
// FILE: lib/screens/splash_screen.dart
// CAPSYNC MINIMALIST ANIMATED SPLASH SCREEN
// Displays only the official CapSync logo with a smooth breathing/fade animation
// and a sleek branded loading indicator.
// =============================================================================

import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'auth/login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback? onFinish;

  const SplashScreen({super.key, required this.appState, this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Ensure session restoration and database initialization have completed
    try {
      await widget.appState.initializationDone.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
    } catch (_) {}

    if (!mounted) return;

    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }

    final target = widget.appState.isAuthenticated
        ? MainScreen(appState: widget.appState)
        : LoginScreen(appState: widget.appState);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. CapSync Logo with Fade & Scale Animation (Direct logo, no background circle)
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Image.asset(
                    'assets/images/capsync_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_rounded,
                      size: 64,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // 2. Sleek Branded Loading Indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  backgroundColor: AppColors.lightBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
