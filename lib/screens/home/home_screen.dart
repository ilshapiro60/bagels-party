import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/mock_data.dart';
import '../../widgets/pet_card.dart';
import '../../widgets/meetup_card.dart';
import '../../widgets/paw_file_image.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final pets = ref.watch(userPetsProvider);
    final meetups = ref.watch(upcomingMeetupsProvider);
    final userName = authState.user?.displayName ?? 'Friend';
    final areaLabel = authState.user?.neighborhood ?? 'Nearby';
    final photoUrl = authState.user?.photoUrl;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context, userName, areaLabel, photoUrl),
            ),
            SliverToBoxAdapter(
              child: _buildQuickActions(context),
            ),
            SliverToBoxAdapter(
              child: _buildPartyStoriesCard(context),
            ),
            if (meetups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Upcoming parties', Icons.celebration),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: meetups.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: MeetupCard(meetup: meetups[index]),
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Your Pets', Icons.pets),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pets.length + 1,
                  itemBuilder: (context, index) {
                    if (index == pets.length) return _buildAddPetCard(context);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildPetMiniCard(context, pets[index]),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Nearby Matches', Icons.favorite),
            ),
            SliverToBoxAdapter(
              child: _buildNearbyMatches(context, pets),
            ),
            SliverToBoxAdapter(
              child: _buildNeighborhoodBanner(context, areaLabel),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    String areaLabel,
    String? photoUrl,
  ) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey $name! 👋',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: PawPartyColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      areaLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
              child: hasPhoto
                  ? ClipOval(
                      child: PawFileOrNetworkImage(
                        path: photoUrl,
                        width: 48,
                        height: 48,
                      ),
                    )
                  : const Icon(Icons.person, color: PawPartyColors.primary),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _quickActionCard(
              context,
              icon: Icons.local_pizza,
              label: 'Host a\nparty',
              color: PawPartyColors.primary,
              onTap: () => context.go('/host'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickActionCard(
              context,
              icon: Icons.search,
              label: 'Discover\nPets',
              color: PawPartyColors.secondary,
              onTap: () => context.go('/discover'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickActionCard(
              context,
              icon: Icons.auto_stories,
              label: 'Passport\nJournal',
              color: PawPartyColors.pizzaGold,
              onTap: () => context.go('/passport'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }

  Widget _buildPartyStoriesCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/party-stories'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PawPartyColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.celebration, color: PawPartyColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Party stories',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Photos & videos from meetups',
                        style: TextStyle(
                          fontSize: 13,
                          color: PawPartyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: PawPartyColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: PawPartyColors.textPrimary,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: PawPartyColors.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildPetMiniCard(BuildContext context, pet) {
    return GestureDetector(
      onTap: () => context.push('/pet/${pet.id}'),
      child: Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: PawPartyColors.primary.withValues(alpha: 0.1),
            child: pet.photoUrl != null && pet.photoUrl!.isNotEmpty
                ? ClipOval(
                    child: PawFileOrNetworkImage(
                      path: pet.photoUrl!,
                      width: 72,
                      height: 72,
                    ),
                  )
                : Text(
                    pet.name[0],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: PawPartyColors.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            pet.name,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${pet.meetupCount} meetups',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 14, color: PawPartyColors.pizzaGold),
              const SizedBox(width: 2),
              Text(
                pet.averageRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PawPartyColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildAddPetCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/create-pet'),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: PawPartyColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: PawPartyColors.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: PawPartyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 28, color: PawPartyColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Pet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PawPartyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyMatches(BuildContext context, userPets) {
    final nearbyPets = MockData.nearbyPets.take(3).toList();
    final primaryPet = userPets.isNotEmpty ? userPets.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: nearbyPets.map((pet) {
          final compatibility = primaryPet != null
              ? MockData.calculateCompatibility(primaryPet, pet)
              : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PetCard(
              pet: pet,
              compatibility: compatibility,
              onTap: () => context.push('/pet/${pet.id}'),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNeighborhoodBanner(BuildContext context, String areaLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PawPartyColors.secondary,
            PawPartyColors.secondary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  areaLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '12 active hosts • 47 parties this year',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: PawPartyColors.pizzaGold),
                    const SizedBox(width: 4),
                    Text(
                      '4.8 avg rating',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.map_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }
}
