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

  @override
  Widget build(BuildContext context) {
    String? cleanAvatar = extractAvatarUrl(avatarOrUser);
    final bgColor = backgroundColor ?? const Color(0xFF4F46E5);

    if (cleanAvatar != null &&
        cleanAvatar.isNotEmpty &&
        cleanAvatar != 'null' &&
        cleanAvatar != 'undefined') {
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

      // 3. Direct HTTP/HTTPS Network URL
      if (cleanAvatar.contains('localhost') ||
          cleanAvatar.contains('127.0.0.1') ||
          cleanAvatar.contains('10.0.2.2')) {
        final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        cleanAvatar = cleanAvatar.replaceAll(
          RegExp(r'https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?'),
          apiBase,
        );
      }

      if (!cleanAvatar.startsWith('http://') &&
          !cleanAvatar.startsWith('https://') &&
          (cleanAvatar.contains('cloudinary.com') ||
              cleanAvatar.contains('vercel.app') ||
              cleanAvatar.contains('onrender.com') ||
              cleanAvatar.contains('amazonaws.com') ||
              cleanAvatar.contains('googleapis.com') ||
              cleanAvatar.contains('supabase.co'))) {
        cleanAvatar = 'https://$cleanAvatar';
      }

      if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: cleanAvatar,
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
            errorWidget: (context, url, error) => CircleAvatar(
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
            ),
          ),
        );
      }

      // 4. Relative Server Path (e.g. /uploads/..., uploads/..., storage/..., etc.)
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
          (!cleanAvatar.contains(' ') && cleanAvatar.contains('.'))) {
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
              backgroundColor: const Color(0xFFE0E7FF),
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => CircleAvatar(
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
            ),
          ),
        );
      }
    }

    // 5. Fallback Initial Letter
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
