import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/biometric_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(biometricProvider.notifier).checkCapabilities();
    });
  }

  Future<void> _toggleFingerprint(bool value) async {
    final auth = ref.read(authProvider);
    final bioNotifier = ref.read(biometricProvider.notifier);

    if (value) {
      // Step 1: Check enrollment
      final enrolled = await BiometricAuthService().isFingerprintEnrolled();
      if (!enrolled) {
        _showSnackBar(
          'Fingerprint is not set up on this device.\nPlease add a fingerprint in your device settings first.',
          AppColors.accentRed,
        );
        return;
      }

      // Step 2: Authenticate to confirm identity before enabling
      final result = await BiometricAuthService().authenticateWithResult(
        localizedReason: 'Scan fingerprint to enable Fingerprint Lock',
      );

      if (result.authenticated && mounted) {
        await bioNotifier.setFingerprintEnabled(
          true,
          token: auth.token,
          user: auth.user,
          role: auth.role,
        );
        _showSnackBar('Fingerprint Lock Enabled Successfully! ✓', AppColors.accentGreen);
      } else if (mounted) {
        _showSnackBar(
          result.errorMessage ?? 'Fingerprint verification failed.',
          AppColors.accentRed,
        );
      }
    } else {
      await bioNotifier.setFingerprintEnabled(false);
      _showSnackBar('Fingerprint Lock Disabled', AppColors.accentAmber);
    }
  }

  Future<void> _toggleFaceLock(bool value) async {
    final auth = ref.read(authProvider);
    final bioNotifier = ref.read(biometricProvider.notifier);

    if (value) {
      // Step 1: Check enrollment
      final enrolled = await BiometricAuthService().isFaceEnrolled();
      if (!enrolled) {
        _showSnackBar(
          'Face Lock is not set up on this device.\nPlease add Face Unlock in your device settings first.',
          AppColors.accentRed,
        );
        return;
      }

      // Step 2: Authenticate to confirm identity before enabling
      final result = await BiometricAuthService().authenticateWithResult(
        localizedReason: 'Scan face to enable Face Lock',
      );

      if (result.authenticated && mounted) {
        await bioNotifier.setFaceLockEnabled(
          true,
          token: auth.token,
          user: auth.user,
          role: auth.role,
        );
        _showSnackBar('Face Lock Enabled Successfully! ✓', AppColors.accentGreen);
      } else if (mounted) {
        _showSnackBar(
          result.errorMessage ?? 'Face verification failed.',
          AppColors.accentRed,
        );
      }
    } else {
      await bioNotifier.setFaceLockEnabled(false);
      _showSnackBar('Face Lock Disabled', AppColors.accentAmber);
    }
  }



  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bioState = ref.watch(biometricProvider);
    final caps = bioState.capabilities;
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final user = auth.user;

    final userName = user?['name']?.toString() ?? 'User';
    final userEmail = user?['email']?.toString() ?? 'user@ams.com';
    final userRole = (auth.role ?? user?['role']?.toString() ?? 'Employee').toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
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
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // User Card Header
              _buildUserHeaderCard(context, userName, userEmail, userRole),

              const SizedBox(height: 24),

              // Section Title: Security & Biometrics
              _buildSectionTitle(context, 'Security & Biometrics', Icons.security_rounded),
              const SizedBox(height: 12),

              // Fingerprint Option Card
              _buildBiometricOptionCard(
                context: context,
                icon: Icons.fingerprint,
                iconColor: AppColors.primary,
                title: 'Fingerprint Lock',
                subtitle: 'Unlock AMS app using your fingerprint scanner',
                isEnabled: caps.isFingerprintEnabled,
                isAvailable: caps.hasFingerprint || caps.isSupported,
                onChanged: (val) => _toggleFingerprint(val),
                badgeText: caps.hasFingerprint
                    ? 'Fingerprint Ready'
                    : (caps.canCheckBiometrics ? 'Available' : 'Not Detected'),
                badgeColor: caps.hasFingerprint ? AppColors.accentGreen : AppColors.accentAmber,
              ),

              const SizedBox(height: 14),

              // Face Lock Option Card
              _buildBiometricOptionCard(
                context: context,
                icon: Icons.face_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Face Lock (Face ID)',
                subtitle: 'Unlock AMS app using facial recognition',
                isEnabled: caps.isFaceLockEnabled,
                isAvailable: caps.hasFace || caps.isSupported,
                onChanged: (val) => _toggleFaceLock(val),
                badgeText: caps.hasFace
                    ? 'Face ID Ready'
                    : (caps.canCheckBiometrics ? 'Available' : 'Not Detected'),
                badgeColor: caps.hasFace ? const Color(0xFF06B6D4) : AppColors.accentAmber,
              ),



              const SizedBox(height: 24),

              // Section Title: Preferences
              _buildSectionTitle(context, 'App Preferences', Icons.tune_rounded),
              const SizedBox(height: 12),

              // Dark Theme Card
              Card(
                color: context.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.borderCol),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.amber : Colors.indigo).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: isDark ? Colors.amber : Colors.indigo,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.txtPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDark ? 'Dark theme active' : 'Light theme active',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.txtSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDark,
                        activeThumbColor: AppColors.primary,
                        onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button Card
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed.withValues(alpha: 0.15),
                  foregroundColor: AppColors.accentRed,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.4)),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Log Out of Account',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard(
    BuildContext context,
    String name,
    String email,
    String role,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.txtPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.txtSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.txtPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool isAvailable,
    required ValueChanged<bool>? onChanged,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Card(
      color: context.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isEnabled
              ? iconColor.withValues(alpha: 0.5)
              : context.borderCol,
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.txtPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.txtSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeThumbColor: iconColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
