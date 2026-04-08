import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps for a vet clinic.
///
/// **1. [googlePlaceId]** — Uses official `query_place_id` so Maps opens the same
/// business page as regular Google Maps (reviews, hours, photos, Q&A, etc.).
///
/// **2. Otherwise** — Text search `name, address`, labeled coordinate pin, etc.
///
/// See: https://developers.google.com/maps/documentation/urls/get-started#search-action
Future<bool> openCommunityVetClinicInGoogleMaps({
  required String displayName,
  String? address,
  String? googlePlaceId,
  double? latitude,
  double? longitude,
}) async {
  final placeId = googlePlaceId?.trim();
  final name = displayName.trim();
  final addr = address?.trim();
  final lat = latitude;
  final lng = longitude;
  final hasCoords =
      lat != null && lng != null && lat.isFinite && lng.isFinite;

  final Uri uri;
  if (placeId != null && placeId.isNotEmpty) {
    // Canonical place: full Maps detail (reviews, photos, hours, …).
    final q = name.isNotEmpty
        ? Uri.encodeComponent(name)
        : Uri.encodeComponent('Veterinary clinic');
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$q&query_place_id=${Uri.encodeComponent(placeId)}',
    );
  } else if (addr != null && addr.isNotEmpty) {
    final q = name.isNotEmpty ? '$name, $addr' : addr;
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
    );
  } else if (hasCoords && name.isNotEmpty) {
    final safeName = name.replaceAll('(', ' ').replaceAll(')', ' ');
    uri = Uri.parse(
      'https://www.google.com/maps?q=$lat,$lng(${Uri.encodeComponent(safeName)})',
    );
  } else if (hasCoords) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$lat,$lng')}',
    );
  } else if (name.isNotEmpty) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}',
    );
  } else {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
