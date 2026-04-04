import 'dart:math' as math;

import '../models/pet.dart';
import '../models/user_profile.dart';

/// Neutral map anchor when there is no user location and no pets to center on
/// (geographic center of the contiguous US — not a real user position).
const double kFallbackMapLat = 39.8283;
const double kFallbackMapLng = -98.5795;

/// Public map points are intentionally offset from real coordinates so the
/// map shows an **approximate area**, not a precise home location.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

GeoPoint fuzzyPublicLocation({
  required double anchorLat,
  required double anchorLng,
  required String stableKey,
  double minJitterMeters = 280,
  double maxJitterMeters = 920,
}) {
  final h = stableKey.hashCode & 0x7FFFFFFF;
  final angle = (h % 6283) / 1000.0;
  final t = ((h ~/ 6283) % 1000) / 1000.0;
  final distM = minJitterMeters + t * (maxJitterMeters - minJitterMeters);
  final cosLat = math.cos(anchorLat * math.pi / 180);
  final dLat = (distM / 111320) * math.cos(angle);
  final dLng = cosLat.abs() < 1e-6
      ? 0.0
      : (distM / (111320 * cosLat)) * math.sin(angle);
  return GeoPoint(anchorLat + dLat, anchorLng + dLng);
}

double haversineMeters(GeoPoint a, GeoPoint b) {
  const earthM = 6371000.0;
  final p1 = a.latitude * math.pi / 180;
  final p2 = b.latitude * math.pi / 180;
  final dp = (b.latitude - a.latitude) * math.pi / 180;
  final dl = (b.longitude - a.longitude) * math.pi / 180;
  final x = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * earthM * math.asin(math.sqrt(x.clamp(0.0, 1.0)));
}

bool profileHasMapCoordinates(UserProfile? user) =>
    user != null &&
    user.latitude != null &&
    user.longitude != null;

GeoPoint viewerMapPoint(UserProfile? user) {
  final lat = user?.latitude ?? kFallbackMapLat;
  final lng = user?.longitude ?? kFallbackMapLng;
  final id = user?.id ?? 'guest';
  return fuzzyPublicLocation(
    anchorLat: lat,
    anchorLng: lng,
    stableKey: 'pawparty:viewer:$id',
  );
}

/// Discover map: fuzzy viewer position when GPS/profile coords exist; otherwise
/// centroid of [pets] so we never imply a random city is "you".
GeoPoint discoverMapAnchor(UserProfile? user, List<Pet> pets) {
  if (profileHasMapCoordinates(user)) {
    return viewerMapPoint(user);
  }
  if (pets.isNotEmpty) {
    var lat = 0.0;
    var lng = 0.0;
    for (final p in pets) {
      final g = ownerApproximateArea(p, viewer: user);
      lat += g.latitude;
      lng += g.longitude;
    }
    lat /= pets.length;
    lng /= pets.length;
    return GeoPoint(lat, lng);
  }
  return const GeoPoint(kFallbackMapLat, kFallbackMapLng);
}

GeoPoint ownerApproximateArea(Pet pet, {UserProfile? viewer}) {
  if (pet.ownerApproxLat != null && pet.ownerApproxLng != null) {
    return fuzzyPublicLocation(
      anchorLat: pet.ownerApproxLat!,
      anchorLng: pet.ownerApproxLng!,
      stableKey: 'pawparty:owner:${pet.ownerId}',
    );
  }
  final lat = viewer?.latitude ?? kFallbackMapLat;
  final lng = viewer?.longitude ?? kFallbackMapLng;
  return fuzzyPublicLocation(
    anchorLat: lat,
    anchorLng: lng,
    stableKey: 'pawparty:owner:${pet.ownerId}',
  );
}

/// Pets whose owner's approximate area falls within [radiusMiles] of the viewer.
List<Pet> petsWithinRadiusMiles(
  List<Pet> pets,
  UserProfile? viewer,
  double radiusMiles,
) {
  if (!profileHasMapCoordinates(viewer)) {
    return List<Pet>.from(pets);
  }
  final you = viewerMapPoint(viewer);
  final maxM = radiusMiles * 1609.34;
  return pets.where((p) {
    final them = ownerApproximateArea(p, viewer: viewer);
    return haversineMeters(you, them) <= maxM;
  }).toList();
}
