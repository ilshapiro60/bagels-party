import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_platform.dart';
import '../config/theme.dart';
import '../models/pet.dart';
import '../models/user_profile.dart';
import '../services/approximate_location.dart';
import 'map_unavailable_placeholder.dart';

class NearbyPetsMap extends StatefulWidget {
  const NearbyPetsMap({
    super.key,
    required this.pets,
    required this.viewerPoint,
    required this.radiusMiles,
    this.viewerProfile,
    this.height = 220,
    this.onPetMarkerTapped,
    /// When false, no "You" marker or radius circle (user location unknown).
    this.showViewerLocation = true,
  });

  final List<Pet> pets;
  final GeoPoint viewerPoint;
  final UserProfile? viewerProfile;
  final double radiusMiles;
  final bool showViewerLocation;
  final double height;
  final ValueChanged<Pet>? onPetMarkerTapped;

  @override
  State<NearbyPetsMap> createState() => _NearbyPetsMapState();
}

class _NearbyPetsMapState extends State<NearbyPetsMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  double _zoomForRadius(double miles) {
    const minZ = 10.5;
    const maxZ = 15.2;
    return maxZ - (miles - 1) / 14 * (maxZ - minZ);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (widget.showViewerLocation) {
      final you = LatLng(
        widget.viewerPoint.latitude,
        widget.viewerPoint.longitude,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('you'),
          position: you,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: 'You (approximate)',
            snippet: 'Your general area on the map',
          ),
        ),
      );
    }

    for (final pet in widget.pets) {
      final pt = ownerApproximateArea(pet, viewer: widget.viewerProfile);
      final pos = LatLng(pt.latitude, pt.longitude);
      final hue = switch (pet.type) {
        'Dog' => BitmapDescriptor.hueOrange,
        'Cat' => BitmapDescriptor.hueViolet,
        _ => BitmapDescriptor.hueGreen,
      };
      markers.add(
        Marker(
          markerId: MarkerId(pet.id),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: pet.name,
            snippet: '${pet.breed ?? pet.type} · approximate area',
          ),
          onTap: () {
            widget.onPetMarkerTapped?.call(pet);
          },
        ),
      );
    }
    return markers;
  }

  Set<Circle> _buildCircles() {
    if (!widget.showViewerLocation) return {};
    final you = LatLng(widget.viewerPoint.latitude, widget.viewerPoint.longitude);
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: you,
        radius: widget.radiusMiles * 1609.34,
        fillColor: PawPartyColors.primary.withValues(alpha: 0.08),
        strokeColor: PawPartyColors.primary.withValues(alpha: 0.45),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!mapsPlatformSupported) {
      return MapUnavailablePlaceholder(height: widget.height);
    }

    final target = LatLng(
      widget.viewerPoint.latitude,
      widget.viewerPoint.longitude,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: target,
            zoom: _zoomForRadius(widget.radiusMiles),
          ),
          markers: _buildMarkers(),
          circles: _buildCircles(),
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          liteModeEnabled: false,
          onMapCreated: (c) => _controller = c,
        ),
      ),
    );
  }
}
