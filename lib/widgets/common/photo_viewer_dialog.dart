import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';

/// Shows a full-screen interactive photo viewer dialog with pinch-to-zoom
void showPhotoPreview(
  BuildContext context, {
  required dynamic avatarOrUser,
  String? title,
  String? subtitle,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return PhotoViewerDialog(
        avatarOrUser: avatarOrUser,
        title: title,
        subtitle: subtitle,
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

class PhotoViewerDialog extends StatefulWidget {
  final dynamic avatarOrUser;
  final String? title;
  final String? subtitle;

  const PhotoViewerDialog({
    super.key,
    required this.avatarOrUser,
    this.title,
    this.subtitle,
  });

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog> {
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  static const Map<String, String> _networkHeaders = {
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformController.value = Matrix4.identity()
        ..storage[0] = 2.5
        ..storage[5] = 2.5
        ..storage[12] = -position.dx * 1.5
        ..storage[13] = -position.dy * 1.5;
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? cleanAvatar = extractAvatarUrl(widget.avatarOrUser);
    final displayName = widget.title ??
        (widget.avatarOrUser is Map
            ? (widget.avatarOrUser['name'] ??
                widget.avatarOrUser['fullName'] ??
                widget.avatarOrUser['firstName'] ??
                'Profile Photo')
            : 'Profile Photo');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),

          // Main Photo Interactive Viewer Area
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 4.5,
                  clipBehavior: Clip.none,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.92,
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildImageContent(cleanAvatar, displayName),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top App Bar with Title and Close Button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Glassy Close Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.subtitle ?? 'Profile Photo',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Reset Zoom Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _transformController.value = Matrix4.identity();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Hint Overlay
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pinch_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pinch or double tap to zoom',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isValidImageBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    // JPEG: FF D8
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP: RIFF ... WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    return false;
  }

  Widget _buildImageContent(String? cleanAvatar, String displayName) {
    if (cleanAvatar == null ||
        cleanAvatar.isEmpty ||
        cleanAvatar == 'null' ||
        cleanAvatar == 'undefined') {
      return _buildFallbackCard(displayName);
    }

    cleanAvatar = cleanAvatar.trim().replaceAll(r'\/', '/').replaceAll(r'\', '/');
    if (cleanAvatar.startsWith('//')) {
      cleanAvatar = 'https:$cleanAvatar';
    }

    // 1. Base64
    if (cleanAvatar.startsWith('data:image/') ||
        cleanAvatar.startsWith('data:application/') ||
        (!cleanAvatar.startsWith('http://') &&
            !cleanAvatar.startsWith('https://') &&
            !cleanAvatar.startsWith('file://') &&
            !cleanAvatar.startsWith('/') &&
            !cleanAvatar.startsWith('uploads') &&
            cleanAvatar.length > 50)) {
      try {
        String base64Str = cleanAvatar.contains(',') ? cleanAvatar.split(',').last : cleanAvatar;
        base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
        while (base64Str.length % 4 != 0) {
          base64Str += '=';
        }
        final bytes = base64Decode(base64Str);
        if (bytes.isNotEmpty && _isValidImageBytes(bytes)) {
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildFallbackCard(displayName),
          );
        }
      } catch (_) {}
      if (!cleanAvatar.startsWith('http://') &&
          !cleanAvatar.startsWith('https://') &&
          !cleanAvatar.startsWith('/') &&
          !cleanAvatar.startsWith('uploads')) {
        return _buildFallbackCard(displayName);
      }
    }

    // 2. Local File
    if (cleanAvatar.startsWith('file://') ||
        cleanAvatar.contains(':\\') ||
        cleanAvatar.startsWith('/data/') ||
        cleanAvatar.startsWith('/storage/')) {
      try {
        final filePath = cleanAvatar.replaceFirst('file://', '');
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildFallbackCard(displayName),
          );
        }
      } catch (_) {}
      return _buildFallbackCard(displayName);
    }

    // 3. HTTP/HTTPS Network URL
    if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
      final uri = Uri.tryParse(cleanAvatar);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.host.length > 120) {
        return _buildFallbackCard(displayName);
      }
      return CachedNetworkImage(
        imageUrl: cleanAvatar,
        httpHeaders: _networkHeaders,
        fit: BoxFit.contain,
        placeholder: (ctx, url) => Container(
          width: 260,
          height: 260,
          color: const Color(0xFF1E293B),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        ),
        errorWidget: (ctx, url, err) => _buildFallbackCard(displayName),
      );
    }

    // 4. Relative server path
    if (cleanAvatar.startsWith('/') ||
        cleanAvatar.startsWith('uploads') ||
        cleanAvatar.startsWith('public') ||
        cleanAvatar.startsWith('storage') ||
        cleanAvatar.startsWith('images') ||
        cleanAvatar.startsWith('assets') ||
        cleanAvatar.startsWith('photos') ||
        cleanAvatar.startsWith('profiles')) {
      final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final fullUrl = '$apiBase${cleanAvatar.startsWith('/') ? '' : '/'}$cleanAvatar';
      final uri = Uri.tryParse(fullUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        return _buildFallbackCard(displayName);
      }
      return CachedNetworkImage(
        imageUrl: fullUrl,
        httpHeaders: _networkHeaders,
        fit: BoxFit.contain,
        placeholder: (ctx, url) => Container(
          width: 260,
          height: 260,
          color: const Color(0xFF1E293B),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        ),
        errorWidget: (ctx, url, err) => _buildFallbackCard(displayName),
      );
    }

    return _buildFallbackCard(displayName);
  }

  Widget _buildFallbackCard(String displayName) {
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : 'U';
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
