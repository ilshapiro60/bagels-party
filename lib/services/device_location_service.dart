import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Reads device GPS (with permission) and optional reverse-geocode for a short place label.
class DeviceLocationService {
  DeviceLocationService._();

  static Future<Position?> tryGetCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint('DeviceLocation: location services disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('DeviceLocation: permission denied');
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e, st) {
      debugPrint('DeviceLocation: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// City / locality label for profile header (best-effort).
  static Future<String?> placemarkNeighborhood(double latitude, double longitude) async {
    try {
      final list = await geo.placemarkFromCoordinates(latitude, longitude);
      if (list.isEmpty) return null;
      final p = list.first;
      final locality = p.locality;
      if (locality != null && locality.trim().isNotEmpty) return locality.trim();
      final sub = p.subAdministrativeArea;
      if (sub != null && sub.trim().isNotEmpty) return sub.trim();
      final admin = p.administrativeArea;
      if (admin != null && admin.trim().isNotEmpty) return admin.trim();
      return null;
    } catch (e) {
      debugPrint('DeviceLocation geocode: $e');
      return null;
    }
  }
}
