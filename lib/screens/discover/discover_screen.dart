import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/community_vet_clinic.dart';
import '../../models/meetup.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/approximate_location.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../utils/open_external_maps.dart';
import '../../utils/pet_compatibility.dart';
import '../../widgets/community_vet_clinics_map.dart';
import '../../widgets/nearby_pets_map.dart';
import '../../widgets/pet_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.initialTab = 0});

  /// 0 = Pets, 1 = Vets, 2 = Events
  final int initialTab;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  double _radiusMiles = 5.0;
  final ScrollController _listScroll = ScrollController();

  late final TabController _tabController;
  final TextEditingController _vetSearchController = TextEditingController();

  /// Custom location override (null = use profile GPS).
  double? _overrideLat;
  double? _overrideLng;
  String? _overrideLabel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vetSearchController.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  UserProfile? _effectiveUser(UserProfile? real) {
    if (_overrideLat == null || _overrideLng == null || real == null) return real;
    return real.copyWithCoordinates(
      latitude: _overrideLat!,
      longitude: _overrideLng!,
      neighborhood: _overrideLabel,
    );
  }

  String _locationLabel(UserProfile? user) {
    if (_overrideLabel != null) return _overrideLabel!;
    return user?.neighborhood ?? 'Your area';
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final locations = await geo.locationFromAddress(query.trim());
      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found for that address.')),
          );
        }
        return;
      }
      final loc = locations.first;
      setState(() {
        _overrideLat = loc.latitude;
        _overrideLng = loc.longitude;
        _overrideLabel = query.trim();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find location: $e')),
        );
      }
    }
  }

  void _resetToCurrentLocation() {
    setState(() {
      _overrideLat = null;
      _overrideLng = null;
      _overrideLabel = null;
    });
  }

  void _openPetProfileFromMap(Pet pet) {
    context.push('/pet/${pet.id}');
  }

  Future<void> _openVetClinicInGoogleMapsFromMarker(CommunityVetClinic c) async {
    final opened = await openCommunityVetClinicInGoogleMaps(
      displayName: c.displayName,
      address: c.address,
      googlePlaceId: c.googlePlaceId,
      latitude: c.latitude,
      longitude: c.longitude,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps. Try from the list below.'),
        ),
      );
      _showVetClinicDetailSheet(c);
    }
  }

  List<CommunityVetClinic> _vetClinicsMatchingSearch(
    List<CommunityVetClinic> clinics,
  ) {
    final q = _vetSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return clinics;
    return clinics.where((c) {
      final name = c.displayName.toLowerCase();
      final addr = (c.address ?? '').toLowerCase();
      return name.contains(q) || addr.contains(q);
    }).toList();
  }

  String? _vetClinicDistanceLabel(UserProfile? user, CommunityVetClinic c) {
    final ulat = user?.latitude;
    final ulng = user?.longitude;
    final plat = c.latitude;
    final plng = c.longitude;
    if (ulat == null || ulng == null || plat == null || plng == null) {
      return null;
    }
    final m = haversineMeters(
      GeoPoint(ulat, ulng),
      GeoPoint(plat, plng),
    );
    if (m < 1609) {
      return '${m.round()} m away';
    }
    final mi = m / 1609.34;
    return '${mi.toStringAsFixed(mi >= 10 ? 0 : 1)} mi away';
  }

  void _showVetClinicDetailSheet(CommunityVetClinic c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.displayName,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                if (c.address != null && c.address!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    c.address!,
                    style: TextStyle(
                      fontSize: 15,
                      color: PawPartyColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  '${c.linkedOwnerCount} neighbor${c.linkedOwnerCount == 1 ? '' : 's'} '
                  'on the app linked ${c.linkCount} pet${c.linkCount == 1 ? '' : 's'} here.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final opened = await openCommunityVetClinicInGoogleMaps(
                      displayName: c.displayName,
                      address: c.address,
                      googlePlaceId: c.googlePlaceId,
                      latitude: c.latitude,
                      longitude: c.longitude,
                    );
                    if (!opened && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open Google Maps.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open in Google Maps'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearbyPets = ref.watch(nearbyPetsProvider);
    final userPets = ref.watch(userPetsProvider);
    final authState = ref.watch(authStateProvider);
    final effectiveUser = _effectiveUser(authState.user);
    final primaryPet = userPets.isNotEmpty ? userPets.first : null;

    final typeFiltered = _selectedFilter == 'All'
        ? nearbyPets
        : nearbyPets.where((p) => p.type == _selectedFilter).toList();

    final visiblePets = petsWithinRadiusMiles(
      typeFiltered,
      effectiveUser,
      _radiusMiles,
    );

    final viewerPoint = discoverMapAnchor(effectiveUser, visiblePets);
    final showViewerOnMap = profileHasMapCoordinates(effectiveUser);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pets_outlined), text: 'Pets'),
            Tab(icon: Icon(Icons.local_hospital_outlined), text: 'Vets'),
            Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh my location',
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              _resetToCurrentLocation();
              final ok =
                  await ref.read(authStateProvider.notifier).syncDeviceLocation();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Location updated — map uses your area.'
                        : 'Could not get location. Turn on GPS and allow location access.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationBar(authState.user),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                switch (_tabController.index) {
                  case 0:
                    return _buildPetsDiscoverTab(
                      visiblePets: visiblePets,
                      viewerPoint: viewerPoint,
                      viewerProfile: effectiveUser,
                      showViewerOnMap: showViewerOnMap,
                      primaryPet: primaryPet,
                    );
                  case 1:
                    return _buildVetClinicsTab(effectiveUser, showViewerOnMap);
                  case 2:
                    return _buildEventsTab(effectiveUser);
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBar(UserProfile? user) {
    final label = _locationLabel(user);
    final isOverride = _overrideLabel != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: PawPartyColors.surface,
      child: Row(
        children: [
          Icon(
            isOverride ? Icons.search : Icons.location_on,
            size: 18,
            color: isOverride ? PawPartyColors.secondary : PawPartyColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _showLocationSearchDialog(),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PawPartyColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isOverride)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: PawPartyColors.textHint),
              tooltip: 'Back to my location',
              onPressed: _resetToCurrentLocation,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: Icon(Icons.edit_location_alt_outlined,
                size: 18, color: PawPartyColors.textSecondary),
            tooltip: 'Search another location',
            onPressed: () => _showLocationSearchDialog(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _showLocationSearchDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Address, city, or zip code',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            _searchLocation(v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _searchLocation(controller.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsDiscoverTab({
    required List<Pet> visiblePets,
    required GeoPoint viewerPoint,
    required UserProfile? viewerProfile,
    required bool showViewerOnMap,
    required Pet? primaryPet,
  }) {
    return ListView.builder(
      key: ValueKey('pets_${_overrideLat}_${_overrideLng}_$_selectedFilter'),
      controller: _listScroll,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: visiblePets.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBar(),
              _buildFilters(),
              _buildRadiusSlider(showViewerOnMap),
              _buildMapPrivacyBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: NearbyPetsMap(
                  pets: visiblePets,
                  viewerPoint: viewerPoint,
                  viewerProfile: viewerProfile,
                  radiusMiles: _radiusMiles,
                  showViewerLocation: showViewerOnMap,
                  onPetMarkerTapped: _openPetProfileFromMap,
                ),
              ),
            ],
          );
        }
        final petIndex = index - 1;
        final pet = visiblePets[petIndex];
        final compatibility = primaryPet != null
            ? calculatePetCompatibility(primaryPet, pet)
            : 0.0;
        return Padding(
          key: ValueKey(pet.id),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: PetCard(
              pet: pet,
              compatibility: compatibility,
              onTap: () => context.push('/pet/${pet.id}'),
            )
              .animate()
              .fadeIn(delay: (100 * petIndex).ms, duration: 400.ms)
              .slideY(begin: 0.1),
        );
      },
    );
  }

  Widget _buildVetClinicsTab(UserProfile? user, bool showViewerOnMap) {
    final clinicsSorted = ref.watch(communityVetClinicsProvider);
    final radiusFiltered =
        vetClinicsWithinRadiusMiles(clinicsSorted, user, _radiusMiles);
    final anchor = vetClinicsMapAnchor(user, radiusFiltered);
    final listClinics = _vetClinicsMatchingSearch(radiusFiltered);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: listClinics.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRadiusSlider(showViewerOnMap),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _vetSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search clinics by name or address…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: PawPartyColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: PawPartyColors.divider),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.local_hospital_outlined, size: 18, color: PawPartyColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pins need saved coordinates (we geocode on save when an address is set). Red markers: '
                        '${radiusFiltered.where((c) => c.latitude != null && c.longitude != null).length} '
                        'on map; list includes clinics without coordinates too.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: PawPartyColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CommunityVetClinicsMap(
                  clinics: radiusFiltered,
                  viewerPoint: anchor,
                  radiusMiles: _radiusMiles,
                  showViewerLocation: showViewerOnMap,
                  onClinicMarkerTapped: _openVetClinicInGoogleMapsFromMarker,
                ),
              ),
              if (listClinics.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    clinicsSorted.isEmpty
                        ? 'No vet clinics yet. When neighbors link a clinic on a pet profile, it appears here.'
                        : 'No clinics match your search or distance filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PawPartyColors.textSecondary),
                  ),
                ),
            ],
          );
        }
        final clinicIndex = index - 1;
        final c = listClinics[clinicIndex];
        final dist = _vetClinicDistanceLabel(user, c);
        final onMap = c.latitude != null && c.longitude != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Material(
            color: PawPartyColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _showVetClinicDetailSheet(c),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PawPartyColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            c.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (onMap)
                          Icon(
                            Icons.place,
                            size: 20,
                            color: PawPartyColors.primary,
                          ),
                      ],
                    ),
                    if (c.address != null &&
                        c.address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        c.address!,
                        style: TextStyle(
                          fontSize: 14,
                          color: PawPartyColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${c.linkedOwnerCount} neighbor${c.linkedOwnerCount == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${c.linkCount} pet${c.linkCount == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (dist != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.near_me_outlined, size: 16),
                            label: Text(dist, style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventsTab(UserProfile? user) {
    final eventsAsync = ref.watch(publicMeetupsProvider);
    final myUid = user?.id;

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load events: $e',
            textAlign: TextAlign.center,
            style: TextStyle(color: PawPartyColors.textSecondary),
          ),
        ),
      ),
      data: (events) {
        final filtered = events.where((m) {
          if (user?.latitude == null || user?.longitude == null) return true;
          final d = haversineMeters(
            GeoPoint(user!.latitude!, user.longitude!),
            GeoPoint(m.latitude, m.longitude),
          );
          return d <= _radiusMiles * 1609.34;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 56, color: PawPartyColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    'No public events nearby right now.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: PawPartyColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Local businesses and neighbors can host open events '
                    'that appear here. Try hosting one yourself!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: PawPartyColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final m = filtered[i];
            final isHost = m.hostId == myUid;
            return Padding(
              padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
              child: _EventCard(
                meetup: m,
                isHost: isHost,
                user: user,
                onTap: () => _showEventDetailSheet(m, user),
              ),
            );
          },
        );
      },
    );
  }

  void _showEventDetailSheet(Meetup meetup, UserProfile? user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _EventDetailSheet(
          meetup: meetup,
          user: user,
          onRsvpChanged: () {
            ref.invalidate(publicMeetupsProvider);
            ref.invalidate(incomingPartyInvitesProvider);
          },
        );
      },
    );
  }

  Widget _buildMapPrivacyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: PawPartyColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Map pins are approximate areas only — not exact home locations. '
              'Full addresses are shared only after a meetup invite is accepted.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: PawPartyColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by name, breed, or play style...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: PawPartyColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: PawPartyColors.divider),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Dog', 'Cat', 'Other'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(filter),
              onSelected: (_) => setState(() => _selectedFilter = filter),
              backgroundColor: PawPartyColors.surfaceVariant,
              selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
              checkmarkColor: PawPartyColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? PawPartyColors.primary
                    : PawPartyColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadiusSlider(bool distanceFilterActive) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!distanceFilterActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Distance filter needs your area — tap the location icon above, '
                'or add coordinates from your profile.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: PawPartyColors.textSecondary,
                ),
              ),
            ),
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: PawPartyColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _radiusMiles,
                  min: 1,
                  max: 15,
                  divisions: 14,
                  activeColor: PawPartyColors.primary,
                  label: '${_radiusMiles.toInt()} mi',
                  onChanged: distanceFilterActive
                      ? (v) => setState(() => _radiusMiles = v)
                      : null,
                ),
              ),
              Text(
                '${_radiusMiles.toInt()} mi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: distanceFilterActive
                      ? PawPartyColors.textPrimary
                      : PawPartyColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.meetup,
    required this.isHost,
    required this.user,
    required this.onTap,
  });

  final Meetup meetup;
  final bool isHost;
  final UserProfile? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(meetup.dateTime);
    final venue = meetup.venueDisplayName;

    return Material(
      color: PawPartyColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PawPartyColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meetup.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isHost)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('Your event',
                          style: TextStyle(fontSize: 11)),
                      backgroundColor:
                          PawPartyColors.primary.withValues(alpha: 0.1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: PawPartyColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                        fontSize: 13, color: PawPartyColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: PawPartyColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: PawPartyColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 14, color: PawPartyColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Hosted by ${meetup.hostName}',
                    style: TextStyle(
                        fontSize: 13, color: PawPartyColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chipTag(meetup.theme, Icons.celebration),
                  if (meetup.hasYard) _chipTag('Yard', Icons.fence),
                  if (meetup.hasPool) _chipTag('Pool', Icons.pool),
                  if (meetup.kidFriendly)
                    _chipTag('Kid-friendly', Icons.child_friendly),
                  if (meetup.maxGuests > 0)
                    _chipTag('${meetup.maxGuests} spots', Icons.group),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipTag(String label, IconData icon) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _EventDetailSheet extends StatefulWidget {
  const _EventDetailSheet({
    required this.meetup,
    required this.user,
    required this.onRsvpChanged,
  });

  final Meetup meetup;
  final UserProfile? user;
  final VoidCallback onRsvpChanged;

  @override
  State<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<_EventDetailSheet> {
  bool _busy = false;
  bool _hasRsvp = false;
  bool _checkingRsvp = true;

  @override
  void initState() {
    super.initState();
    _checkExistingRsvp();
  }

  Future<void> _checkExistingRsvp() async {
    final uid = widget.user?.id;
    if (uid == null) {
      setState(() => _checkingRsvp = false);
      return;
    }
    try {
      final active = await FirestoreMeetupRepository.guestIdsWithActiveInvite(
        meetupId: widget.meetup.id,
        hostId: widget.meetup.hostId,
      );
      if (!mounted) return;
      setState(() {
        _hasRsvp = active.contains(uid);
        _checkingRsvp = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingRsvp = false);
    }
  }

  Future<void> _rsvp() async {
    final uid = widget.user?.id;
    final name = widget.user?.displayName;
    if (uid == null || name == null) return;

    setState(() => _busy = true);
    try {
      await FirestoreMeetupRepository.rsvpToPublicMeetup(
        meetupId: widget.meetup.id,
        meetupTitle: widget.meetup.title,
        hostId: widget.meetup.hostId,
        hostName: widget.meetup.hostName,
        guestId: uid,
        guestName: name,
      );
      if (!mounted) return;
      setState(() {
        _hasRsvp = true;
        _busy = false;
      });
      widget.onRsvpChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not RSVP: $e')),
      );
    }
  }

  Future<void> _cancelRsvp() async {
    final uid = widget.user?.id;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await FirestoreMeetupRepository.cancelRsvp(
        meetupId: widget.meetup.id,
        actingUid: uid,
      );
      if (!mounted) return;
      setState(() {
        _hasRsvp = false;
        _busy = false;
      });
      widget.onRsvpChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meetup;
    final isHost = m.hostId == widget.user?.id;
    final dateStr = DateFormat('EEEE, MMMM d, y · h:mm a').format(m.dateTime);
    final durationStr =
        '${m.durationMinutes ~/ 60}h${m.durationMinutes % 60 > 0 ? " ${m.durationMinutes % 60}m" : ""}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _detailRow(Icons.calendar_today, dateStr),
            const SizedBox(height: 6),
            _detailRow(Icons.timer_outlined, durationStr),
            const SizedBox(height: 6),
            _detailRow(Icons.location_on_outlined, m.venueDisplayName),
            const SizedBox(height: 6),
            _detailRow(Icons.person_outline, 'Hosted by ${m.hostName}'),
            if (m.description != null && m.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                m.description!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: PawPartyColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chipTag(m.theme, Icons.celebration),
                if (m.hasYard) _chipTag('Yard', Icons.fence),
                if (m.hasPool) _chipTag('Pool', Icons.pool),
                if (m.kidFriendly)
                  _chipTag('Kid-friendly', Icons.child_friendly),
                if (m.pizzaCommitment.willProvidePizza)
                  _chipTag('Pizza provided', Icons.local_pizza),
                if (m.pizzaCommitment.willProvideDrinks)
                  _chipTag('Drinks provided', Icons.local_drink),
              ],
            ),
            const SizedBox(height: 20),
            if (_checkingRsvp)
              const Center(child: CircularProgressIndicator())
            else if (isHost)
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: const Text("You're hosting this event"),
              )
            else if (_hasRsvp)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text("You're going!"),
                      style: FilledButton.styleFrom(
                        backgroundColor: PawPartyColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy ? null : _cancelRsvp,
                    child: const Text('Cancel'),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: _busy ? null : _rsvp,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.event_available),
                label: const Text('RSVP — Count me in!'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: PawPartyColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: PawPartyColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipTag(String label, IconData icon) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

