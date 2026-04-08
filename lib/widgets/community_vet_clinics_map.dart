import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_platform.dart';
import '../config/theme.dart';
import '../models/community_vet_clinic.dart';
import '../services/approximate_location.dart';
import '../utils/safe_map_geometry.dart';
import 'expandable_map_frame.dart';
import 'map_unavailable_placeholder.dart';

/// Map of community vet clinics (geocoded positions) plus optional viewer circle.
class CommunityVetClinicsMap extends StatefulWidget {
  const CommunityVetClinicsMap({
    super.key,
    required this.clinics,
    required this.viewerPoint,
    required this.radiusMiles,
    this.height = 220,
    this.showViewerLocation = true,
    this.onClinicMarkerTapped,
    this.expandable = true,
    this.fullscreenTitle = 'Vet clinics',
  });

  final List<CommunityVetClinic> clinics;
  final GeoPoint viewerPoint;
  final double radiusMiles;
  final bool showViewerLocation;
  final double height;
  final ValueChanged<CommunityVetClinic>? onClinicMarkerTapped;
  final bool expandable;
  final String fullscreenTitle;

  @override
  State<CommunityVetClinicsMap> createState() => _CommunityVetClinicsMapState();
}

class _CommunityVetClinicsMapState extends State<CommunityVetClinicsMap> {
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

    var index = 0;
    for (final c in widget.clinics) {
      final lat = c.latitude;
      final lng = c.longitude;
      if (lat == null || lng == null) continue;
      final pos = safeMapLatLng(lat, lng);
      final owners = c.linkedOwnerCount;
      final pets = c.linkCount;
      final neighborLabel =
          owners == 1 ? '1 neighbor' : '$owners neighbors';
      final petLabel = pets == 1 ? '1 pet' : '$pets pets';
      markers.add(
        Marker(
          markerId: MarkerId('vet_${c.dedupeKey.hashCode}_$index'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: c.displayName,
            snippet: '$neighborLabel · $petLabel linked',
          ),
          onTap: () => widget.onClinicMarkerTapped?.call(c),
        ),
      );
      index++;
    }
    return markers;
  }

  Set<Circle> _buildCircles() {
    if (!widget.showViewerLocation) return {};
    final you = safeMapLatLngFromGeo(widget.viewerPoint);
    return {
      Circle(
        circleId: const CircleId('vet_search_radius'),
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
      onMapCreated: fullscreen ? null : (c) => _controller = c,
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
