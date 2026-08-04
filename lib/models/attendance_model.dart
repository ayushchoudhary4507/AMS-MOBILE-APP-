import 'package:intl/intl.dart';

class AttendanceModel {
  final String? id;
  final String? employeeId;
  final String? userId;
  final DateTime? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final double workingHours;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceModel({
    this.id,
    this.employeeId,
    this.userId,
    this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'absent',
    this.workingHours = 0.0,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Safely parses DateTime from String, num, or DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        // Try parsing time formats like "09:30 AM" or "09:30"
        try {
          final now = DateTime.now();
          if (value.contains(':')) {
            final parts = value.trim().split(' ');
            final timeParts = parts[0].split(':');
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);
            if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
              hour += 12;
            } else if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hour == 12) {
              hour = 0;
            }
            return DateTime(now.year, now.month, now.day, hour, minute);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Safely parses double from dynamic (num, String, etc.)
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    // ID mapping
    final id = (json['_id'] ?? json['id'])?.toString();

    // Employee & User ID mapping
    String? empId = (json['employeeId'] ?? json['employee_id'] ?? json['employee'])?.toString();
    if (json['employee'] is Map) {
      empId ??= (json['employee']['_id'] ?? json['employee']['id'])?.toString();
    }
    
    String? usrId = (json['userId'] ?? json['user_id'] ?? json['user'])?.toString();
    if (json['user'] is Map) {
      usrId ??= (json['user']['_id'] ?? json['user']['id'])?.toString();
    }

    // Date mapping
    final date = _parseDateTime(
      json['date'] ?? json['attendanceDate'] ?? json['created_at'] ?? json['createdAt'],
    );

    // CheckIn mapping
    final checkIn = _parseDateTime(
      json['checkIn'] ??
          json['check_in'] ??
          json['checkInTime'] ??
          json['inTime'] ??
          json['in_time'],
    );

    // CheckOut mapping
    final checkOut = _parseDateTime(
      json['checkOut'] ??
          json['check_out'] ??
          json['checkOutTime'] ??
          json['outTime'] ??
          json['out_time'],
    );

    // Status mapping
    final rawStatus = (json['status'] ?? json['attendanceStatus'] ?? '').toString().toLowerCase();
    String status = 'absent';
    if (rawStatus.contains('present') || rawStatus == 'done' || checkIn != null) {
      status = 'present';
    } else if (rawStatus.contains('half') || rawStatus.contains('half-day') || rawStatus == 'half_day') {
      status = 'half-day';
    } else if (rawStatus.contains('leave') || rawStatus == 'on-leave') {
      status = 'leave';
    } else if (rawStatus.contains('late')) {
      status = 'late';
    } else if (rawStatus.isNotEmpty) {
      status = rawStatus;
    }

    // Working Hours mapping
    final workingHours = _parseDouble(
      json['workingHours'] ??
          json['working_hours'] ??
          json['workHours'] ??
          json['totalHours'] ??
          json['total_hours'],
    );

    // Notes
    final notes = json['notes']?.toString() ?? json['remark']?.toString();

    // Timestamps
    final createdAt = _parseDateTime(json['createdAt'] ?? json['created_at']);
    final updatedAt = _parseDateTime(json['updatedAt'] ?? json['updated_at']);

    return AttendanceModel(
      id: id,
      employeeId: empId,
      userId: usrId,
      date: date,
      checkIn: checkIn,
      checkOut: checkOut,
      status: status,
      workingHours: workingHours,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (employeeId != null) 'employeeId': employeeId,
      if (userId != null) 'userId': userId,
      if (date != null) 'date': date!.toIso8601String(),
      if (checkIn != null) 'checkIn': checkIn!.toIso8601String(),
      if (checkOut != null) 'checkOut': checkOut!.toIso8601String(),
      'status': status,
      'workingHours': workingHours,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  // --- Helper Getters ---

  /// Returns true if checked in (checkIn timestamp is present)
  bool get isCheckedIn => checkIn != null || status == 'present' || status == 'late' || status == 'half-day';

  /// Returns true if checked out (checkOut timestamp is present)
  bool get isCheckedOut => checkOut != null;

  /// Formatted check-in time e.g., "09:30 AM" or "--:-- --"
  String get formattedCheckInTime {
    if (checkIn == null) return '--:-- --';
    try {
      return DateFormat('hh:mm a').format(checkIn!.toLocal());
    } catch (_) {
      return '--:-- --';
    }
  }

  /// Formatted check-out time e.g., "06:00 PM" or "--:-- --"
  String get formattedCheckOutTime {
    if (checkOut == null) return '--:-- --';
    try {
      return DateFormat('hh:mm a').format(checkOut!.toLocal());
    } catch (_) {
      return '--:-- --';
    }
  }

  /// Formatted working hours e.g., "8.5 hrs" or "0.0 hrs"
  String get formattedWorkingHours {
    if (workingHours > 0) {
      return '${workingHours.toStringAsFixed(1)} hrs';
    }
    if (checkIn != null && checkOut != null) {
      final diff = checkOut!.difference(checkIn!).inMinutes / 60.0;
      if (diff > 0) return '${diff.toStringAsFixed(1)} hrs';
    }
    if (checkIn != null && checkOut == null) {
      final diff = DateTime.now().difference(checkIn!).inMinutes / 60.0;
      if (diff > 0) return '${diff.toStringAsFixed(1)} hrs';
    }
    return '0.0 hrs';
  }

  /// Display text for status badge
  String get displayStatus {
    if (isCheckedOut) return 'Done ✓';
    if (isCheckedIn) return 'Checked In';
    return 'Not Marked';
  }
}
