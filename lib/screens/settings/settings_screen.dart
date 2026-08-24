import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/theme_provider.dart';
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
      // SECURITY: biometricOnly=true prevents PIN/pattern/password fallback
      final result = await BiometricAuthService().authenticateWithResult(
        localizedReason: 'Scan fingerprint to enable Fingerprint Lock',
        biometricOnly: true,
      );

      if (result.authenticated && mounted) {
        await bioNotifier.setFingerprintEnabled(
          true,
          token: auth.token,
          user: auth.user,
          role: auth.role,
        );
        _showSnackBar(
          'Fingerprint Lock Enabled Successfully! ✓',
          AppColors.accentGreen,
        );
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
      // Direct Camera Face Lock Enrollment
      final success = await FaceCameraAuthDialog.show(
        context,
        title: 'Set Up Face Lock',
        subtitle: 'Position your face inside the circle to register Face Lock',
        isEnrollment: true,
      );

      if (success && mounted) {
        await bioNotifier.setFaceLockEnabled(
          true,
          token: auth.token,
          user: auth.user,
          role: auth.role,
        );
        await bioNotifier.checkCapabilities();
        _showSnackBar(
          'Face Lock Registered & Enabled Successfully! ✓',
          AppColors.accentGreen,
        );
      } else if (mounted) {
        await bioNotifier.checkCapabilities();
        _showSnackBar(
          'Face Lock setup was cancelled or failed.',
          AppColors.accentAmber,
        );
      }
    } else {
      await bioNotifier.setFaceLockEnabled(false);
      final userId = auth.user?['id'] ?? auth.user?['_id'] ?? auth.user?['email'];
      await FaceRecognitionService().clearEnrolledFaceTemplate(userId: userId?.toString());
      await bioNotifier.checkCapabilities();
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
    final userRole = (auth.role ?? user?['role']?.toString() ?? 'Employee')
        .toUpperCase();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: context.txtPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.txtPrimary,
          ),
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
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              // User Card Header
              _buildUserHeaderCard(
                context,
                user,
                userName,
                userEmail,
                userRole,
              ),

              const SizedBox(height: 22),

              // Section Title: Security & Biometrics
              _buildSectionTitle(
                context,
                'Security & Biometrics',
                Icons.security_rounded,
              ),
              const SizedBox(height: 12),

              // Fingerprint Option Card
              _buildBiometricOptionCard(
                context: context,
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Fingerprint Lock',
                subtitle: 'Unlock AMS app using your fingerprint scanner',
                isEnabled: caps.isFingerprintEnabled,
                isAvailable: caps.hasFingerprint || caps.isSupported,
                onChanged: (val) => _toggleFingerprint(val),
                badgeText: caps.isFingerprintEnabled
                    ? 'Active'
                    : (caps.hasFingerprint
                        ? 'Available'
                        : (caps.canCheckBiometrics ? 'Supported' : 'Not Detected')),
                badgeColor: caps.isFingerprintEnabled
                    ? AppColors.accentGreen
                    : const Color(0xFFF59E0B),
              ),

              const SizedBox(height: 12),

              // Face Lock Option Card
              _buildBiometricOptionCard(
                context: context,
                icon: Icons.face_retouching_natural_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Face Lock (Camera)',
                subtitle: 'Unlock AMS app using front camera facial recognition',
                isEnabled: caps.isFaceLockEnabled,
                isAvailable: true,
                onChanged: (val) => _toggleFaceLock(val),
                badgeText: caps.isFaceLockEnabled
                    ? 'Active'
                    : 'Camera Ready',
                badgeColor: caps.isFaceLockEnabled
                    ? AppColors.accentGreen
                    : const Color(0xFF06B6D4),
              ),

              const SizedBox(height: 22),

              // Section Title: Preferences
              _buildSectionTitle(
                context,
                'App Preferences',
                Icons.tune_rounded,
              ),
              const SizedBox(height: 12),

              // Dark Theme Card
              Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF272A3E)
                        : const Color(0xFFE2E8F0),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFF6366F1))
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
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
                            isDark
                                ? 'Dark theme active'
                                : 'Light theme active',
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
                      onChanged: (_) =>
                          ref.read(themeProvider.notifier).toggleTheme(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button Card
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

              // App Version Footer
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
                      'Secured with AES-256 Biometric Hash',
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

  Widget _buildAvatarWidget(dynamic avatarOrUser, String name, double radius) {
    return AppAvatar(
      avatarOrUser: avatarOrUser,
      fallbackText: name,
      radius: radius,
    );
  }

  Widget _buildUserHeaderCard(
    BuildContext context,
    Map<String, dynamic>? user,
    String name,
    String email,
    String role,
  ) {
    final isDark = context.isDark;
    final phone =
        user?['phone']?.toString() ?? user?['phoneNumber']?.toString();

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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
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
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📞 $phone',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.txtSecondary,
                        ),
                      ),
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
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showEditProfileModal(context, user),
              icon: const Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              label: const Text(
                'Edit Profile & Photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileModal(BuildContext context, Map<String, dynamic>? user) {
    final currentName = user?['name']?.toString() ?? '';
    final currentPhone =
        user?['phone']?.toString() ?? user?['phoneNumber']?.toString() ?? '';
    final currentEmail = user?['email']?.toString() ?? '';
    final currentRole = (user?['role']?.toString() ?? 'Employee').toUpperCase();
    String? currentAvatar = extractAvatarUrl(user);

    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

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
                final XFile? pickedFile = await picker.pickImage(
                  source: source,
                  maxWidth: 600,
                  maxHeight: 600,
                  imageQuality: 70,
                );
                if (pickedFile != null) {
                  setModalState(() {
                    selectedBase64Image = pickedFile.path;
                  });
                }
              } catch (e) {
                _showSnackBar('Could not pick image: $e', AppColors.accentRed);
              }
            }

            Future<void> saveProfile() async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();

              if (newName.isEmpty) {
                _showSnackBar('Name cannot be empty', AppColors.accentRed);
                return;
              }

              setModalState(() => isSaving = true);

              final success = await ref
                  .read(authProvider.notifier)
                  .updateUserProfile(
                    name: newName,
                    phone: newPhone.isNotEmpty ? newPhone : null,
                    profilePicture: selectedBase64Image,
                  );

              if (modalCtx.mounted) {
                Navigator.of(modalCtx).pop();
              }

              if (success) {
                _showSnackBar(
                  'Profile & Photo updated successfully! ✓',
                  AppColors.accentGreen,
                );
              } else {
                _showSnackBar('Failed to update profile.', AppColors.accentRed);
              }
            }

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: modalCtx.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: modalCtx.borderCol),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sheet handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: modalCtx.txtSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: modalCtx.txtPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Avatar Edit Circle with Camera Badge
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              showPhotoPreview(
                                modalCtx,
                                avatarOrUser: selectedBase64Image ?? user,
                                title: nameController.text,
                                subtitle: 'Profile Photo Preview',
                              );
                            },
                            child: _buildAvatarWidget(
                              selectedBase64Image ?? user,
                              nameController.text,
                              45,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: modalCtx,
                                  builder: (pickerCtx) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(
                                            Icons.photo_library_rounded,
                                            color: AppColors.primary,
                                          ),
                                          title: const Text(
                                            'Choose from Gallery',
                                          ),
                                          onTap: () {
                                            Navigator.pop(pickerCtx);
                                            pickImage(ImageSource.gallery);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Color(0xFF06B6D4),
                                          ),
                                          title: const Text('Take a Photo'),
                                          onTap: () {
                                            Navigator.pop(pickerCtx);
                                            pickImage(ImageSource.camera);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: modalCtx.cardBg,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: modalCtx,
                          builder: (pickerCtx) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.photo_library_rounded,
                                    color: AppColors.primary,
                                  ),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () {
                                    Navigator.pop(pickerCtx);
                                    pickImage(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Color(0xFF06B6D4),
                                  ),
                                  title: const Text('Take a Photo'),
                                  onTap: () {
                                    Navigator.pop(pickerCtx);
                                    pickImage(ImageSource.camera);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: const Text('Change Profile Picture'),
                    ),
                    const SizedBox(height: 16),

                    // Name Field
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: modalCtx.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Field
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: modalCtx.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Read-only Email Field
                    TextField(
                      controller: TextEditingController(text: currentEmail),
                      readOnly: true,
                      enabled: false,
                      style: TextStyle(color: modalCtx.txtSecondary),
                      decoration: InputDecoration(
                        labelText: 'Email Address (Read-only)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Read-only Role Field
                    TextField(
                      controller: TextEditingController(text: currentRole),
                      readOnly: true,
                      enabled: false,
                      style: TextStyle(color: modalCtx.txtSecondary),
                      decoration: InputDecoration(
                        labelText: 'Role (Read-only)',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isSaving ? null : saveProfile,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Profile Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnabled
              ? iconColor.withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF272A3E) : const Color(0xFFE2E8F0)),
          width: isEnabled ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? iconColor.withValues(alpha: isDark ? 0.18 : 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: context.txtSecondary),
                ),
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
