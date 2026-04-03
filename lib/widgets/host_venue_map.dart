import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_platform.dart';
import '../config/theme.dart';
import '../services/approximate_location.dart';
import '../services/mock_data.dart';
import 'map_unavailable_placeholder.dart';

/// Preview of what guests see before accepting: a fuzzy point near the
/// neighborhood, not the street address you type in the form.
class HostVenueMap extends StatelessWidget {
  const HostVenueMap({
    super.key,
    this.height = 200,
    this.anchorLatitude,
    this.anchorLongitude,
  });

  final double height;
  final double? anchorLatitude;
  final double? anchorLongitude;

  @override
  Widget build(BuildContext context) {
    if (!mapsPlatformSupported) {
      return MapUnavailablePlaceholder(height: height);
    }

    final anchorLat =
        anchorLatitude ?? MockData.currentUser.latitude!;
    final anchorLng =
        anchorLongitude ?? MockData.currentUser.longitude!;
    final venue = fuzzyPublicLocation(
      anchorLat: anchorLat,
      anchorLng: anchorLng,
      stableKey: 'pawparty:host_venue_preview',
    );
    final target = LatLng(venue.latitude, venue.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 14.5),
          markers: {
            Marker(
              markerId: const MarkerId('venue_approx'),
              position: target,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
              infoWindow: const InfoWindow(
                title: 'Approximate party area',
                snippet: 'Full address shared after invite is accepted',
              ),
            ),
          },
          circles: {
            Circle(
              circleId: const CircleId('venue_uncertainty'),
              center: target,
              radius: 650,
              fillColor: PawPartyColors.secondary.withValues(alpha: 0.12),
              strokeColor: PawPartyColors.secondary.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}
