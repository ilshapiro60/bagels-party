import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_platform.dart';
import '../config/theme.dart';
import '../models/pet.dart';
import '../models/user_profile.dart';
import '../services/approximate_location.dart';
import '../utils/safe_map_geometry.dart';
import 'expandable_map_frame.dart';
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
    this.expandable = true,
    this.fullscreenTitle = 'Nearby pets',
  });

  final List<Pet> pets;
  final GeoPoint viewerPoint;
  final UserProfile? viewerProfile;
  final double radiusMiles;
  final bool showViewerLocation;
  final double height;
  final ValueChanged<Pet>? onPetMarkerTapped;
  final bool expandable;
  final String fullscreenTitle;

  @override
  State<NearbyPetsMap> createState() => _NearbyPetsMapState();
}

class _NearbyPetsMapState extends State<NearbyPetsMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant NearbyPetsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerPoint.latitude != widget.viewerPoint.latitude ||
        oldWidget.viewerPoint.longitude != widget.viewerPoint.longitude ||
        oldWidget.radiusMiles != widget.radiusMiles) {
      _animateToCurrentPoint();
    }
  }

  void _animateToCurrentPoint() {
    final c = _controller;
    if (c == null) return;
    final target = safeMapLatLngFromGeo(widget.viewerPoint);
    c.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: target,
        zoom: safeMapZoom(_zoomForRadius(widget.radiusMiles)),
      ),
    ));
  }

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
      final you = safeMapLatLngFromGeo(widget.viewerPoint);
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
      final pos = safeMapLatLngFromGeo(pt);
      final hue = switch (pet.type) {
        'Dog' => BitmapDescriptor.hueOrange,
        'Cat' => BitmapDescriptor.hueViolet,
        _ => BitmapDescriptor.hueGreen,
      };
      markers.add(
        Marker(
          markerId: MarkerId(pet.id.isEmpty ? 'pet_unknown' : pet.id),
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
    final you = safeMapLatLngFromGeo(widget.viewerPoint);
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: you,
        radius: safeCircleRadiusMeters(widget.radiusMiles * 1609.34),
        fillColor: PawPartyColors.primary.withValues(alpha: 0.08),
        strokeColor: PawPartyColors.primary.withValues(alpha: 0.45),
        strokeWidth: 2,
      ),
    };
  }

  Widget _googleMap(double? maxHeight) {
    final target = safeMapLatLngFromGeo(widget.viewerPoint);
    final fullscreen = maxHeight == null;
    final map = GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: target,
        zoom: safeMapZoom(_zoomForRadius(widget.radiusMiles)),
      ),
      markers: _buildMarkers(),
      circles: _buildCircles(),
      zoomControlsEnabled: fullscreen,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: fullscreen,
      liteModeEnabled: false,
      onMapCreated: (c) {
        _controller = c;
      },
    );
    if (maxHeight != null) {
      return SizedBox(height: maxHeight, width: double.infinity, child: map);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (!mapsPlatformSupported) {
      return MapUnavailablePlaceholder(height: widget.height);
    }

    return ExpandableMapFrame(
      collapsedHeight: widget.height,
      fullscreenTitle: widget.fullscreenTitle,
      expandable: widget.expandable,
      mapBuilder: (context, maxHeight) => _googleMap(maxHeight),
    );
  }
}
