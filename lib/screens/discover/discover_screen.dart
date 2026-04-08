import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/community_vet_clinic.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/approximate_location.dart';
import '../../utils/pet_compatibility.dart';
import '../../widgets/community_vet_clinics_map.dart';
import '../../widgets/nearby_pets_map.dart';
import '../../widgets/pet_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  double _radiusMiles = 5.0;
  final ScrollController _listScroll = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};
  late final TabController _tabController;
  final TextEditingController _vetSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vetSearchController.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _scrollToPet(String petId) {
    final key = _cardKeys[petId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    }
  }

  void _showMapPetActionsSheet(Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  pet.name,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.pets_outlined),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/pet/${pet.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_list_outlined),
                title: const Text('Show in list'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToPet(pet.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
    final primaryPet = userPets.isNotEmpty ? userPets.first : null;

    final typeFiltered = _selectedFilter == 'All'
        ? nearbyPets
        : nearbyPets.where((p) => p.type == _selectedFilter).toList();

    final visiblePets = petsWithinRadiusMiles(
      typeFiltered,
      authState.user,
      _radiusMiles,
    );

    final viewerPoint = discoverMapAnchor(authState.user, visiblePets);
    final showViewerOnMap = profileHasMapCoordinates(authState.user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pets_outlined), text: 'Pets'),
            Tab(icon: Icon(Icons.local_hospital_outlined), text: 'Vet clinics'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh my location',
            icon: const Icon(Icons.my_location),
            onPressed: () async {
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
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
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
                  viewerProfile: authState.user,
                  radiusMiles: _radiusMiles,
                  showViewerLocation: showViewerOnMap,
                  onPetMarkerTapped: _showMapPetActionsSheet,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _listScroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visiblePets.length,
                  itemBuilder: (context, index) {
                    final pet = visiblePets[index];
                    _cardKeys[pet.id] ??= GlobalKey();
                    final compatibility = primaryPet != null
                        ? calculatePetCompatibility(primaryPet, pet)
                        : 0.0;
                    return Padding(
                      key: _cardKeys[pet.id],
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PetCard(
                          pet: pet,
                          compatibility: compatibility,
                          onTap: () => context.push('/pet/${pet.id}'),
                        )
                          .animate()
                          .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                          .slideY(begin: 0.1),
                    );
                  },
                ),
              ),
            ],
          ),
          _buildVetClinicsTab(authState.user, showViewerOnMap),
        ],
      ),
    );
  }

  Widget _buildVetClinicsTab(UserProfile? user, bool showViewerOnMap) {
    final clinicsSorted = ref.watch(communityVetClinicsProvider);
    final radiusFiltered =
        vetClinicsWithinRadiusMiles(clinicsSorted, user, _radiusMiles);
    final anchor = vetClinicsMapAnchor(user, radiusFiltered);
    final listClinics = _vetClinicsMatchingSearch(radiusFiltered);

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
            onClinicMarkerTapped: _showVetClinicDetailSheet,
          ),
        ),
        Expanded(
          child: listClinics.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      clinicsSorted.isEmpty
                          ? 'No vet clinics yet. When neighbors link a clinic on a pet profile, it appears here.'
                          : 'No clinics match your search or distance filter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawPartyColors.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: listClinics.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = listClinics[index];
                    final dist = _vetClinicDistanceLabel(user, c);
                    final onMap =
                        c.latitude != null && c.longitude != null;
                    return Material(
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
                    );
                  },
                ),
        ),
      ],
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
