/// Represents an enrolled biometric profile (Face or Fingerprint)
/// associated with a specific user account.
class FaceBiometricProfile {
  final String userId;
  final String userName;
  final String email;
  final String role;
  final String? token;
  final Map<String, dynamic> userData;
  final List<double> faceTemplate;
  final DateTime enrolledAt;
  final bool isFingerprintEnabled;
  final bool isFaceLockEnabled;

  const FaceBiometricProfile({
    required this.userId,
    required this.userName,
    required this.email,
    required this.role,
    this.token,
    required this.userData,
    required this.faceTemplate,
    required this.enrolledAt,
    this.isFingerprintEnabled = false,
    this.isFaceLockEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'email': email,
      'role': role,
      'token': token,
      'userData': userData,
      'faceTemplate': faceTemplate,
      'enrolledAt': enrolledAt.toIso8601String(),
      'isFingerprintEnabled': isFingerprintEnabled,
      'isFaceLockEnabled': isFaceLockEnabled,
    };
  }

  factory FaceBiometricProfile.fromJson(Map<String, dynamic> json) {
    List<double> template = [];
    if (json['faceTemplate'] is List) {
      template = (json['faceTemplate'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    Map<String, dynamic> user = {};
    if (json['userData'] is Map) {
      user = Map<String, dynamic>.from(json['userData']);
    }

    DateTime enrolledDate = DateTime.now();
    if (json['enrolledAt'] != null) {
      try {
        enrolledDate = DateTime.parse(json['enrolledAt'].toString());
      } catch (_) {}
    }

    return FaceBiometricProfile(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? user['name']?.toString() ?? 'User',
      email: json['email']?.toString() ?? user['email']?.toString() ?? '',
      role: json['role']?.toString() ?? user['role']?.toString() ?? 'employee',
      token: json['token']?.toString(),
      userData: user,
      faceTemplate: template,
      enrolledAt: enrolledDate,
      isFingerprintEnabled: json['isFingerprintEnabled'] == true,
      isFaceLockEnabled: json['isFaceLockEnabled'] == true,
    );
  }

  FaceBiometricProfile copyWith({
    String? userId,
    String? userName,
    String? email,
    String? role,
    String? token,
    Map<String, dynamic>? userData,
    List<double>? faceTemplate,
    DateTime? enrolledAt,
    bool? isFingerprintEnabled,
    bool? isFaceLockEnabled,
  }) {
    return FaceBiometricProfile(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
      userData: userData ?? this.userData,
      faceTemplate: faceTemplate ?? this.faceTemplate,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      isFingerprintEnabled: isFingerprintEnabled ?? this.isFingerprintEnabled,
      isFaceLockEnabled: isFaceLockEnabled ?? this.isFaceLockEnabled,
    );
  }
}

/// Result returned by multi-user 1:N face identification.
class FaceIdentificationResult {
  final bool isSuccess;
  final FaceBiometricProfile? matchedProfile;
  final double similarityScore;
  final String message;

  const FaceIdentificationResult({
    required this.isSuccess,
    this.matchedProfile,
    required this.similarityScore,
    required this.message,
  });

  factory FaceIdentificationResult.success({
    required FaceBiometricProfile profile,
    required double score,
  }) {
    return FaceIdentificationResult(
      isSuccess: true,
      matchedProfile: profile,
      similarityScore: score,
      message: 'Face verified successfully for ${profile.userName}.',
    );
  }

  factory FaceIdentificationResult.notRecognized({double score = 0.0}) {
    return FaceIdentificationResult(
      isSuccess: false,
      matchedProfile: null,
      similarityScore: score,
      message: 'Face does not match any registered account.',
    );
  }

  factory FaceIdentificationResult.noEnrolledProfiles() {
    return const FaceIdentificationResult(
      isSuccess: false,
      matchedProfile: null,
      similarityScore: 0.0,
      message: 'No registered face found. Please register your face first.',
    );
  }

  factory FaceIdentificationResult.faceNotDetected() {
    return const FaceIdentificationResult(
      isSuccess: false,
      matchedProfile: null,
      similarityScore: 0.0,
      message: 'Face not detected. Please position your face clearly in the camera.',
    );
  }
}
