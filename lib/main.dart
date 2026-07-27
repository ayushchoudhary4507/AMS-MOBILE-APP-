import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/employee/employee_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';

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

    // Admin Routes
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboard(),
    ),

    // Additional screens (can be expanded)
    GoRoute(
      path: '/employee/tasks',
      builder: (context, state) => const _PlaceholderScreen(title: 'My Tasks'),
    ),
    GoRoute(
      path: '/employee/salary',
      builder: (context, state) => const _PlaceholderScreen(title: 'My Salary'),
    ),
    GoRoute(
      path: '/employee/shifts',
      builder: (context, state) => const _PlaceholderScreen(title: 'My Shifts'),
    ),
    GoRoute(
      path: '/employee/profile',
      builder: (context, state) => const _PlaceholderScreen(title: 'Profile'),
    ),
    GoRoute(
      path: '/admin/analytics',
      builder: (context, state) => const _PlaceholderScreen(title: 'Analytics'),
    ),
    GoRoute(
      path: '/admin/projects',
      builder: (context, state) => const _PlaceholderScreen(title: 'Projects'),
    ),
    GoRoute(
      path: '/admin/salary',
      builder: (context, state) => const _PlaceholderScreen(title: 'Salary Management'),
    ),
    GoRoute(
      path: '/admin/holidays',
      builder: (context, state) => const _PlaceholderScreen(title: 'Holidays'),
    ),
    GoRoute(
      path: '/admin/notifications',
      builder: (context, state) => const _PlaceholderScreen(title: 'Notifications'),
    ),
  ],
);

class AMSApp extends StatelessWidget {
  const AMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AMS - Attendance Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

// Placeholder screen for routes to be expanded
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 60,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming Soon',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
