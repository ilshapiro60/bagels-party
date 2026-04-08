import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A veterinary clinic row from Places Nearby Search (New), suitable for [Pet] vet fields.
class VetPlaceSelection {
  const VetPlaceSelection({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

const _channel = MethodChannel('com.pawparty.paw_party/places');

/// Nearby veterinary clinics via the native Places SDK (Android / iOS).
///
/// The native side uses the same API key already configured for Maps
/// (`com.google.android.geo.API_KEY` on Android, `GMSApiKey` in Info.plist
/// on iOS). No separate `--dart-define` is required.
Future<List<VetPlaceSelection>> searchNearbyVeterinaryCare({
  required double latitude,
  required double longitude,
  double radiusMeters = 8000,
  int maxResultCount = 20,
}) async {
  try {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'searchNearbyVeterinaryCare',
      {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters.clamp(1.0, 50000.0),
        'maxResultCount': maxResultCount.clamp(1, 20),
      },
    );
    if (result == null) return [];

    return result
        .whereType<Map>()
        .map((m) {
          final placeId = m['placeId'] as String? ?? '';
          final name = m['name'] as String? ?? '';
          if (placeId.isEmpty || name.isEmpty) return null;
          return VetPlaceSelection(
            placeId: placeId,
            name: name,
            address: m['address'] as String? ?? '',
            latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
          );
        })
        .whereType<VetPlaceSelection>()
        .toList();
  } on PlatformException catch (e) {
    debugPrint('google_places_vet_service: ${e.code} ${e.message}');
    throw GooglePlacesVetException(
      e.message ?? 'Native Places search failed.',
    );
  }
}

class GooglePlacesVetException implements Exception {
  GooglePlacesVetException(this.message);

  final String message;

  @override
  String toString() => message;
}
