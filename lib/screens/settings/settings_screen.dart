import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/face_recognition_service.dart';
import '../../widgets/auth/face_camera_auth_dialog.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/photo_viewer_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Password controllers
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;
  bool _passwordLoading = false;
  String _passwordMsg = '';
  bool _passwordSuccess = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(biometricProvider.notifier).checkCapabilities();
    });
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Fingerprint ─────────────────────────────────────────────────────────────
  Future<void> _toggleFingerprint(bool value) async {
    final auth = ref.read(authProvider);
    final bioNotifier = ref.read(biometricProvider.notifier);
    if (value) {
      final enrolled = await BiometricAuthService().isFingerprintEnrolled();
      if (!enrolled) {
        _snack('Fingerprint is not set up on this device.\nPlease add a fingerprint in your device settings first.', AppColors.accentRed);
        return;
      }
      final result = await BiometricAuthService().authenticateWithResult(
        localizedReason: 'Scan fingerprint to enable Fingerprint Lock',
        biometricOnly: true,
      );
      if (result.authenticated && mounted) {
        await bioNotifier.setFingerprintEnabled(true, token: auth.token, user: auth.user, role: auth.role);
        _snack('Fingerprint Lock Enabled Successfully! ✓', AppColors.accentGreen);
      } else if (mounted) {
        _snack(result.errorMessage ?? 'Fingerprint verification failed.', AppColors.accentRed);
      }
    } else {
      await bioNotifier.setFingerprintEnabled(false);
      _snack('Fingerprint Lock Disabled', AppColors.accentAmber);
    }
  }

  // ── Face Lock ───────────────────────────────────────────────────────────────
  Future<void> _toggleFaceLock(bool value) async {
    final auth = ref.read(authProvider);
    final bioNotifier = ref.read(biometricProvider.notifier);
    if (value) {
      final success = await FaceCameraAuthDialog.show(
        context,
        title: 'Set Up Face Lock',
        subtitle: 'Position your face inside the circle to register Face Lock',
        isEnrollment: true,
      );
      if (success && mounted) {
        await bioNotifier.setFaceLockEnabled(true, token: auth.token, user: auth.user, role: auth.role);
        await bioNotifier.checkCapabilities();
        _snack('Face Lock Registered & Enabled Successfully! ✓', AppColors.accentGreen);
      } else if (mounted) {
        await bioNotifier.checkCapabilities();
        _snack('Face Lock setup was cancelled or failed.', AppColors.accentAmber);
      }
    } else {
      await bioNotifier.setFaceLockEnabled(false);
      final userId = auth.user?['id'] ?? auth.user?['_id'] ?? auth.user?['email'];
      await FaceRecognitionService().clearEnrolledFaceTemplate(userId: userId?.toString());
      await bioNotifier.checkCapabilities();
      _snack('Face Lock Disabled', AppColors.accentAmber);
    }
  }

  // ── Change Password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final current = _currentPasswordCtrl.text.trim();
    final newPass = _newPasswordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();
    if (current.isEmpty || newPass.isEmpty) {
      setState(() { _passwordMsg = 'Please enter your current and new password.'; _passwordSuccess = false; });
      return;
    }
    if (newPass.length < 6) {
      setState(() { _passwordMsg = 'New password must be at least 6 characters long.'; _passwordSuccess = false; });
      return;
    }
    if (newPass != confirm) {
      setState(() { _passwordMsg = 'New password and confirm password do not match.'; _passwordSuccess = false; });
      return;
    }
    setState(() { _passwordLoading = true; _passwordMsg = ''; });
    try {
      final response = await ApiService.put(ApiConstants.changePassword, data: {
        'currentPassword': current, 'newPassword': newPass, 'confirmPassword': confirm,
      });
      final map = ApiService.toMap(response.data);
      if (map['success'] == true || (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300)) {
        setState(() { _passwordMsg = '✓ Password updated successfully in MongoDB Atlas!'; _passwordSuccess = true; });
        _currentPasswordCtrl.clear(); _newPasswordCtrl.clear(); _confirmPasswordCtrl.clear();
        _snack('Password updated successfully! ✓', AppColors.accentGreen);
      } else {
        setState(() { _passwordMsg = map['message']?.toString() ?? 'Failed to update password'; _passwordSuccess = false; });
      }
    } catch (e) {
      setState(() { _passwordMsg = 'Failed to update password. Please check your current password.'; _passwordSuccess = false; });
    } finally {
      setState(() { _passwordLoading = false; });
    }
  }

  Future<void> _syncThemeToBackend(ThemeMode mode) async {
    try {
      final themeStr = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'auto';
      await ApiService.put('${ApiConstants.settings}/appearance', data: {'theme': themeStr});
    } catch (_) {}
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: context.txtPrimary),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.txtPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(auth.isAdmin ? '/admin/dashboard' : '/employee/dashboard');
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              // ── 1. USER PROFILE CARD ───────────────────────────────────────
              _buildUserHeaderCard(context, user, userName, userEmail, userRole),

              const SizedBox(height: 24),

              // ── 2. PASSWORD & SECURITY (WEBSITE SETTING) ───────────────────
              _buildSectionTitle(context, 'Password & Security', Icons.lock_outline_rounded),
              const SizedBox(height: 12),
              _buildPasswordCard(context, isDark),

              const SizedBox(height: 24),

              // ── 3. SECURITY & BIOMETRICS ───────────────────────────────────
              _buildSectionTitle(context, 'Security & Biometrics', Icons.security_rounded),
              const SizedBox(height: 12),

              // Fingerprint Card
              _buildBiometricOptionCard(
                context: context,
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Fingerprint Lock',
                subtitle: 'Unlock AMS app using your fingerprint scanner',
                isEnabled: caps.isFingerprintEnabled,
                isAvailable: caps.hasFingerprint || caps.isSupported,
                onChanged: (val) => _toggleFingerprint(val),
                badgeText: caps.isFingerprintEnabled ? 'Active' : (caps.hasFingerprint ? 'Available' : (caps.canCheckBiometrics ? 'Supported' : 'Not Detected')),
                badgeColor: caps.isFingerprintEnabled ? AppColors.accentGreen : const Color(0xFFF59E0B),
              ),

              const SizedBox(height: 12),

              // Face Lock Card
              _buildBiometricOptionCard(
                context: context,
                icon: Icons.face_retouching_natural_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Face Lock (Camera)',
                subtitle: 'Unlock AMS app using front camera facial recognition',
                isEnabled: caps.isFaceLockEnabled,
                isAvailable: true,
                onChanged: (val) => _toggleFaceLock(val),
                badgeText: caps.isFaceLockEnabled ? 'Active' : 'Camera Ready',
                badgeColor: caps.isFaceLockEnabled ? AppColors.accentGreen : const Color(0xFF06B6D4),
              ),

              const SizedBox(height: 24),

              // ── 4. APP PREFERENCES ─────────────────────────────────────────
              _buildSectionTitle(context, 'App Preferences', Icons.tune_rounded),
              const SizedBox(height: 12),

              // Dark Theme Card
              Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF272A3E) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFF6366F1)).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                        size: 24,
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
                              fontWeight: FontWeight.w700,
                              color: context.txtPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
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
                      activeTrackColor: const Color(0xFF6366F1),
                      activeThumbColor: Colors.white,
                      onChanged: (_) {
                        ref.read(themeProvider.notifier).toggleTheme();
                        _syncThemeToBackend(isDark ? ThemeMode.light : ThemeMode.dark);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 6. LOGOUT BUTTON ───────────────────────────────────────────
              InkWell(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/welcome');
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentRed.withValues(alpha: isDark ? 0.45 : 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: AppColors.accentRed),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out of Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── 7. FOOTER ──────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'AttendancePro • v1.0.0 Pro Edition',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.txtMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Synchronized with MongoDB Atlas & Vercel Web Portal',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.txtMuted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── PASSWORD CARD (WEBSITE SETTING) ─────────────────────────────────────────
  Widget _buildPasswordCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF272A3E) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Account Password',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.txtPrimary),
                    ),
                    Text(
                      'Update your password securely in Atlas DB',
                      style: TextStyle(fontSize: 11, color: context.txtSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Message Alert
          if (_passwordMsg.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_passwordSuccess ? AppColors.accentGreen : AppColors.accentRed).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (_passwordSuccess ? AppColors.accentGreen : AppColors.accentRed).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(_passwordSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: _passwordSuccess ? AppColors.accentGreen : AppColors.accentRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _passwordMsg,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _passwordSuccess ? AppColors.accentGreen : AppColors.accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Current Password Field
          _buildPasswordField(
            context: context,
            controller: _currentPasswordCtrl,
            label: 'Current Password',
            isVisible: _showCurrentPass,
            onToggle: () => setState(() => _showCurrentPass = !_showCurrentPass),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // New Password Field
          _buildPasswordField(
            context: context,
            controller: _newPasswordCtrl,
            label: 'New Password (min. 6 characters)',
            isVisible: _showNewPass,
            onToggle: () => setState(() => _showNewPass = !_showNewPass),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Confirm New Password Field
          _buildPasswordField(
            context: context,
            controller: _confirmPasswordCtrl,
            label: 'Confirm New Password',
            isVisible: _showConfirmPass,
            onToggle: () => setState(() => _showConfirmPass = !_showConfirmPass),
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Update Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _passwordLoading ? null : _changePassword,
              icon: _passwordLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_reset_rounded, size: 18),
              label: Text(
                _passwordLoading ? 'Updating Password...' : '🔐  Update Password',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Security Guidelines Box (matches website UI)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🛡️', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'Security Guidelines',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...[
                  'Minimum 6 Characters for a strong password',
                  'Combine uppercase, lowercase, numbers & symbols',
                  '256-Bit Protection encrypted in Atlas database',
                  'Never share your credentials with anyone',
                ].map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF6366F1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tip,
                              style: TextStyle(fontSize: 11, color: context.txtSecondary),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      style: TextStyle(color: context.txtPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.txtSecondary, fontSize: 12),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: context.txtSecondary),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2A2F47) : const Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2A2F47) : const Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── SECTION TITLE ──────────────────────────────────────────────────────────
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

  // ── USER HEADER CARD ───────────────────────────────────────────────────────
  Widget _buildAvatarWidget(dynamic avatarOrUser, String name, double radius) {
    return AppAvatar(avatarOrUser: avatarOrUser, fallbackText: name, radius: radius);
  }

  Widget _buildUserHeaderCard(
    BuildContext context,
    Map<String, dynamic>? user,
    String name,
    String email,
    String role,
  ) {
    final isDark = context.isDark;
    final phone = user?['phone']?.toString() ?? user?['phoneNumber']?.toString();
    final department = user?['department']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF272A3E) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => showPhotoPreview(
                      context,
                      avatarOrUser: user,
                      title: name,
                      subtitle: role,
                    ),
                    child: _buildAvatarWidget(user, name, 30),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showEditProfileModal(context, user),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.cardBg, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    Text(email, style: TextStyle(fontSize: 13, color: context.txtSecondary)),
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('📞 $phone', style: TextStyle(fontSize: 12, color: context.txtSecondary)),
                    ],
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('🏢 $department', style: TextStyle(fontSize: 12, color: context.txtSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showEditProfileModal(context, user),
              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Edit Profile, Department & Photo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EDIT PROFILE MODAL ─────────────────────────────────────────────────────
  void _showEditProfileModal(BuildContext context, Map<String, dynamic>? user) {
    final currentName = user?['name']?.toString() ?? '';
    final currentPhone = user?['phone']?.toString() ?? user?['phoneNumber']?.toString() ?? '';
    final currentEmail = user?['email']?.toString() ?? '';
    final currentRole = (user?['role']?.toString() ?? 'Employee').toUpperCase();
    final currentDepartment = user?['department']?.toString() ?? '';
    String? currentAvatar = extractAvatarUrl(user);

    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    final departmentController = TextEditingController(text: currentDepartment);
    String? selectedBase64Image = currentAvatar;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final XFile? pickedFile = await picker.pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 70);
                if (pickedFile != null) {
                  setModalState(() { selectedBase64Image = pickedFile.path; });
                }
              } catch (e) {
                _snack('Could not pick image: $e', AppColors.accentRed);
              }
            }

            Future<void> saveProfile() async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();
              if (newName.isEmpty) {
                _snack('Name cannot be empty', AppColors.accentRed);
                return;
              }
              setModalState(() => isSaving = true);
              final success = await ref.read(authProvider.notifier).updateUserProfile(
                name: newName,
                phone: newPhone.isNotEmpty ? newPhone : null,
                profilePicture: selectedBase64Image,
              );
              if (modalCtx.mounted) Navigator.of(modalCtx).pop();
              _snack(success ? 'Profile & Photo updated successfully! ✓' : 'Failed to update profile.', success ? AppColors.accentGreen : AppColors.accentRed);
            }

            return Container(
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: modalCtx.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: modalCtx.borderCol),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: modalCtx.txtSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: modalCtx.txtPrimary)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(modalCtx).pop()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Avatar Edit
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => showPhotoPreview(modalCtx, avatarOrUser: selectedBase64Image ?? user, title: nameController.text, subtitle: 'Profile Photo Preview'),
                            child: _buildAvatarWidget(selectedBase64Image ?? user, nameController.text, 45),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => showModalBottomSheet(
                                context: modalCtx,
                                builder: (pickerCtx) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                                        title: const Text('Choose from Gallery'),
                                        onTap: () { Navigator.pop(pickerCtx); pickImage(ImageSource.gallery); },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF06B6D4)),
                                        title: const Text('Take a Photo'),
                                        onTap: () { Navigator.pop(pickerCtx); pickImage(ImageSource.camera); },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: modalCtx.cardBg, width: 2)),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: modalCtx.txtPrimary),
                      decoration: InputDecoration(labelText: 'Full Name *', prefixIcon: const Icon(Icons.person_outline_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 12),

                    // Phone
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: modalCtx.txtPrimary),
                      decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 12),

                    // Department (Website Setting)
                    TextField(
                      controller: departmentController,
                      style: TextStyle(color: modalCtx.txtPrimary),
                      decoration: InputDecoration(labelText: 'Department', prefixIcon: const Icon(Icons.business_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 12),

                    // Email (Read-only)
                    TextField(
                      controller: TextEditingController(text: currentEmail),
                      readOnly: true,
                      enabled: false,
                      style: TextStyle(color: modalCtx.txtSecondary),
                      decoration: InputDecoration(labelText: 'Email Address (Read-only)', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 12),

                    // Role (Read-only)
                    TextField(
                      controller: TextEditingController(text: currentRole),
                      readOnly: true,
                      enabled: false,
                      style: TextStyle(color: modalCtx.txtSecondary),
                      decoration: InputDecoration(labelText: 'Role (Read-only)', prefixIcon: const Icon(Icons.badge_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving ? null : saveProfile,
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Profile Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── BIOMETRIC OPTION CARD ──────────────────────────────────────────────────
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
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnabled ? iconColor.withValues(alpha: 0.6) : (isDark ? const Color(0xFF272A3E) : const Color(0xFFE2E8F0)),
          width: isEnabled ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled ? iconColor.withValues(alpha: isDark ? 0.18 : 0.08) : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: context.txtSecondary)),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            activeTrackColor: iconColor,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
