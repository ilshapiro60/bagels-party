import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/passport_entry.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../widgets/passport_entry_card.dart';

class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(userPetsProvider);
    final entries = ref.watch(passportEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppConstants.appName} Passport'),
        actions: [
          IconButton(
            tooltip: 'Party stories',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.push('/party-stories'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (pets.length > 1) _buildPetSelector(pets),
          _buildStatsBar(pets.isNotEmpty ? pets.first : null, entries),
          TabBar(
            controller: _tabController,
            labelColor: PawPartyColors.primary,
            unselectedLabelColor: PawPartyColors.textHint,
            indicatorColor: PawPartyColors.primary,
            tabs: const [
              Tab(text: 'Journal'),
              Tab(text: 'Stats'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildJournalTab(entries, pets.isNotEmpty ? pets.first : null),
                _buildStatsTab(entries, pets.isNotEmpty ? pets.first : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelector(List<Pet> pets) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: pets.length,
        itemBuilder: (context, index) {
          final pet = pets[index];
          final isSelected = index == 0;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? PawPartyColors.primary.withValues(alpha: 0.1)
                      : PawPartyColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? PawPartyColors.primary
                        : PawPartyColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        pet.name[0],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: PawPartyColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: PawPartyColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${pet.meetupCount} entries',
                          style: TextStyle(
                            fontSize: 12,
                            color: PawPartyColors.textSecondary,
                          ),
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
    );
  }

  Widget _buildStatsBar(Pet? pet, List<PassportEntry> entries) {
    final petEntries = pet != null
        ? entries.where((e) => e.petId == pet.id).toList()
        : entries;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PawPartyColors.primary, PawPartyColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Meetups', '${petEntries.length}', Icons.celebration),
          _statItem(
            'Friends',
            '${petEntries.expand((e) => e.metPetNames).toSet().length}',
            Icons.pets,
          ),
          _statItem(
            'Rating',
            pet?.averageRating.toStringAsFixed(1) ?? '—',
            Icons.star,
          ),
          _statItem(
            'Streak',
            '3 wks',
            Icons.local_fire_department,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildJournalTab(List<PassportEntry> entries, Pet? pet) {
    final petEntries = pet != null
        ? entries.where((e) => e.petId == pet.id).toList()
        : entries;

    if (petEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories, size: 64, color: PawPartyColors.textHint),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: PawPartyColors.textHint,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attend a party to start building\nyour pet\'s social passport!',
              textAlign: TextAlign.center,
              style: TextStyle(color: PawPartyColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: petEntries.length,
      itemBuilder: (context, index) {
        return PassportEntryCard(entry: petEntries[index])
            .animate()
            .fadeIn(delay: (100 * index).ms, duration: 400.ms)
            .slideX(begin: 0.05);
      },
    );
  }

  Widget _buildStatsTab(List<PassportEntry> entries, Pet? pet) {
    final petEntries = pet != null
        ? entries.where((e) => e.petId == pet.id).toList()
        : entries;
    final allFriends = petEntries.expand((e) => e.metPetNames).toList();
    final friendCounts = <String, int>{};
    for (final name in allFriends) {
      friendCounts[name] = (friendCounts[name] ?? 0) + 1;
    }
    final sortedFriends = friendCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frequent Friends', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...sortedFriends.map((friend) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PawPartyColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: PawPartyColors.secondary.withValues(alpha: 0.15),
                    child: Text(
                      friend.key[0],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: PawPartyColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      friend.key,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PawPartyColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${friend.value}x',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: PawPartyColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Text('Play Outcomes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...PlayOutcome.values.map((outcome) {
            final count = petEntries.where((e) => e.playOutcome == outcome).length;
            if (count == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PawPartyColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Text(outcome.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(outcome.label, style: Theme.of(context).textTheme.bodyLarge)),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: PawPartyColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
