import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/biometric_lock_screen.dart';
import 'screens/employee/employee_dashboard.dart';
import 'screens/employee/salary_screen.dart';
import 'screens/employee/tasks_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/admin/salary_screen.dart';
import 'screens/admin/projects_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/shared/notifications_screen.dart';
import 'screens/shared/holidays_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_room_screen.dart';
import 'screens/employee/qr_scanner_screen.dart';
import 'screens/employee/face_lock_registration_screen.dart';
import 'screens/admin/admin_attendance_qr_screen.dart';
import 'screens/admin/admin_face_attendance_screen.dart';

import 'services/realtime_notification_service.dart';
import 'services/socket_service.dart';

const FirebaseOptions _fallbackFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAamsMobileDefaultApiKey123456789',
  appId: '1:123456789012:android:abcdef1234567890',
  messagingSenderId: '123456789012',
  projectId: 'attendence-management-system1',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();

  runApp(
    const ProviderScope(
      child: AMSApp(),
    ),
  );

  // Initialize Firebase, Native Push Notifications and Realtime Sockets in background
  Future.microtask(() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _fallbackFirebaseOptions);
      }
      if (Firebase.apps.isNotEmpty) {
        try {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        } catch (_) {}
        await RealtimeNotificationService.initFirebaseMessaging();
      }
    } catch (e) {
      debugPrint('Firebase async initialization warning: $e');
    }

    try {
      await RealtimeNotificationService.initNativeNotifications();
    } catch (e) {
      debugPrint('Native notifications async warning: $e');
    }

    try {
      await SocketService().initSocket();
    } catch (e) {
      debugPrint('Socket async initialization warning: $e');
    }
  });
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // App-Level Biometric Lock Gate
    GoRoute(
      path: '/biometric-lock',
      builder: (context, state) => const BiometricLockScreen(),
    ),

    // Settings
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),


    // Landing / Welcome
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const LandingScreen(),
    ),

    // Auth
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Employee Routes
    GoRoute(
      path: '/employee/dashboard',
      builder: (context, state) => const EmployeeDashboard(),
    ),
    GoRoute(
      path: '/employee/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    // Admin Routes
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboard(),
    ),

    // Additional screens
    GoRoute(
      path: '/employee/tasks',
      builder: (context, state) => const EmployeeTasksScreen(),
    ),
    GoRoute(
      path: '/employee/salary',
      builder: (context, state) => const EmployeeSalaryScreen(),
    ),
    GoRoute(
      path: '/employee/projects',
      builder: (context, state) => const AdminProjectsScreen(),
    ),
    GoRoute(
      path: '/employee/shifts',
      builder: (context, state) => const _PlaceholderScreen(title: 'My Shifts'),
    ),
    GoRoute(
      path: '/employee/profile',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/employee/scan-qr',
      builder: (context, state) => const QRScannerScreen(),
    ),
    GoRoute(
      path: '/employee/face-lock',
      builder: (context, state) => const FaceLockRegistrationScreen(),
    ),
    GoRoute(
      path: '/scan-qr',
      builder: (context, state) => const QRScannerScreen(),
    ),

    GoRoute(
      path: '/admin/attendance-qr',
      builder: (context, state) => const AdminAttendanceQRScreen(),
    ),
    GoRoute(
      path: '/admin/face-attendance',
      builder: (context, state) => const AdminFaceAttendanceScreen(),
    ),
    GoRoute(
      path: '/admin/analytics',
      builder: (context, state) => const AdminAnalyticsScreen(),
    ),
    GoRoute(
      path: '/admin/projects',
      builder: (context, state) => const AdminProjectsScreen(),
    ),
    GoRoute(
      path: '/admin/salary',
      builder: (context, state) => const AdminSalaryScreen(),
    ),
    GoRoute(
      path: '/admin/holidays',
      builder: (context, state) => const HolidaysScreen(),
    ),
    GoRoute(
      path: '/admin/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    // Chat & Messaging Routes
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/chat/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        return ChatRoomScreen(
          targetUserId: userId,
          initialUserData: extra,
        );
      },
    ),
  ],
);

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AMSApp extends ConsumerWidget {
  const AMSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'AMS - Attendance Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

// Placeholder screen for routes to be expanded
class _PlaceholderScreen extends ConsumerWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final auth = ref.read(authProvider);
              if (auth.isAdmin) {
                context.go('/admin/dashboard');
              } else {
                context.go('/employee/dashboard');
              }
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 60,
                color: context.txtMuted,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: context.txtPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: TextStyle(color: context.txtSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

