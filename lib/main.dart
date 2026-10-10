// =============================================================================
// FILE: lib/main.dart
// PROJECT: CapSync - University of Mindanao IT College Capstone Consultation System
// Handles Application Themes, Database State, and Authentication Routing.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/database/firebase_config.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'services/push_notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Note: Environment file (.env) could not be loaded: $e");
  }

  // Initialize Firebase using environment-backed options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Connected to Firebase project: ${FirebaseConfig.projectId}");
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint("Note: Firebase.initializeApp deferred or running offline: $e");
  }

  runApp(const CapSyncApp());
}

class CapSyncApp extends StatefulWidget {
  const CapSyncApp({super.key});

  @override
  State<CapSyncApp> createState() => _CapSyncAppState();
}

class _CapSyncAppState extends State<CapSyncApp> {
  final AppState _appState = AppState();
  bool _splashFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.requestPermission();
    });
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, child) {
        return MaterialApp(
          title: 'CapSync - University of Mindanao',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryNavy,
              primary: AppColors.primaryNavy,
              secondary: AppColors.primaryBlue,
              surface: AppColors.surface,
              onPrimary: Colors.white,
            ),
            scaffoldBackgroundColor: AppColors.background,
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              color: Colors.white,
              shadowColor: AppColors.primaryNavy.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryBlue, width: 2.0),
              ),
            ),
          ),
          home: !_splashFinished
              ? SplashScreen(
                  appState: _appState,
                  onFinish: () {
                    if (mounted) {
                      setState(() => _splashFinished = true);
                    }
                  },
                )
              : (_appState.isAuthenticated
                  ? MainScreen(appState: _appState)
                  : LoginScreen(appState: _appState)),
        );
      },
    );
  }
}
