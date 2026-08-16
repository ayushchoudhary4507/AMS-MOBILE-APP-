import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isCameraPermissionGranted = true;
  bool _isCheckingPermission = true;
  String? _statusText;

  @override
  void initState() {
    super.initState();

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(
        parent: _laserAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    setState(() => _isCheckingPermission = true);
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = true;
          _isCheckingPermission = false;
        });
      }
    } else {
      final requested = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = requested.isGranted;
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Handles barcode detection
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawData = barcodes.first.rawValue?.trim();
    if (rawData == null || rawData.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Verifying location & QR token...';
    });

    try {
      // Pause scanner while validating
      await _scannerController.stop();
    } catch (_) {}

    // Extract token if rawData is formatted JSON or plain text
    String qrToken = rawData;
    try {
      if (rawData.startsWith('{') && rawData.endsWith('}')) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) {
          qrToken = (decoded['qrToken'] ??
                  decoded['token'] ??
                  decoded['code'] ??
                  decoded['id'] ??
                  rawData)
              .toString();
        }
      }
    } catch (_) {
      qrToken = rawData;
    }

    // 1. Fetch Location Coordinates
    double? latitude;
    double? longitude;

    final locationResult = await LocationService.getCurrentLocation();
    if (locationResult.isSuccess) {
      latitude = locationResult.latitude;
      longitude = locationResult.longitude;
    } else {
      debugPrint('Location fetching notice: ${locationResult.errorMessage}');
    }

    if (!mounted) return;

    // 2. Send to Attendance Provider
    final res = await ref.read(attendanceProvider.notifier).qrCheckIn(
          qrToken: qrToken,
          latitude: latitude,
          longitude: longitude,
        );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _statusText = null;
    });

    if (res['success'] == true) {
      // 3. Show Success Modal
      final auth = ref.read(authProvider);
      final userName = auth.user?['name'] ?? 'Employee';
      final model = res['model'] as AttendanceModel?;
      final checkInTimeStr = model?.formattedCheckInTime ??
          DateFormat('hh:mm a').format(DateTime.now());
      final dateStr = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
      final statusStr = model?.status.toUpperCase() ?? 'PRESENT';
      final officeStr = res['office']?.toString();

      _showSuccessSheet(
        userName: userName,
        checkInTime: checkInTimeStr,
        date: dateStr,
        status: statusStr,
        office: officeStr,
      );
    } else {
      // 4. Show Error Dialog with Retry
      final message = res['message']?.toString() ??
          'Failed to record attendance. Please try again.';
      _showErrorDialog(message);
    }
  }

  void _showSuccessSheet({
    required String userName,
    required String checkInTime,
    required String date,
    required String status,
    String? office,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Animated Check Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF10B981),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Attendance Marked Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your check-in has been validated and recorded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.txtSecondary,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 20),

              // Summary Info Container
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.borderCol,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Employee',
                      value: userName,
                      color: const Color(0xFF6366F1),
                    ),
                    const Divider(height: 18, thickness: 0.7),
                    _buildSummaryRow(
                      icon: Icons.schedule_rounded,
                      label: 'Check-in Time',
                      value: checkInTime,
                      color: const Color(0xFF10B981),
                      isHighlight: true,
                    ),
                    const Divider(height: 18, thickness: 0.7),
                    _buildSummaryRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: date,
                      color: const Color(0xFF3B82F6),
                    ),
                    const Divider(height: 18, thickness: 0.7),
                    _buildSummaryRow(
                      icon: Icons.verified_outlined,
                      label: 'Status',
                      value: status,
                      color: const Color(0xFF10B981),
                      isBadge: true,
                    ),
                    if (office != null && office.isNotEmpty) ...[
                      const Divider(height: 18, thickness: 0.7),
                      _buildSummaryRow(
                        icon: Icons.business_rounded,
                        label: 'Location / Office',
                        value: office,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Return / Done Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/employee/dashboard');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isHighlight = false,
    bool isBadge = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: context.txtSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? const Color(0xFF4F46E5) : context.txtPrimary,
              fontSize: 13.5,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.accentRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scan Failed',
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: context.txtSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/employee/dashboard');
                }
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: context.txtSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() {
                  _isProcessing = false;
                });
                try {
                  await _scannerController.start();
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/employee/dashboard');
            }
          },
        ),
        title: const Text(
          'Scan Attendance QR',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Flash',
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white,
            ),
            onPressed: () async {
              try {
                await _scannerController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              } catch (_) {}
            },
          ),
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () async {
              try {
                await _scannerController.switchCamera();
              } catch (_) {}
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera View or Permission Denied Placeholder
          if (_isCheckingPermission)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          else if (!_isCameraPermissionGranted)
            _buildPermissionDeniedView()
          else
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),

          // 2. Scanner Overlay & Frame
          if (_isCameraPermissionGranted && !_isCheckingPermission)
            _buildScannerOverlay(),

          // 3. Loading Overlay
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    final scanWindowSize = MediaQuery.of(context).size.width * 0.72;

    return Stack(
      children: [
        // Semi-transparent cutout backdrop
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.65),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: scanWindowSize,
                  height: scanWindowSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Glowing Corner Brackets & Laser
        Center(
          child: SizedBox(
            width: scanWindowSize,
            height: scanWindowSize,
            child: Stack(
              children: [
                // Corner Borders
                Positioned.fill(
                  child: CustomPaint(
                    painter: _QRCornerBorderPainter(
                      color: const Color(0xFF6366F1),
                      cornerLength: 32,
                      strokeWidth: 4.5,
                      radius: 20,
                    ),
                  ),
                ),

                // Animated Laser Line
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: scanWindowSize * _laserAnimation.value,
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF818CF8),
                              Color(0xFF4F46E5),
                              Color(0xFF818CF8),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Instruction Text Header & Footer
        Positioned(
          top: 30,
          left: 20,
          right: 20,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF818CF8),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Scan the attendance QR code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 60,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text(
                'Position the QR code inside the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your location will be verified automatically',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Validating Attendance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusText ?? 'Verifying with server...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      color: context.cardBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 56,
                color: AppColors.accentRed,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Camera Access Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.txtPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'To scan the office attendance QR code, please allow camera permission in your app settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.txtSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
              },
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _checkCameraPermission(),
              child: const Text('Retry Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for sleek rounded corner brackets
class _QRCornerBorderPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double radius;

  _QRCornerBorderPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final l = cornerLength;

    // Top-Left Corner
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right Corner
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left Corner
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right Corner
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _QRCornerBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
