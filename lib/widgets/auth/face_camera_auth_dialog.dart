import 'dart:async';
import 'dart:developer' as dev;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/face_recognition_service.dart';

class FaceCameraAuthDialog extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final bool isEnrollment;
  final VoidCallback? onFallbackToFingerprint;
  final VoidCallback? onFallbackToPassword;

  const FaceCameraAuthDialog({
    super.key,
    this.title = 'Face Unlock',
    this.subtitle = 'Look at the camera to verify your identity',
    this.isEnrollment = false,
    this.onFallbackToFingerprint,
    this.onFallbackToPassword,
  });

  /// Static helper to show the dialog cleanly
  static Future<bool> show(
    BuildContext context, {
    String title = 'Face Unlock',
    String subtitle = 'Look at the camera to verify your identity',
    bool isEnrollment = false,
    VoidCallback? onFallbackToFingerprint,
    VoidCallback? onFallbackToPassword,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FaceCameraAuthDialog(
        title: title,
        subtitle: subtitle,
        isEnrollment: isEnrollment,
        onFallbackToFingerprint: onFallbackToFingerprint,
        onFallbackToPassword: onFallbackToPassword,
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<FaceCameraAuthDialog> createState() =>
      _FaceCameraAuthDialogState();
}

class _FaceCameraAuthDialogState extends ConsumerState<FaceCameraAuthDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  late AnimationController _animController;
  late Animation<double> _laserAnimation;
  final FaceRecognitionService _faceService = FaceRecognitionService();

  bool _isInitializing = false;
  bool _isCameraInitialized = false;
  bool _isVerifying = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  bool _isPermanentlyDenied = false;
  String? _errorMessage;
  String _statusText = 'Starting camera...';
  Timer? _faceScanTimer;

  // Pre-cached authentication session & template for instant verification
  Map<String, dynamic>? _cachedSession;
  List<double>? _cachedEnrolledTemplate;
  String? _cachedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dev.log('[FaceLock] Screen opened', name: 'FaceLock');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Pre-warm data & start camera immediately
    _preWarmAuthData();
    _initCamera();
  }

  Future<void> _preWarmAuthData() async {
    try {
      final session = await BiometricAuthService.getSecureSession();
      final auth = ref.read(authProvider);
      final savedUser = session?['user'] as Map<String, dynamic>?;
      final enrolledUserId = await _faceService.getEnrolledUserId();
      final effectiveUser = auth.user ?? savedUser;

      _cachedSession = session;
      _cachedUserId = enrolledUserId ??
          effectiveUser?['id']?.toString() ??
          effectiveUser?['_id']?.toString() ??
          effectiveUser?['email']?.toString() ??
          effectiveUser?['name']?.toString() ??
          'registered_employee';

      _cachedEnrolledTemplate = await _faceService.getEnrolledFaceTemplate(userId: _cachedUserId);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      dev.log('[FaceLock] App paused: disposing camera', name: 'FaceLock');
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      dev.log('[FaceLock] App resumed: reinitializing camera', name: 'FaceLock');
      _initCamera();
    }
  }

  Future<void> _disposeCamera() async {
    _faceScanTimer?.cancel();
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
        dev.log('[FaceLock] Camera disposed', name: 'FaceLock');
      } catch (e) {
        dev.log('[FaceLock] Error disposing camera: $e', name: 'FaceLock');
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
    if (_isInitializing) return;
    _isInitializing = true;

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
      dev.log('[FaceLock] Camera permission: $status', name: 'FaceLock');

      if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _isPermanentlyDenied = true;
            _errorMessage = 'Camera permission permanently denied. Please enable in Settings.';
            _statusText = 'Camera permission required';
            _isInitializing = false;
          });
        }
        return;
      }

      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Camera permission is required for Face Lock.';
            _statusText = 'Permission required';
            _isInitializing = false;
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
            _isInitializing = false;
          });
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Low resolution preset allows ultra-fast frame capture (< 50ms)
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

      dev.log('[FaceLock] Front camera initialized successfully', name: 'FaceLock');

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isInitializing = false;
        _statusText = widget.isEnrollment
            ? 'Align face to register Face Lock...'
            : 'Looking for face...';
      });

      // Start fast face processing immediately after auto-exposure stabilization
      _startFastFaceProcessing();
    } catch (e) {
      dev.log('[FaceLock] Camera initialization failed: $e', name: 'FaceLock');
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to access camera. Please try again.';
          _statusText = 'Camera error';
          _isCameraInitialized = false;
          _isInitializing = false;
        });
      }
    }
  }

  void _startFastFaceProcessing() {
    _faceScanTimer?.cancel();
    setState(() {
      _isFailed = false;
      _isVerifying = false;
      _statusText = widget.isEnrollment ? 'Scanning face...' : 'Verifying face...';
    });

    // 250ms initial delay allows camera sensor exposure to balance before instant capture
    _faceScanTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted || !_isCameraInitialized || _cameraController == null) return;

      setState(() {
        _isVerifying = true;
        _statusText = widget.isEnrollment
            ? 'Extracting facial features...'
            : 'Verifying facial identity...';
      });

      try {
        HapticFeedback.selectionClick();
      } catch (_) {}

      try {
        // Instant live frame capture
        final XFile photo = await _cameraController!.takePicture();
        final Uint8List imageBytes = await photo.readAsBytes();

        // Extract 224-d facial embedding vector
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

        // Get user ID
        final auth = ref.read(authProvider);
        final currentUser = auth.user;
        final savedUser = _cachedSession?['user'] as Map<String, dynamic>?;
        final effectiveUser = currentUser ?? savedUser;
        final userId = _cachedUserId ??
            effectiveUser?['id']?.toString() ??
            effectiveUser?['_id']?.toString() ??
            effectiveUser?['email']?.toString() ??
            'registered_employee';

        dev.log('[FaceAuth] User ID: $userId', name: 'FaceAuth');
        dev.log('[FaceAuth] Face detected: true', name: 'FaceAuth');
        dev.log('[FaceAuth] Live embedding generated: true (dims: ${liveEmbedding.length})', name: 'FaceAuth');

        if (widget.isEnrollment) {
          // --- ENROLLMENT MODE ---
          final enrolled = await _faceService.enrollFaceTemplate(
            userId: userId,
            featureVector: liveEmbedding,
          );

          if (enrolled && mounted) {
            await BiometricAuthService.setFaceLockEnabled(
              true,
              token: auth.token,
              user: auth.user ?? savedUser,
              role: auth.role ?? _cachedSession?['role']?.toString(),
            );

            setState(() {
              _isSuccess = true;
              _isVerifying = false;
              _isFailed = false;
              _statusText = 'Face Lock Registered! ✓';
            });

            try {
              HapticFeedback.heavyImpact();
            } catch (_) {}

            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } else if (mounted) {
            setState(() {
              _isVerifying = false;
              _isFailed = true;
              _statusText = 'Failed to register face. Please retry.';
            });
          }
        } else {
          // --- VERIFICATION MODE ---
          final enrolledTemplate = _cachedEnrolledTemplate ??
              await _faceService.getEnrolledFaceTemplate(userId: userId);
          dev.log('[FaceAuth] Enrolled template found: ${enrolledTemplate != null}', name: 'FaceAuth');

          if (enrolledTemplate == null || enrolledTemplate.isEmpty) {
            dev.log('[FaceAuth] Authentication result: DENIED (No enrolled template)', name: 'FaceAuth');
            if (mounted) {
              setState(() {
                _isVerifying = false;
                _isFailed = true;
                _statusText = 'No registered face found. Please set up in Settings.';
              });
            }
            return;
          }

          final result = _faceService.verifyFaceVector(liveEmbedding, enrolledTemplate);
          dev.log('[FaceAuth] Similarity score: ${result.similarityScore.toStringAsFixed(4)}', name: 'FaceAuth');
          dev.log('[FaceAuth] Required threshold: ${FaceRecognitionService.securityThreshold}', name: 'FaceAuth');
          dev.log('[FaceAuth] Match result: ${result.isSuccess ? "MATCH" : "NO_MATCH"}', name: 'FaceAuth');
          dev.log('[FaceAuth] Authentication result: ${result.isSuccess ? "ALLOWED" : "DENIED"}', name: 'FaceAuth');
          dev.log('[FaceAuth] Unlock triggered by: FaceRecognitionService.verifyFaceVector', name: 'FaceAuth');

          if (!mounted) return;

          if (result.isSuccess) {
            if (_cachedSession != null) {
              await ref.read(authProvider.notifier).restoreBiometricSession(_cachedSession!);
            }

            setState(() {
              _isSuccess = true;
              _isVerifying = false;
              _isFailed = false;
              _statusText = 'Face Verified! ✓';
            });

            try {
              HapticFeedback.heavyImpact();
            } catch (_) {}

            // Immediate fast pop without waiting
            await Future.delayed(const Duration(milliseconds: 150));
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } else {
            setState(() {
              _isVerifying = false;
              _isFailed = true;
              _statusText = 'Face not recognized. Please try again.';
            });
          }
        }
      } catch (e) {
        dev.log('[FaceAuth] Error during face processing: $e', name: 'FaceAuth');
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _isFailed = true;
            _statusText = 'Unable to verify face. Tap to retry.';
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
        dev.log('[FaceLock] Camera disposed in dispose()', name: 'FaceLock');
      } catch (_) {}
      _cameraController = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isSuccess
                ? const Color(0xFF10B981)
                : (_isFailed
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF06B6D4).withValues(alpha: 0.3)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar: Simple Title & Close
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
                        color: Color(0xFF06B6D4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.subtitle,
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

            // Clean Circular Camera Viewport
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera feed inside clean circle
                  ClipOval(
                    child: Container(
                      width: 212,
                      height: 212,
                      color: const Color(0xFF020617),
                      child: _buildCameraPreview(),
                    ),
                  ),

                  // Circular Glowing Border Ring
                  Container(
                    width: 218,
                    height: 218,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSuccess
                            ? const Color(0xFF10B981)
                            : (_isFailed
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF06B6D4).withValues(alpha: 0.7)),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isSuccess
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF06B6D4).withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  // Subtle Scanning Beam
                  if (!_isSuccess && _isCameraInitialized && _errorMessage == null && !_isFailed)
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 212 * _laserAnimation.value,
                          child: Container(
                            width: 180,
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFF06B6D4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Success Checkmark Overlay
                  if (_isSuccess)
                    Container(
                      width: 212,
                      height: 212,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xA610B981),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 64),
                      ),
                    ).animate().scale(duration: const Duration(milliseconds: 200)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Clean Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? const Color(0x2610B981)
                    : (_isFailed
                        ? const Color(0x26F59E0B)
                        : const Color(0x2606B6D4)),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (_isSuccess) ...[
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                    const SizedBox(width: 6),
                  ] else if (_isFailed) ...[
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 15),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _errorMessage ?? _statusText,
                    style: TextStyle(
                      color: _isSuccess
                          ? const Color(0xFF10B981)
                          : (_isFailed
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF06B6D4)),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Retry Scan Button on Failure
            if (_isFailed && !_isSuccess) ...[
              ElevatedButton.icon(
                onPressed: _startFastFaceProcessing,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Scan Again', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Fallback Options
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onFallbackToFingerprint != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      widget.onFallbackToFingerprint!();
                    },
                    icon: const Icon(Icons.fingerprint_rounded, size: 16, color: Color(0xFF818CF8)),
                    label: const Text(
                      'Use Fingerprint',
                      style: TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.onFallbackToPassword != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      widget.onFallbackToPassword!();
                    },
                    icon: const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                    label: const Text(
                      'Use Password',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
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
