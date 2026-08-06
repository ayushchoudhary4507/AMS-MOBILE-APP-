import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';

class AppAvatar extends StatelessWidget {
  final dynamic avatarOrUser;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    required this.avatarOrUser,
    this.fallbackText = 'U',
    this.radius = 20,
    this.backgroundColor,
  });

  static const Map<String, String> _networkHeaders = {
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  @override
  Widget build(BuildContext context) {
    String? cleanAvatar = extractAvatarUrl(avatarOrUser);
    final bgColor = backgroundColor ?? const Color(0xFF4F46E5);

    if (cleanAvatar != null &&
        cleanAvatar.isNotEmpty &&
        cleanAvatar != 'null' &&
        cleanAvatar != 'undefined') {
      // Clean escaped slashes and protocol-relative URLs
      cleanAvatar = cleanAvatar.trim().replaceAll(r'\/', '/').replaceAll(r'\', '/');
      if (cleanAvatar.startsWith('//')) {
        cleanAvatar = 'https:$cleanAvatar';
      }

      // 1. Base64 Data URI or Raw Base64 String
      if (cleanAvatar.startsWith('data:image/') ||
          cleanAvatar.startsWith('data:application/') ||
          (!cleanAvatar.startsWith('http://') &&
              !cleanAvatar.startsWith('https://') &&
              !cleanAvatar.startsWith('file://') &&
              !cleanAvatar.startsWith('/') &&
              !cleanAvatar.startsWith('uploads') &&
              cleanAvatar.length > 80)) {
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
              backgroundColor: const Color(0xFFE0E7FF),
              backgroundImage: MemoryImage(bytes),
            );
          }
        } catch (_) {}
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
            return CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFFE0E7FF),
              backgroundImage: FileImage(file),
            );
          }
        } catch (_) {}
      }

      // 3. Normalize Localhost / IP to Backend Server Domain
      if (cleanAvatar.contains('localhost') ||
          cleanAvatar.contains('127.0.0.1') ||
          cleanAvatar.contains('10.0.2.2')) {
        final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        cleanAvatar = cleanAvatar.replaceAll(
          RegExp(r'https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?'),
          apiBase,
        );
      }

      // 4. Prepend https:// for Vercel, Cloudinary, S3, Supabase, Render, etc. if scheme missing
      if (!cleanAvatar.startsWith('http://') &&
          !cleanAvatar.startsWith('https://') &&
          (cleanAvatar.contains('vercel') ||
              cleanAvatar.contains('cloudinary') ||
              cleanAvatar.contains('render') ||
              cleanAvatar.contains('amazonaws') ||
              cleanAvatar.contains('googleapis') ||
              cleanAvatar.contains('supabase') ||
              cleanAvatar.contains('.com') ||
              cleanAvatar.contains('.app') ||
              cleanAvatar.contains('.dev') ||
              cleanAvatar.contains('.net') ||
              cleanAvatar.contains('.io') ||
              cleanAvatar.contains('.org'))) {
        cleanAvatar = 'https://$cleanAvatar';
      }

      // 5. Direct HTTP/HTTPS Network URL (Vercel CDN / Remote Host)
      if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
        final targetUrl = cleanAvatar;
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: targetUrl,
            httpHeaders: _networkHeaders,
            width: radius * 2,
            height: radius * 2,
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
            errorWidget: (context, url, error) {
              return Image.network(
                targetUrl,
                headers: _networkHeaders,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => _fallbackInitials(bgColor),
              );
            },
          ),
        );
      }

      // 6. Relative Server Path (e.g. /uploads/..., uploads/..., storage/..., _next/..., etc.)
      if (cleanAvatar.startsWith('/') ||
          cleanAvatar.startsWith('uploads') ||
          cleanAvatar.startsWith('public') ||
          cleanAvatar.startsWith('storage') ||
          cleanAvatar.startsWith('images') ||
          cleanAvatar.startsWith('assets') ||
          cleanAvatar.startsWith('photos') ||
          cleanAvatar.startsWith('profiles') ||
          cleanAvatar.contains('.png') ||
          cleanAvatar.contains('.jpg') ||
          cleanAvatar.contains('.jpeg') ||
          cleanAvatar.contains('.webp') ||
          cleanAvatar.contains('.svg') ||
          cleanAvatar.contains('.gif') ||
          (!cleanAvatar.contains(' ') && cleanAvatar.contains('.'))) {
        final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        final fullUrl = '$apiBase${cleanAvatar.startsWith('/') ? '' : '/'}$cleanAvatar';
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            httpHeaders: _networkHeaders,
            width: radius * 2,
            height: radius * 2,
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
            errorWidget: (context, url, error) {
              return Image.network(
                fullUrl,
                headers: _networkHeaders,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => _fallbackInitials(bgColor),
              );
            },
          ),
        );
      }
    }

    // 7. Fallback Initial Letter
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
