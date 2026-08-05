import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/landing_screen.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();
  runApp(
    const ProviderScope(
      child: AMSApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // App-Level Biometric Lock Gate (Redirect to Splash)
    GoRoute(
      path: '/biometric-lock',
      builder: (context, state) => const SplashScreen(),
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
  ],
);

class AMSApp extends ConsumerWidget {
  const AMSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
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

