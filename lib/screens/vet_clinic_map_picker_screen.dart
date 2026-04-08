import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_platform.dart';
import '../config/theme.dart';
import '../services/approximate_location.dart';
import '../services/device_location_service.dart';
import '../services/google_places_vet_service.dart';
import '../utils/safe_map_geometry.dart';

/// Fullscreen map: pan to refresh Nearby Search for [veterinary_care], pick one clinic.
class VetClinicMapPickerScreen extends StatefulWidget {
  const VetClinicMapPickerScreen({
    super.key,
    this.fallbackLatitude,
    this.fallbackLongitude,
  });

  /// Used when GPS is unavailable (e.g. profile coordinates).
  final double? fallbackLatitude;
  final double? fallbackLongitude;

  @override
  State<VetClinicMapPickerScreen> createState() =>
      _VetClinicMapPickerScreenState();
}

class _VetClinicMapPickerScreenState extends State<VetClinicMapPickerScreen> {
  GoogleMapController? _mapController;
  Timer? _debounce;

  late LatLng _mapCenter;
  List<VetPlaceSelection> _places = [];
  VetPlaceSelection? _selected;
  bool _loading = false;
  String? _errorMessage;

  static const _searchRadiusM = 8000.0;
  static const _initialZoom = 12.5;

  @override
  void initState() {
    super.initState();
    final lat = widget.fallbackLatitude;
    final lng = widget.fallbackLongitude;
    _mapCenter = lat != null && lng != null
        ? safeMapLatLng(lat, lng)
        : safeMapLatLng(kFallbackMapLat, kFallbackMapLng);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryGpsUpgrade();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _tryGpsUpgrade() async {
    final pos = await DeviceLocationService.tryGetCurrentPosition();
    if (!mounted || pos == null) return;
    final ll = safeMapLatLng(pos.latitude, pos.longitude);
    setState(() {
      _mapCenter = ll;
      _selected = null;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(ll, 13),
    );
    _runNearbySearch();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _runNearbySearch);
  }

  Future<void> _runNearbySearch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final list = await searchNearbyVeterinaryCare(
        latitude: _mapCenter.latitude,
        longitude: _mapCenter.longitude,
        radiusMeters: _searchRadiusM,
      );
      if (!mounted) return;
      final sel = _selected;
      VetPlaceSelection? newSel = sel;
      if (sel != null) {
        final still = list.where((p) => p.placeId == sel.placeId).toList();
        newSel = still.isEmpty ? null : still.first;
      }
      setState(() {
        _places = list;
        _selected = newSel;
        _loading = false;
      });
    } on GooglePlacesVetException catch (e) {
      if (!mounted) return;
      setState(() {
        _places = [];
        _selected = null;
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _places = [];
        _selected = null;
        _loading = false;
        _errorMessage = 'Could not load clinics. Check your connection.';
      });
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    for (final p in _places) {
      final pos = safeMapLatLng(p.latitude, p.longitude);
      final isSel = _selected?.placeId == p.placeId;
      markers.add(
        Marker(
          markerId: MarkerId(p.placeId),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSel ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          onTap: () => setState(() => _selected = p),
        ),
      );
    }
    return markers;
  }

  void _confirmSelection() {
    final s = _selected;
    if (s == null) return;
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final initial = _mapCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose vet clinic'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _runNearbySearch,
            child: const Text('Refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initial,
                    zoom: _initialZoom,
                  ),
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  markers: _markers(),
                  circles: {
                    Circle(
                      circleId: const CircleId('search_radius'),
                      center: _mapCenter,
                      radius: safeCircleRadiusMeters(_searchRadiusM),
                      fillColor: PawPartyColors.primary.withValues(alpha: 0.06),
                      strokeColor: PawPartyColors.primary.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  },
                  onMapCreated: (c) {
                    _mapController = c;
                    _runNearbySearch();
                  },
                  onCameraMove: (pos) => _mapCenter = pos.target,
                  onCameraIdle: _scheduleSearch,
                ),
                if (_loading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 12,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Searching this area…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 200,
            child: _places.isEmpty && !_loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _errorMessage != null
                            ? 'Fix the issue above, then tap Refresh or move the map.'
                            : 'No veterinary clinics in this area. Try zooming out or panning.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PawPartyColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _places.length,
                    itemBuilder: (context, i) {
                      final p = _places[i];
                      final sel = _selected?.placeId == p.placeId;
                      return ListTile(
                        selected: sel,
                        title: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: p.address.isEmpty
                            ? null
                            : Text(
                                p.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => setState(() => _selected = p),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _selected == null ? null : _confirmSelection,
                child: const Text('Use this clinic'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the picker on Android/iOS; shows a [SnackBar] on unsupported platforms.
Future<VetPlaceSelection?> openVetClinicMapPicker(
  BuildContext context, {
  double? fallbackLatitude,
  double? fallbackLongitude,
}) async {
  if (!vetClinicMapPickerSupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vet clinic map search is only available on mobile.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return null;
  }
  return Navigator.of(context).push<VetPlaceSelection>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VetClinicMapPickerScreen(
        fallbackLatitude: fallbackLatitude,
        fallbackLongitude: fallbackLongitude,
      ),
    ),
  );
}
