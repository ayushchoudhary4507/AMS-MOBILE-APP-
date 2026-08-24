import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import 'photo_viewer_dialog.dart';

class AppAvatar extends StatelessWidget {
  final dynamic avatarOrUser;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;
  final bool enablePreview;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.avatarOrUser,
    this.fallbackText = 'U',
    this.radius = 20,
    this.backgroundColor,
    this.enablePreview = true,
    this.onTap,
  });

  static const Map<String, String> _networkHeaders = {
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  @override
  Widget build(BuildContext context) {
    final avatarWidget = _buildAvatarContent(context);

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarWidget,
      );
    }

    if (enablePreview) {
      return GestureDetector(
        onTap: () {
          showPhotoPreview(
            context,
            avatarOrUser: avatarOrUser,
            title: fallbackText.trim().isNotEmpty && fallbackText != 'U'
                ? fallbackText
                : null,
          );
        },
        behavior: HitTestBehavior.opaque,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  bool _isValidImageBytes(List<int> bytes) {
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

  Widget _buildAvatarContent(BuildContext context) {
    String? cleanAvatar = extractAvatarUrl(avatarOrUser);
    final bgColor = backgroundColor ?? const Color(0xFF4F46E5);

    if (cleanAvatar == null ||
        cleanAvatar.isEmpty ||
        cleanAvatar == 'null' ||
        cleanAvatar == 'undefined') {
      return _fallbackInitials(bgColor);
    }

    cleanAvatar = cleanAvatar.trim().replaceAll(r'\/', '/').replaceAll(r'\', '/');
    if (cleanAvatar.startsWith('//')) {
      cleanAvatar = 'https:$cleanAvatar';
    }

    final targetSize = radius * 2;

    // 1. Data URI or Raw Base64 string
    if (cleanAvatar.startsWith('data:image/') ||
        cleanAvatar.startsWith('data:application/') ||
        (!cleanAvatar.startsWith('http://') &&
            !cleanAvatar.startsWith('https://') &&
            !cleanAvatar.startsWith('/') &&
            !cleanAvatar.startsWith('uploads') &&
            !cleanAvatar.startsWith('file://') &&
            cleanAvatar.length > 50)) {
      try {
        String base64Str =
            cleanAvatar.contains(',') ? cleanAvatar.split(',').last : cleanAvatar;
        base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
        while (base64Str.length % 4 != 0) {
          base64Str += '=';
        }
        final bytes = base64Decode(base64Str);
        if (bytes.isNotEmpty && _isValidImageBytes(bytes)) {
          return ClipOval(
            child: Image.memory(
              bytes,
              width: targetSize,
              height: targetSize,
              fit: BoxFit.cover,
              cacheWidth: (radius * 4).toInt().clamp(48, 500),
              cacheHeight: (radius * 4).toInt().clamp(48, 500),
              errorBuilder: (ctx, err, st) => _fallbackInitials(bgColor),
            ),
          );
        }
      } catch (_) {}
      // If base64 decoding failed or invalid image bytes, return fallback immediately
      if (!cleanAvatar.startsWith('http://') &&
          !cleanAvatar.startsWith('https://') &&
          !cleanAvatar.startsWith('/') &&
          !cleanAvatar.startsWith('uploads')) {
        return _fallbackInitials(bgColor);
      }
    }

    // 2. Local File Path
    if (cleanAvatar.startsWith('file://') ||
        cleanAvatar.contains(':\\') ||
        cleanAvatar.startsWith('/data/') ||
        cleanAvatar.startsWith('/storage/')) {
      try {
        final filePath = cleanAvatar.replaceFirst('file://', '');
        final file = File(filePath);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: targetSize,
              height: targetSize,
              fit: BoxFit.cover,
              cacheWidth: (radius * 4).toInt().clamp(48, 500),
              cacheHeight: (radius * 4).toInt().clamp(48, 500),
              errorBuilder: (ctx, err, st) => _fallbackInitials(bgColor),
            ),
          );
        }
      } catch (_) {}
      return _fallbackInitials(bgColor);
    }

    // 3. Direct HTTP/HTTPS Network URL
    if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
      final uri = Uri.tryParse(cleanAvatar);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.host.length > 120) {
        return _fallbackInitials(bgColor);
      }
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: cleanAvatar,
          httpHeaders: _networkHeaders,
          width: targetSize,
          height: targetSize,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE0E7FF),
            child: SizedBox(
              width: radius * 0.8,
              height: radius * 0.8,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => _fallbackInitials(bgColor),
        ),
      );
    }

    // 4. Relative Server Path (e.g. /uploads/..., uploads/...)
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
        return _fallbackInitials(bgColor);
      }
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          httpHeaders: _networkHeaders,
          width: targetSize,
          height: targetSize,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE0E7FF),
            child: SizedBox(
              width: radius * 0.8,
              height: radius * 0.8,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => _fallbackInitials(bgColor),
        ),
      );
    }

    // 5. Fallback Initial Letter
    return _fallbackInitials(bgColor);
  }

  Widget _fallbackInitials(Color bgColor) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        fallbackText.trim().isNotEmpty ? fallbackText.trim()[0].toUpperCase() : 'U',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
