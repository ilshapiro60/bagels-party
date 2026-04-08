import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_platform.dart';
import '../config/theme.dart';
import '../services/approximate_location.dart';
import 'expandable_map_frame.dart';
import 'map_unavailable_placeholder.dart';

/// Preview of what guests see before accepting: a fuzzy point near the
/// neighborhood, not the street address you type in the form.
class HostVenueMap extends StatelessWidget {
  const HostVenueMap({
    super.key,
    this.height = 200,
    this.anchorLatitude,
    this.anchorLongitude,
    this.expandable = true,
    this.fullscreenTitle = 'Party area',
  });

  final double height;
  final double? anchorLatitude;
  final double? anchorLongitude;
  final bool expandable;
  final String fullscreenTitle;

  @override
  Widget build(BuildContext context) {
    if (!mapsPlatformSupported) {
      return MapUnavailablePlaceholder(height: height);
    }

    final anchorLat = anchorLatitude ?? kFallbackMapLat;
    final anchorLng = anchorLongitude ?? kFallbackMapLng;
    final venue = fuzzyPublicLocation(
      anchorLat: anchorLat,
      anchorLng: anchorLng,
      stableKey: 'pawparty:host_venue_preview',
    );
    final target = LatLng(venue.latitude, venue.longitude);

    Widget mapFor(double? maxHeight) {
      final fullscreen = maxHeight == null;
      final map = GoogleMap(
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
        zoomControlsEnabled: fullscreen,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: fullscreen,
      );
      if (maxHeight != null) {
        return SizedBox(height: maxHeight, width: double.infinity, child: map);
      }
      return map;
    }

    return ExpandableMapFrame(
      collapsedHeight: height,
      fullscreenTitle: fullscreenTitle,
      expandable: expandable,
      mapBuilder: (context, maxHeight) => mapFor(maxHeight),
    );
  }
}
