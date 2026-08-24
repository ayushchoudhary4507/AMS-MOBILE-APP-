import 'dart:async';
import 'dart:developer' as dev;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/biometric_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/face_attendance_log_service.dart';
import '../../services/face_recognition_service.dart';

class FaceLockRegistrationScreen extends ConsumerStatefulWidget {
  const FaceLockRegistrationScreen({super.key});

  @override
  ConsumerState<FaceLockRegistrationScreen> createState() =>
      _FaceLockRegistrationScreenState();
}

class _FaceLockRegistrationScreenState
    extends ConsumerState<FaceLockRegistrationScreen>
    with WidgetsBindingObserver {
  final FaceRecognitionService _faceService = FaceRecognitionService();

  CameraController? _cameraController;
  bool _isCheckingStatus = true;
  bool _isEnrolled = false;
  String? _enrollmentDate;

  bool _isCameraOpen = false;
  bool _isInitializingCamera = false;
  bool _isCapturing = false;
  String? _errorMessage;
  String _cameraStatus = 'Align your face inside the frame';

  String? _employeeId;
  String _employeeName = 'Employee';
  String _employeeEmail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEmployeeFaceStatus();
  }

  Future<void> _loadEmployeeFaceStatus() async {
    final auth = ref.read(authProvider);
    final user = auth.user;

    _employeeName = user?['name']?.toString() ?? 'Employee';
    _employeeEmail = user?['email']?.toString() ?? '';
    final rawId = user?['id'] ?? user?['_id'] ?? user?['email'] ?? 'employee';
    _employeeId = rawId.toString();

    final hasTemplate = await _faceService.hasEnrolledFaceTemplate(userId: _employeeId);
    final enrolledUserId = await _faceService.getEnrolledUserId();

    // Check if enrolled for this specific employee
    final isEnrolledForMe = hasTemplate && (enrolledUserId == null || enrolledUserId == _employeeId);

    if (mounted) {
      setState(() {
        _isCheckingStatus = false;
        _isEnrolled = isEnrolledForMe;
        _enrollmentDate = isEnrolledForMe ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()) : null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
        dev.log('[FaceRegistration] Camera disposed', name: 'FaceRegistration');
      } catch (e) {
        dev.log('[FaceRegistration] Camera dispose error: $e', name: 'FaceRegistration');
      }
      _cameraController = null;
    }
    if (mounted) {
      setState(() {
        _isCameraOpen = false;
        _isInitializingCamera = false;
        _isCapturing = false;
      });
    }
  }

  Future<void> _openCamera() async {
    if (_isInitializingCamera) return;
    setState(() {
      _isInitializingCamera = true;
      _errorMessage = null;
      _cameraStatus = 'Starting front camera...';
    });

    try {
      final permStatus = await Permission.camera.request();
      if (!permStatus.isGranted) {
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _errorMessage = permStatus.isPermanentlyDenied
                ? 'Camera permission permanently denied. Please enable in Device Settings.'
                : 'Camera permission is required for face registration.';
          });
        }
        return;
      }

      await _disposeCamera();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _errorMessage = 'No camera found on this device.';
          });
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraOpen = true;
        _isInitializingCamera = false;
        _cameraStatus = 'Align your face in the circle & tap "Register Face"';
      });
    } catch (e) {
      dev.log('[FaceRegistration] Camera init error: $e', name: 'FaceRegistration');
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _errorMessage = 'Unable to start camera: $e';
        });
      }
    }
  }

  Future<void> _captureAndRegisterFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _cameraStatus = 'Capturing face & generating embedding...';
      _errorMessage = null;
    });

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    try {
      // 1. Capture camera frame
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();

      // 2. Validate that real face is detected & extract 224-d face embedding
      final embedding = _faceService.extractFaceEmbeddingFromBytes(imageBytes);

      if (embedding == null) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _cameraStatus = 'Face not detected clearly. Position face & retry.';
            _errorMessage = 'No face detected in the frame. Please look directly at the camera in good lighting.';
          });
        }
        return;
      }

      // 3. Associate and save face template strictly with authenticated employee ID
      final auth = ref.read(authProvider);
      final rawId = auth.user?['id'] ?? auth.user?['_id'] ?? auth.user?['email'] ?? _employeeId;
      final effectiveUserId = rawId.toString();
      final effectiveUser = auth.user ?? {'id': effectiveUserId, 'name': _employeeName, 'email': _employeeEmail};

      final caps = ref.read(biometricProvider).capabilities;
      final profile = FaceBiometricProfile(
        userId: effectiveUserId,
        userName: _employeeName,
        email: _employeeEmail,
        role: auth.role ?? effectiveUser['role']?.toString() ?? 'employee',
        token: auth.token,
        userData: effectiveUser,
        faceTemplate: embedding,
        enrolledAt: DateTime.now(),
        isFingerprintEnabled: caps.isFingerprintEnabled,
        isFaceLockEnabled: true,
      );

      final success = await _faceService.saveFaceProfile(profile);

      if (success && mounted) {
        // Save registered face photo thumbnail for Admin verification directory
        try {
          final regBase64 = FaceAttendanceLogService.compressImageToBase64(imageBytes);
          if (regBase64 != null) {
            await FaceAttendanceLogService().saveRegisteredFaceImage(
              userId: effectiveUserId,
              imageBase64: regBase64,
            );
          }
        } catch (e) {
          dev.log('[FaceRegistration] Error saving reg photo: $e', name: 'FaceRegistration');
        }

        // Also enable Face Lock capability in BiometricNotifier
        await ref.read(biometricProvider.notifier).setFaceLockEnabled(
              true,
              token: auth.token,
              user: effectiveUser,
              role: auth.role,
            );

        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}

        await _disposeCamera();

        if (mounted) {
          setState(() {
            _isEnrolled = true;
            _enrollmentDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
            _isCapturing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Face registered successfully! ✓',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = 'Failed to save face data. Please try again.';
        });
      }
    } catch (e) {
      dev.log('[FaceRegistration] Capture error: $e', name: 'FaceRegistration');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = 'Error capturing face: $e';
        });
      }
    }
  }

  Future<void> _removeFaceData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Remove Face Data?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove your registered face? You will need to register again to use Face Lock Attendance.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _faceService.clearEnrolledFaceTemplate(userId: _employeeId);
      await ref.read(biometricProvider.notifier).setFaceLockEnabled(false);
      await _disposeCamera();

      if (mounted) {
        setState(() {
          _isEnrolled = false;
          _enrollmentDate = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face data removed.'),
            backgroundColor: Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Face Lock',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isEnrolled && !_isCameraOpen)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Remove Face Data',
              onPressed: _removeFaceData,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Employee Info & Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.face_unlock_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _employeeName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${_employeeId ?? "Employee"}${_employeeEmail.isNotEmpty ? " • $_employeeEmail" : ""}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Face Registration Status Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _isEnrolled
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isEnrolled
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isEnrolled
                                  ? Icons.verified_rounded
                                  : Icons.warning_amber_rounded,
                              color: _isEnrolled
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isEnrolled ? '✓ Face Registered' : '⚠ Face Not Registered',
                              style: TextStyle(
                                color: _isEnrolled
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isEnrolled
                              ? 'Your face is registered and bound to employee ID $_employeeId. You can mark attendance using Face Lock Attendance.'
                              : 'Register your face once so you can quickly mark your attendance using Face Lock Attendance.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        if (_enrollmentDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Enrolled on: $_enrollmentDate',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Camera View & Registration Section
                  if (_isCameraOpen) ...[
                    // Camera Live Viewport
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020617),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Face Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipOval(
                                  child: Container(
                                    width: 230,
                                    height: 230,
                                    color: Colors.black,
                                    child: _buildCameraPreview(),
                                  ),
                                ),
                                Container(
                                  width: 236,
                                  height: 236,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF06B6D4),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isCapturing)
                                  Container(
                                    width: 230,
                                    height: 230,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0x99000000),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _cameraStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _disposeCamera,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF334155)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _isCapturing ? null : _captureAndRegisterFace,
                                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                  label: Text(
                                    _isCapturing ? 'Registering...' : 'Register Face',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Button to Open Camera
                    ElevatedButton.icon(
                      onPressed: _isInitializingCamera ? null : _openCamera,
                      icon: _isInitializingCamera
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.videocam_rounded, size: 20),
                      label: Text(
                        _isEnrolled ? 'Update / Re-Register Face' : 'Open Camera to Register Face',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),

                  // 4. Instructions Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            Text(
                              'Face Registration Tips',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildTipRow('Hold the phone directly in front of your face in a well-lit area.'),
                        _buildTipRow('Keep your facial expression natural and look at the camera.'),
                        _buildTipRow('Avoid strong backlighting or shadows across your face.'),
                        _buildTipRow('Once registered, you can mark attendance immediately using Face Lock.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxWidth * _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        );
      },
    );
  }
}
