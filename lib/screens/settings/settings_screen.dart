import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/api_constants.dart';
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
              _buildUserHeaderCard(context, user, userName, userEmail, userRole),

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

  Widget _buildAvatarWidget(dynamic avatarOrUser, String name, double radius) {
    String? cleanAvatar = extractAvatarUrl(avatarOrUser);
    if (cleanAvatar != null &&
        cleanAvatar.isNotEmpty &&
        cleanAvatar != 'null' &&
        cleanAvatar != 'undefined') {
      if (cleanAvatar.contains('localhost') ||
          cleanAvatar.contains('127.0.0.1') ||
          cleanAvatar.contains('10.0.2.2')) {
        final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        cleanAvatar = cleanAvatar.replaceAll(
          RegExp(r'https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?'),
          apiBase,
        );
      }

      // 1. Direct HTTP/HTTPS Network URL
      if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: cleanAvatar,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary,
              child: Text(
                name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                ),
              ),
            ),
          ),
        );
      }

      // 2. Base64 Data URI or Raw Base64 String
      if (cleanAvatar.startsWith('data:image/') ||
          (!cleanAvatar.startsWith('/') &&
           !cleanAvatar.startsWith('uploads') &&
           cleanAvatar.length > 50)) {
        try {
          String base64Str = cleanAvatar.contains(',') ? cleanAvatar.split(',').last : cleanAvatar;
          base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
          while (base64Str.length % 4 != 0) {
            base64Str += '=';
          }
          final bytes = base64Decode(base64Str);
          if (bytes.isNotEmpty) {
            return CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: MemoryImage(bytes),
            );
          }
        } catch (_) {}
      }

      // 3. Relative Server Path (e.g. /uploads/..., uploads/..., /public/...)
      if (cleanAvatar.startsWith('/') ||
          cleanAvatar.startsWith('uploads') ||
          cleanAvatar.startsWith('public') ||
          cleanAvatar.startsWith('storage') ||
          cleanAvatar.contains('.png') ||
          cleanAvatar.contains('.jpg') ||
          cleanAvatar.contains('.jpeg') ||
          cleanAvatar.contains('.webp')) {
        final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        final fullUrl = '$apiBase${cleanAvatar.startsWith('/') ? '' : '/'}$cleanAvatar';
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary,
              child: Text(
                name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                ),
              ),
            ),
          ),
        );
      }

      // 4. Local File Path
      if (cleanAvatar.startsWith('file://') || cleanAvatar.startsWith('/') || cleanAvatar.contains(':\\')) {
        try {
          final filePath = cleanAvatar.replaceFirst('file://', '');
          final file = File(filePath);
          if (file.existsSync()) {
            return CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: FileImage(file),
            );
          }
        } catch (_) {}
      }
    }

    // 5. Fallback Initial Letter
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard(
    BuildContext context,
    Map<String, dynamic>? user,
    String name,
    String email,
    String role,
  ) {
    final avatar = user?['avatar']?.toString() ??
        user?['profilePicture']?.toString() ??
        user?['image']?.toString();
    final phone = user?['phone']?.toString() ?? user?['phoneNumber']?.toString();

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
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  _buildAvatarWidget(avatar, name, 30),
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
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showEditProfileModal(context, user),
              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
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
    final currentPhone = user?['phone']?.toString() ?? user?['phoneNumber']?.toString() ?? '';
    final currentEmail = user?['email']?.toString() ?? '';
    final currentRole = (user?['role']?.toString() ?? 'Employee').toUpperCase();
    String? currentAvatar = user?['avatar']?.toString() ??
        user?['profilePicture']?.toString() ??
        user?['image']?.toString();

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
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (pickedFile != null) {
                  final bytes = await pickedFile.readAsBytes();
                  final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
                  setModalState(() {
                    selectedBase64Image = base64String;
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

              final success = await ref.read(authProvider.notifier).updateUserProfile(
                name: newName,
                phone: newPhone.isNotEmpty ? newPhone : null,
                profilePicture: selectedBase64Image,
              );

              if (modalCtx.mounted) {
                Navigator.of(modalCtx).pop();
              }

              if (success) {
                _showSnackBar('Profile & Photo updated successfully! ✓', AppColors.accentGreen);
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                          _buildAvatarWidget(selectedBase64Image, nameController.text, 45),
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
                                          leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                                          title: const Text('Choose from Gallery'),
                                          onTap: () {
                                            Navigator.pop(pickerCtx);
                                            pickImage(ImageSource.gallery);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF06B6D4)),
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
                                  border: Border.all(color: modalCtx.cardBg, width: 2),
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
                                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () {
                                    Navigator.pop(pickerCtx);
                                    pickImage(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF06B6D4)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving ? null : saveProfile,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Save Profile Changes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
