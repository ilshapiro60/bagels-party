import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/firebase_bootstrap.dart';
import '../../models/passport_entry.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_passport_repository.dart';
import '../../widgets/passport_entry_card.dart';

class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key, this.initialMeetupId});

  /// When set (e.g. from `/passport?meetupId=`), Journal opens filtered to this party.
  final String? initialMeetupId;

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPetIndex = 0;
  final _journalSearch = TextEditingController();
  final _communitySearch = TextEditingController();

  /// Non-null → journal list only shows entries for this meetup (from deep link).
  String? _meetupJournalFilter;
  bool _autoPetForMeetupDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    final raw = widget.initialMeetupId?.trim();
    _meetupJournalFilter = (raw != null && raw.isNotEmpty) ? raw : null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _journalSearch.dispose();
    _communitySearch.dispose();
    super.dispose();
  }

  Pet? _currentPet(List<Pet> pets) {
    if (pets.isEmpty) return null;
    final i = _selectedPetIndex.clamp(0, pets.length - 1);
    return pets[i];
  }

  List<PassportEntry> _filterEntries(
    List<PassportEntry> entries,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      if (e.searchText.isNotEmpty && e.searchText.contains(q)) return true;
      return e.meetupTitle.toLowerCase().contains(q) ||
          e.hostName.toLowerCase().contains(q) ||
          e.petName.toLowerCase().contains(q) ||
          e.behaviorNotes?.toLowerCase().contains(q) == true ||
          e.metPetNames.any((n) => n.toLowerCase().contains(q));
    }).toList();
  }

  void _maybeSelectPetForMeetupFilter(List<PassportEntry> allEntries) {
    if (_autoPetForMeetupDone || _meetupJournalFilter == null) return;
    final filter = _meetupJournalFilter!;
    if (allEntries.isEmpty) {
      _autoPetForMeetupDone = true;
      return;
    }
    final subset = allEntries.where((e) => e.meetupId == filter).toList();
    _autoPetForMeetupDone = true;
    if (subset.isEmpty) return;
    final petIds = subset.map((e) => e.petId).toSet();
    final pets = ref.read(userPetsProvider);
    final idx = pets.indexWhere((p) => petIds.contains(p.id));
    if (idx < 0 || idx == _selectedPetIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _selectedPetIndex = idx);
    });
  }

  List<PassportEntry> _entriesForJournal(
    List<PassportEntry> entries,
    Pet? pet,
  ) {
    var list = pet != null ? entries.where((e) => e.petId == pet.id) : entries;
    if (_meetupJournalFilter != null) {
      list = list.where((e) => e.meetupId == _meetupJournalFilter);
    }
    return list.toList();
  }

  void _editEntry(PassportEntry entry) {
    context.push('/add-passport-entry', extra: entry);
  }

  Future<void> _confirmDeleteEntry(PassportEntry entry) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          '“${entry.meetupTitle}” will be removed from your passport.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PawPartyColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await FirestorePassportRepository.deleteEntry(
        entryId: entry.id,
        actingOwnerId: user.id,
      );
      ref.invalidate(passportMyEntriesProvider);
      ref.invalidate(passportPublicEntriesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(userPetsProvider);
    final myAsync = ref.watch(passportMyEntriesProvider);
    final publicAsync = ref.watch(passportPublicEntriesProvider);
    final pet = _currentPet(pets);

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppConstants.appName} Passport'),
        actions: const [],
      ),
      floatingActionButton: _tabController.index == 2
          ? null
          : FloatingActionButton.small(
              onPressed: !isFirebaseInitialized
                  ? null
                  : () => context.push(
                        '/add-passport-entry',
                        extra: pet?.id,
                      ),
              tooltip: 'Add entry',
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (pets.length > 1) _buildPetSelector(pets),
          _buildStatsBar(pet, myAsync.value ?? []),
          TabBar(
            controller: _tabController,
            labelColor: PawPartyColors.primary,
            unselectedLabelColor: PawPartyColors.textHint,
            indicatorColor: PawPartyColors.primary,
            tabs: const [
              Tab(text: 'Journal'),
              Tab(text: 'Community'),
              Tab(text: 'Stats'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildJournalTab(myAsync, pet),
                _buildCommunityTab(publicAsync),
                _buildStatsTab(myAsync.value ?? [], pet),
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
          final isSelected = index == _selectedPetIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPetIndex = index),
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
                          '${pet.meetupCount} meetups',
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
          _statItem('Entries', '${petEntries.length}', Icons.auto_stories),
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
            'Public',
            '${petEntries.where((e) => e.isPublic).length}',
            Icons.public,
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

  Widget _buildJournalTab(AsyncValue<List<PassportEntry>> myAsync, Pet? pet) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _journalSearch,
            decoration: InputDecoration(
              hintText: 'Search your journal…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_meetupJournalFilter != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: Icon(Icons.celebration, size: 18, color: PawPartyColors.primary),
                label: Text(
                  'This party',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PawPartyColors.textPrimary,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => setState(() => _meetupJournalFilter = null),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        Expanded(
          child: myAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load: $e')),
            data: (entries) {
              _maybeSelectPetForMeetupFilter(entries);
              final forPet = _entriesForJournal(entries, pet);
              final filtered = _filterEntries(forPet, _journalSearch.text);
              if (filtered.isEmpty) {
                final partyOnlyEmpty = _meetupJournalFilter != null &&
                    forPet.isEmpty &&
                    entries.isNotEmpty;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories, size: 64, color: PawPartyColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        entries.isEmpty
                            ? 'No entries yet'
                            : partyOnlyEmpty
                                ? 'No entries for this party'
                                : 'No matches',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: PawPartyColors.textHint,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entries.isEmpty
                            ? 'Tap Add entry to log a party.'
                            : partyOnlyEmpty
                                ? 'Try another pet above, or clear the party filter.'
                                : 'Try a different search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PawPartyColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return PassportEntryCard(
                    entry: entry,
                    onEdit: () => _editEntry(entry),
                    onDelete: () => _confirmDeleteEntry(entry),
                  )
                      .animate()
                      .fadeIn(delay: (50 * index).ms, duration: 400.ms)
                      .slideX(begin: 0.05);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityTab(AsyncValue<List<PassportEntry>> publicAsync) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _communitySearch,
            decoration: InputDecoration(
              hintText: 'Search community posts…',
              prefixIcon: const Icon(Icons.travel_explore),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: publicAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load: $e')),
            data: (entries) {
              final filtered = _filterEntries(entries, _communitySearch.text);
              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.public, size: 56, color: PawPartyColors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          entries.isEmpty
                              ? 'No public posts yet'
                              : 'No matches',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entries.isEmpty
                              ? 'When you add an entry, turn on “Share on Community” to show it here.'
                              : 'Try another search term.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PawPartyColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return PassportEntryCard(
                    entry: filtered[index],
                    showPetAttribution: true,
                  )
                      .animate()
                      .fadeIn(delay: (40 * index).ms, duration: 350.ms);
                },
              );
            },
          ),
        ),
      ],
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
          if (sortedFriends.isEmpty)
            Text(
              'Log meetups in your journal to see stats.',
              style: TextStyle(color: PawPartyColors.textSecondary),
            )
          else
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
