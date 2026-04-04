import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../services/approximate_location.dart';
import '../../utils/pet_compatibility.dart';
import '../../widgets/nearby_pets_map.dart';
import '../../widgets/pet_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _selectedFilter = 'All';
  double _radiusMiles = 5.0;
  final ScrollController _listScroll = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void dispose() {
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
        title: const Text('Discover Pets'),
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
      body: Column(
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
