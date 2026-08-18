import 'dart:async';
import 'dart:developer' as dev;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/face_recognition_service.dart';
import '../../services/location_service.dart';

class FaceAttendanceDialog extends ConsumerStatefulWidget {
  const FaceAttendanceDialog({super.key});

  /// Static helper to launch Face Lock Attendance dialog cleanly
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const FaceAttendanceDialog(),
    );
    return result == true;
  }

  @override
  ConsumerState<FaceAttendanceDialog> createState() =>
      _FaceAttendanceDialogState();
}

class _FaceAttendanceDialogState extends ConsumerState<FaceAttendanceDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  late AnimationController _animController;
  late Animation<double> _laserAnimation;
  final FaceRecognitionService _faceService = FaceRecognitionService();

  bool _isCheckingEnrollment = true;
  bool _isEnrolled = false;
  bool _isAlreadyMarked = false;
  String? _alreadyMarkedTime;
  bool _isInitializingCamera = false;
  bool _isCameraInitialized = false;
  bool _isVerifying = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  bool _isPermanentlyDenied = false;

  String? _errorMessage;
  String _statusText = 'Checking attendance & face registration...';
  Timer? _faceScanTimer;

  String? _employeeId;
  String _employeeName = 'Employee';
  List<double>? _enrolledTemplate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dev.log('[FaceAttendance] Screen opened', name: 'FaceAttendance');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _verifyEnrollmentAndInit();
  }

  Future<void> _verifyEnrollmentAndInit() async {
    final auth = ref.read(authProvider);
    final user = auth.user;
    _employeeName = user?['name'] ?? 'Employee';
    final rawId = user?['id'] ?? user?['_id'] ?? user?['email'] ?? 'employee';
    _employeeId = rawId.toString();

    // 1. Check if Attendance is ALREADY marked for today
    final attState = ref.read(attendanceProvider);
    if (attState.isCheckedIn) {
      final checkInTime = attState.todayAttendance?.formattedCheckInTime ?? 'Today';
      dev.log('[FaceAttendance] Attendance already marked today at $checkInTime', name: 'FaceAttendance');
      if (mounted) {
        setState(() {
          _isCheckingEnrollment = false;
          _isAlreadyMarked = true;
          _alreadyMarkedTime = checkInTime;
          _statusText = 'Attendance is already marked for today.';
        });
      }
      return;
    }

    // 2. Check if enrolled face template exists for this employee
    final enrolledUserId = await _faceService.getEnrolledUserId();
    final effectiveId = enrolledUserId ?? _employeeId!;
    final template = await _faceService.getEnrolledFaceTemplate(userId: effectiveId);

    if (!mounted) return;

    if (template == null || template.isEmpty) {
      dev.log('[FaceAttendance] Face not enrolled for employee $effectiveId', name: 'FaceAttendance');
      setState(() {
        _isCheckingEnrollment = false;
        _isEnrolled = false;
        _errorMessage = 'Face is not registered. Please register your face first.';
        _statusText = 'Face Not Registered';
      });
      return;
    }

    _enrolledTemplate = template;
    setState(() {
      _isCheckingEnrollment = false;
      _isEnrolled = true;
      _statusText = 'Opening front camera...';
    });

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      dev.log('[FaceAttendance] App paused: disposing camera', name: 'FaceAttendance');
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && _isEnrolled && !_isAlreadyMarked) {
      dev.log('[FaceAttendance] App resumed: reinitializing camera', name: 'FaceAttendance');
      _initCamera();
    }
  }

  Future<void> _disposeCamera() async {
    _faceScanTimer?.cancel();
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
        dev.log('[FaceAttendance] Camera disposed', name: 'FaceAttendance');
      } catch (e) {
        dev.log('[FaceAttendance] Error disposing camera: $e', name: 'FaceAttendance');
      }
      _cameraController = null;
    }
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializingCamera || _isAlreadyMarked) return;
    _isInitializingCamera = true;

    if (mounted) {
      setState(() {
        _errorMessage = null;
        _isPermanentlyDenied = false;
        _isFailed = false;
        _statusText = 'Opening front camera...';
      });
    }

    try {
      final status = await Permission.camera.request();
      dev.log('[FaceAttendance] Camera permission: $status', name: 'FaceAttendance');

      if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _isPermanentlyDenied = true;
            _errorMessage = 'Camera permission permanently denied. Please enable in Settings.';
            _statusText = 'Camera permission required';
            _isInitializingCamera = false;
          });
        }
        return;
      }

      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Camera permission is required for Face Attendance.';
            _statusText = 'Permission required';
            _isInitializingCamera = false;
          });
        }
        return;
      }

      await _disposeCamera();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No camera found on this device.';
            _statusText = 'No camera available';
            _isInitializingCamera = false;
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
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      dev.log('[FaceAttendance] Front camera ready for attendance', name: 'FaceAttendance');

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isInitializingCamera = false;
        _statusText = 'Position face to mark attendance...';
      });

      _startFaceAttendanceScan(delayMs: 700);
    } catch (e) {
      dev.log('[FaceAttendance] Camera initialization failed: $e', name: 'FaceAttendance');
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to access camera. Please try again.';
          _statusText = 'Camera error';
          _isCameraInitialized = false;
          _isInitializingCamera = false;
        });
      }
    }
  }

  void _startFaceAttendanceScan({int delayMs = 400}) {
    _faceScanTimer?.cancel();
    setState(() {
      _isFailed = false;
      _isVerifying = false;
      _statusText = 'Align face with the circle...';
    });

    _faceScanTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!mounted || !_isCameraInitialized || _cameraController == null) return;

      setState(() {
        _isVerifying = true;
        _statusText = 'Scanning and verifying face...';
      });

      try {
        HapticFeedback.selectionClick();
      } catch (_) {}

      try {
        // 1. Capture live camera frame
        final XFile photo = await _cameraController!.takePicture();
        final Uint8List imageBytes = await photo.readAsBytes();

        // 2. Extract genuine 640-dimensional Zero-Mean biometric embedding
        final liveEmbedding = _faceService.extractFaceEmbeddingFromBytes(imageBytes);

        if (liveEmbedding == null) {
          if (mounted) {
            setState(() {
              _isVerifying = false;
              _isFailed = true;
              _statusText = 'Face not detected. Please position face clearly.';
            });
          }
          return;
        }

        // 3. Verify against the logged-in employee's registered face template
        final enrolled = _enrolledTemplate ??
            await _faceService.getEnrolledFaceTemplate(userId: _employeeId);

        if (enrolled == null || enrolled.isEmpty) {
          if (mounted) {
            setState(() {
              _isVerifying = false;
              _isFailed = true;
              _statusText = 'Face is not registered. Please register your face first.';
            });
          }
          return;
        }

        dev.log('[FaceAttendance] Comparing live face against employee: $_employeeId', name: 'FaceAttendance');
        final result = _faceService.verifyFaceVector(liveEmbedding, enrolled);

        dev.log('[FaceAttendance] Verification Score: ${result.similarityScore.toStringAsFixed(4)} (Threshold: ${FaceRecognitionService.securityThreshold})', name: 'FaceAttendance');
        dev.log('[FaceAttendance] Match Status: ${result.isSuccess ? "MATCH" : "NO_MATCH"}', name: 'FaceAttendance');

        if (!mounted) return;

        if (!result.isSuccess) {
          // --- DIFFERENT PERSON / IMPOSTOR REJECTED ---
          dev.log('[FaceAttendance] Attendance REJECTED: Face mismatch', name: 'FaceAttendance');
          setState(() {
            _isVerifying = false;
            _isFailed = true;
            _statusText = 'Face does not match with your registered face.';
          });
          return;
        }

        // --- FACE MATCHED: MARK ATTENDANCE ---
        dev.log('[FaceAttendance] Face MATCHED! Fetching GPS location and marking attendance...', name: 'FaceAttendance');
        setState(() {
          _statusText = 'Face Verified! Recording attendance...';
        });

        // 4. Fetch GPS Location
        double? latitude;
        double? longitude;
        final locRes = await LocationService.getCurrentLocation();
        if (locRes.isSuccess) {
          latitude = locRes.latitude;
          longitude = locRes.longitude;
        }

        if (!mounted) return;

        // 5. Call Attendance Provider faceCheckIn with attendanceMethod: 'FACE'
        final res = await ref.read(attendanceProvider.notifier).faceCheckIn(
              latitude: latitude,
              longitude: longitude,
              notes: 'Face Lock Verified ($_employeeName)',
            );

        if (!mounted) return;

        if (res['success'] == true) {
          setState(() {
            _isSuccess = true;
            _isVerifying = false;
            _isFailed = false;
            _statusText = 'Face verified. Attendance marked successfully. ✓';
          });

          try {
            HapticFeedback.heavyImpact();
          } catch (_) {}

          await Future.delayed(const Duration(milliseconds: 900));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          final msg = res['message']?.toString() ?? 'Failed to mark attendance.';
          final lower = msg.toLowerCase();
          final isAlready = lower.contains('already') || lower.contains('pehle');

          setState(() {
            _isVerifying = false;
            if (isAlready) {
              _isAlreadyMarked = true;
              _alreadyMarkedTime = 'Today';
            } else {
              _isFailed = true;
            }
            _statusText = msg;
          });
        }
      } catch (e) {
        dev.log('[FaceAttendance] Error during face attendance processing: $e', name: 'FaceAttendance');
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _isFailed = true;
            _statusText = 'Verification error. Tap Scan Again to retry.';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceScanTimer?.cancel();
    _animController.dispose();
    if (_cameraController != null) {
      try {
        _cameraController!.dispose();
        dev.log('[FaceAttendance] Camera disposed in dispose()', name: 'FaceAttendance');
      } catch (_) {}
      _cameraController = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isSuccess || _isAlreadyMarked
                ? const Color(0xFF10B981)
                : (_isFailed
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4F46E5).withValues(alpha: 0.4)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isCheckingEnrollment
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            : (_isAlreadyMarked
                ? _buildAlreadyMarkedView()
                : (!_isEnrolled ? _buildUnenrolledView() : _buildCameraScanningView())),
      ),
    );
  }

  // --- View shown when attendance is ALREADY marked for today ---
  Widget _buildAlreadyMarkedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Face Lock Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: Color(0xFF10B981),
            size: 56,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Attendance Already Marked! ✓',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'You have already marked your attendance for today.\nCheck-in Time: ${_alreadyMarkedTime ?? "Today"}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK, Understood', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // --- View shown when employee has NOT registered face yet ---
  Widget _buildUnenrolledView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.face_retouching_off_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Face Lock Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 52,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Face is not registered',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Please register your face first before using Face Lock Attendance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  context.push('/employee/face-lock');
                },
                icon: const Icon(Icons.face_unlock_rounded, size: 16),
                label: const Text('Register Face', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- View shown during Camera Face Scanning & Attendance Marking ---
  Widget _buildCameraScanningView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Bar: Title & Close
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.face_unlock_rounded,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Face Lock Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Verifying $_employeeName',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
              onPressed: () => Navigator.of(context).pop(false),
              splashRadius: 20,
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Circular Viewfinder
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera Feed
              ClipOval(
                child: Container(
                  width: 212,
                  height: 212,
                  color: const Color(0xFF020617),
                  child: _buildCameraPreview(),
                ),
              ),

              // Glowing Circle Ring
              Container(
                width: 218,
                height: 218,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isSuccess
                        ? const Color(0xFF10B981)
                        : (_isFailed
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6366F1)),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isSuccess
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : (_isFailed
                              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                              : const Color(0xFF6366F1).withValues(alpha: 0.25)),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),

              // Scanning Beam
              if (!_isSuccess && _isCameraInitialized && _errorMessage == null && !_isFailed)
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 212 * _laserAnimation.value,
                      child: Container(
                        width: 180,
                        height: 2.5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF6366F1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Success Overlay
              if (_isSuccess)
                Container(
                  width: 212,
                  height: 212,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xB310B981),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 64),
                  ),
                ).animate().scale(duration: const Duration(milliseconds: 200)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _isSuccess
                ? const Color(0x2610B981)
                : (_isFailed
                    ? const Color(0x26EF4444)
                    : const Color(0x266366F1)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isVerifying && !_isSuccess) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (_isSuccess) ...[
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                const SizedBox(width: 6),
              ] else if (_isFailed) ...[
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 15),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  _errorMessage ?? _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isSuccess
                        ? const Color(0xFF10B981)
                        : (_isFailed
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF818CF8)),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Action Buttons
        if (_isFailed && !_isSuccess) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _startFaceAttendanceScan(delayMs: 200),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Scan Again', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null && !_isCameraInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 36),
              const SizedBox(height: 6),
              Text(
                _isPermanentlyDenied ? 'Permission Denied' : 'Camera Unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
      );
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
