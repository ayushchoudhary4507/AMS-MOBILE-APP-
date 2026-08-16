import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final bool isSuccess;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool isServiceDisabled;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.isSuccess = true,
    this.errorMessage,
    this.isPermissionDenied = false,
    this.isServiceDisabled = false,
  });

  factory LocationResult.success(double lat, double lng) {
    return LocationResult(
      latitude: lat,
      longitude: lng,
      isSuccess: true,
    );
  }

  factory LocationResult.error(
    String message, {
    bool isPermissionDenied = false,
    bool isServiceDisabled = false,
  }) {
    return LocationResult(
      isSuccess: false,
      errorMessage: message,
      isPermissionDenied: isPermissionDenied,
      isServiceDisabled: isServiceDisabled,
    );
  }
}

class LocationService {
  /// Request permission and get current GPS location
  static Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // 1. Check if location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error(
          'Location services are disabled on your device. Please enable GPS in settings.',
          isServiceDisabled: true,
        );
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error(
            'Location permission was denied. Please grant location access to mark attendance.',
            isPermissionDenied: true,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
          'Location permissions are permanently denied. Please enable them in your device app settings.',
          isPermissionDenied: true,
        );
      }

      // 3. Acquire current GPS position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );
      } catch (e) {
        debugPrint('Geolocator.getCurrentPosition timeout or failed, trying last known position: $e');
        // Fallback to last known position if current times out
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        return LocationResult.success(position.latitude, position.longitude);
      } else {
        return LocationResult.error(
          'Unable to determine your GPS location. Please ensure you have GPS signal.',
        );
      }
    } catch (e) {
      debugPrint('LocationService exception: $e');
      return LocationResult.error(
        'Failed to fetch GPS location: ${e.toString()}',
      );
    }
  }

  /// Open device location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Open app permission settings
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
