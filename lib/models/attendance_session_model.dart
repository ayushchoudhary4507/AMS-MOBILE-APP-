import 'dart:convert';

class AttendanceSessionModel {
  final String sessionId;
  final String token;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int durationMinutes;
  final int scannedCount;
  final List<Map<String, dynamic>> scannedEmployees;
  final String? office;

  AttendanceSessionModel({
    required this.sessionId,
    required this.token,
    this.status = 'ACTIVE',
    required this.createdAt,
    required this.expiresAt,
    this.durationMinutes = 10,
    this.scannedCount = 0,
    this.scannedEmployees = const [],
    this.office,
  });

  bool get isActive {
    if (status.toUpperCase() != 'ACTIVE') return false;
    return DateTime.now().isBefore(expiresAt);
  }

  bool get isExpired {
    if (status.toUpperCase() == 'EXPIRED' || status.toUpperCase() == 'STOPPED') {
      return true;
    }
    return DateTime.now().isAfter(expiresAt);
  }

  Duration get remainingDuration {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get formattedRemainingTime {
    final rem = remainingDuration;
    if (rem.inHours >= 1) {
      final hours = rem.inHours;
      final minutes = rem.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${hours}h ${minutes}m';
    }
    final minutes = rem.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = rem.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }

  String get qrPayloadJson {
    return jsonEncode({
      'sessionId': sessionId,
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
      'type': 'AMS_ATTENDANCE_QR',
      'date': formattedDate,
      'generatedAt': createdAt.toIso8601String(),
    });
  }

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final sId = (json['sessionId'] ??
            json['id'] ??
            json['_id'] ??
            'ATT-SESSION-${now.millisecondsSinceEpoch}')
        .toString();

    final tok = (json['token'] ??
            json['qrToken'] ??
            json['attendanceToken'] ??
            'ams-sec-${now.millisecondsSinceEpoch}')
        .toString();

    final stat = (json['status'] ?? 'ACTIVE').toString().toUpperCase();

    DateTime parsedCreated = now;
    if (json['createdAt'] != null) {
      try {
        parsedCreated = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    int duration = 10;
    if (json['durationMinutes'] != null) {
      duration = int.tryParse(json['durationMinutes'].toString()) ?? 10;
    } else if (json['duration'] != null) {
      duration = int.tryParse(json['duration'].toString()) ?? 10;
    }

    DateTime parsedExpires = parsedCreated.add(Duration(minutes: duration));
    if (json['expiresAt'] != null) {
      try {
        parsedExpires = DateTime.parse(json['expiresAt'].toString());
      } catch (_) {}
    }

    final rawEmployees = json['scannedEmployees'] ??
        json['employees'] ??
        json['records'] ??
        json['scannedList'] ??
        [];

    final List<Map<String, dynamic>> employees = [];
    if (rawEmployees is List) {
      for (final e in rawEmployees) {
        if (e is Map) {
          employees.add(Map<String, dynamic>.from(e));
        }
      }
    }

    final count = json['scannedCount'] != null
        ? (int.tryParse(json['scannedCount'].toString()) ?? employees.length)
        : employees.length;

    return AttendanceSessionModel(
      sessionId: sId,
      token: tok,
      status: stat,
      createdAt: parsedCreated,
      expiresAt: parsedExpires,
      durationMinutes: duration,
      scannedCount: count,
      scannedEmployees: employees,
      office: json['office']?.toString() ?? json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'token': token,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'scannedCount': scannedCount,
      'scannedEmployees': scannedEmployees,
      if (office != null) 'office': office,
    };
  }

  AttendanceSessionModel copyWith({
    String? sessionId,
    String? token,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? durationMinutes,
    int? scannedCount,
    List<Map<String, dynamic>>? scannedEmployees,
    String? office,
  }) {
    return AttendanceSessionModel(
      sessionId: sessionId ?? this.sessionId,
      token: token ?? this.token,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      scannedCount: scannedCount ?? this.scannedCount,
      scannedEmployees: scannedEmployees ?? this.scannedEmployees,
      office: office ?? this.office,
    );
  }
}
