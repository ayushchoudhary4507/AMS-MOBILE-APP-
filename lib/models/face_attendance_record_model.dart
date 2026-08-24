import 'package:intl/intl.dart';

/// Model representing a Face Lock Attendance verification record with captured face photo.
class FaceAttendanceRecord {
  final String id;
  final String userId;
  final String userName;
  final String email;
  final DateTime timestamp;
  final String? faceImageBase64;
  final String? registeredFaceImageBase64;
  final double similarityScore;
  final String status;
  final String verificationMethod;
  final double? latitude;
  final double? longitude;
  final String? notes;

  const FaceAttendanceRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.timestamp,
    this.faceImageBase64,
    this.registeredFaceImageBase64,
    this.similarityScore = 1.0,
    this.status = 'present',
    this.verificationMethod = 'Face Lock Biometric',
    this.latitude,
    this.longitude,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'email': email,
      'timestamp': timestamp.toIso8601String(),
      'faceImageBase64': faceImageBase64,
      'registeredFaceImageBase64': registeredFaceImageBase64,
      'similarityScore': similarityScore,
      'status': status,
      'verificationMethod': verificationMethod,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
    };
  }

  factory FaceAttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    if (json['timestamp'] != null) {
      try {
        ts = DateTime.parse(json['timestamp'].toString());
      } catch (_) {}
    }

    double sim = 1.0;
    if (json['similarityScore'] != null) {
      sim = (json['similarityScore'] as num).toDouble();
    }

    double? lat;
    if (json['latitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
    }

    double? lng;
    if (json['longitude'] != null) {
      lng = (json['longitude'] as num).toDouble();
    }

    return FaceAttendanceRecord(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Employee',
      email: json['email']?.toString() ?? '',
      timestamp: ts,
      faceImageBase64: json['faceImageBase64']?.toString(),
      registeredFaceImageBase64: json['registeredFaceImageBase64']?.toString(),
      similarityScore: sim,
      status: json['status']?.toString() ?? 'present',
      verificationMethod: json['verificationMethod']?.toString() ?? 'Face Lock Biometric',
      latitude: lat,
      longitude: lng,
      notes: json['notes']?.toString(),
    );
  }

  /// Formatted time e.g., "09:30 AM"
  String get formattedTime {
    try {
      return DateFormat('hh:mm a').format(timestamp.toLocal());
    } catch (_) {
      return '--:--';
    }
  }

  /// Formatted date e.g., "20 Aug 2026"
  String get formattedDate {
    try {
      return DateFormat('dd MMM yyyy').format(timestamp.toLocal());
    } catch (_) {
      return '';
    }
  }

  /// Formatted full date & time e.g., "20 Aug 2026, 09:30 AM"
  String get formattedDateTime {
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toLocal());
    } catch (_) {
      return '';
    }
  }

  /// Biometric match percentage e.g. "98.5%"
  String get similarityPercent {
    if (similarityScore <= 0) return 'Verified ✓';
    final pct = (similarityScore * 100).clamp(0.0, 100.0);
    return '${pct.toStringAsFixed(1)}% Match';
  }

  /// Whether attendance was marked today
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }
}
