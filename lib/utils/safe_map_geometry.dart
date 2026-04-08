import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/approximate_location.dart';

/// Google Maps native SDK can throw (NSException / abort) on NaN, Infinity, or
/// out-of-range coordinates. All map cameras, markers, and circles should use these.
LatLng safeMapLatLng(double latitude, double longitude) {
  if (!latitude.isFinite || !longitude.isFinite) {
    return const LatLng(kFallbackMapLat, kFallbackMapLng);
  }
  return LatLng(
    latitude.clamp(-85.0, 85.0),
    longitude.clamp(-180.0, 180.0),
  );
}

LatLng safeMapLatLngFromGeo(GeoPoint p) =>
    safeMapLatLng(p.latitude, p.longitude);

double safeMapZoom(double zoom) {
  if (!zoom.isFinite) return 12.0;
  return zoom.clamp(2.0, 21.0);
}

/// Circle radius in meters — must be finite and positive for the native SDK.
double safeCircleRadiusMeters(double meters) {
  if (!meters.isFinite || meters <= 0) return 100.0;
  return meters.clamp(1.0, 10_000_000.0);
}
