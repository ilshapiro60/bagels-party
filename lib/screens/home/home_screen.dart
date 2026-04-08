import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../models/party_invite.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_passport_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../utils/pet_compatibility.dart';
import '../../widgets/pet_card.dart';
import '../../widgets/meetup_card.dart';
import '../../widgets/paw_file_image.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final pets = ref.watch(userPetsProvider);
    final meetups = ref.watch(upcomingMeetupsProvider).value ?? [];
    final partyInvites = ref.watch(incomingPartyInvitesProvider).value ?? [];
    final pendingInvites = partyInvites
        .where((i) => i.status == PartyInviteStatus.pending)
        .toList();
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
            if (pendingInvites.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Party Invitations', Icons.mail),
              ),
              SliverToBoxAdapter(
                child: _buildPartyInvites(context, ref, pendingInvites),
              ),
            ],
            SliverToBoxAdapter(
              child: _buildPartyStoriesCard(context),
            ),
            SliverToBoxAdapter(
              child: _buildAreaNewsletterCard(context),
            ),
            if (meetups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Upcoming parties', Icons.celebration),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 248,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: meetups.length,
                    itemBuilder: (context, index) {
                      final meetup = meetups[index];
                      final userId = authState.user?.id;
                      final isHost =
                          userId != null && meetup.hostId == userId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Consumer(
                          builder: (context, ref, _) {
                            String? guestSummary;
                            if (isHost) {
                              final async = ref.watch(
                                partyInvitesForHostedMeetupProvider((
                                  meetupId: meetup.id,
                                  hostId: userId,
                                )),
                              );
                              guestSummary = async.maybeWhen(
                                data: (list) {
                                  if (list.isEmpty) {
                                    return 'No invites — tap Invite';
                                  }
                                  final acc = list
                                      .where(
                                        (i) =>
                                            i.status ==
                                            PartyInviteStatus.accepted,
                                      )
                                      .length;
                                  final pend = list
                                      .where(
                                        (i) =>
                                            i.status ==
                                            PartyInviteStatus.pending,
                                      )
                                      .length;
                                  final dec = list
                                      .where(
                                        (i) =>
                                            i.status ==
                                            PartyInviteStatus.declined,
                                      )
                                      .length;
                                  final parts = <String>['$acc accepted'];
                                  if (pend > 0) parts.add('$pend pending');
                                  if (dec > 0) parts.add('$dec declined');
                                  return parts.join(' · ');
                                },
                                orElse: () => null,
                              );
                            }
                            return MeetupCard(
                              meetup: meetup,
                              currentUserId: userId,
                              guestSummaryOverride: guestSummary,
                              onHostDelete: (m) =>
                                  _confirmDeleteHostedParty(context, ref, m),
                              onHostInviteMore: isHost
                                  ? () => context
                                      .push('/invite-friends/${meetup.id}')
                                  : null,
                              onHostManageGuests: isHost
                                  ? () =>
                                      context.push('/party-guests/${meetup.id}')
                                  : null,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Your Pets', Icons.pets),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
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
              child: _buildNearbyMatches(context, ref, pets),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => context.push('/friends'),
            icon: const Icon(Icons.people_outline),
            tooltip: 'Friends',
            style: IconButton.styleFrom(
              foregroundColor: PawPartyColors.primary,
              backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(width: 4),
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
                    Expanded(
                      child: Text(
                        areaLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildAreaNewsletterCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/neighborhood-news'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PawPartyColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.forum_outlined, color: PawPartyColors.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area newsletter',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Posts from neighbors in your area (2-week feed)',
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
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

  Widget _buildNearbyMatches(
    BuildContext context,
    WidgetRef ref,
    List<Pet> userPets,
  ) {
    final nearbyPets = ref.watch(nearbyPetsProvider).take(3).toList();
    final primaryPet = userPets.isNotEmpty ? userPets.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: nearbyPets.map((pet) {
          final compatibility = primaryPet != null
              ? calculatePetCompatibility(primaryPet, pet)
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

  Widget _buildPartyInvites(
    BuildContext context,
    WidgetRef ref,
    List<PartyInvite> invites,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: invites.map((invite) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PartyInviteCard(invite: invite),
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
                  'Discover pets nearby and host your own meetups.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.35,
                  ),
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

class _PartyInviteCard extends ConsumerStatefulWidget {
  const _PartyInviteCard({required this.invite});
  final PartyInvite invite;

  @override
  ConsumerState<_PartyInviteCard> createState() => _PartyInviteCardState();
}

class _PartyInviteCardState extends ConsumerState<_PartyInviteCard> {
  bool _busy = false;

  Future<void> _respond(PartyInviteStatus response) async {
    if (_busy) return;
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await FirestoreMeetupRepository.respondToInvite(
        inviteId: widget.invite.id,
        actingUid: uid,
        response: response,
      );
      if (!mounted) return;
      final label = response == PartyInviteStatus.accepted ? 'accepted' : 'declined';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite $label.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invite;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, size: 20, color: PawPartyColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inv.meetupTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${inv.hostName} invited you to their party',
              style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(PartyInviteStatus.declined),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(PartyInviteStatus.accepted),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _deletePartyLinkedMedia(WidgetRef ref, String meetupId) async {
  final storage = FirebaseStorageService.instance;
  final stories = ref.read(partyStoriesProvider);
  final urls = <String>{};
  for (final s in stories.where((s) => s.meetupId == meetupId)) {
    urls.addAll(s.imagePaths);
    urls.addAll(s.videoPaths);
  }
  if (isFirebaseInitialized) {
    final user = ref.read(authStateProvider).user;
    if (user != null) {
      final passEntries =
          await FirestorePassportRepository.fetchOwnerEntriesForMeetup(
        ownerId: user.id,
        meetupId: meetupId,
      );
      for (final e in passEntries) {
        urls.addAll(e.photoUrls);
        urls.addAll(e.videoPaths);
      }
    }
  }
  for (final u in urls) {
    await storage.deleteRemoteObjectIfPossible(u);
  }
}

Future<void> _confirmDeleteHostedParty(
  BuildContext context,
  WidgetRef ref,
  Meetup meetup,
) async {
  if (!isFirebaseInitialized) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Firebase is not configured — cannot delete the party.'),
      ),
    );
    return;
  }
  final user = ref.read(authStateProvider).user;
  if (user == null || user.id != meetup.hostId) return;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this party?'),
      content: Text(
        '“${meetup.title}” will be removed for everyone. '
        'Your passport entries and party stories linked to this meetup are removed, '
        'and stored photos/videos for those items are deleted when possible.',
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
  if (ok != true || !context.mounted) return;

  try {
    await FirestoreMeetupRepository.deleteMeetup(
      meetupId: meetup.id,
      actingHostId: user.id,
    );
    await FirestoreProfileRepository.decrementHostCount(user.id);
    final nextCount = (user.hostCount - 1).clamp(0, 0x7fffffff);
    ref.read(authStateProvider.notifier).updateUser(
          user.copyWithHostCount(nextCount),
        );

    await _deletePartyLinkedMedia(ref, meetup.id);
    ref.read(partyStoriesProvider.notifier).removeStoriesForMeetup(meetup.id);
    await FirestorePassportRepository.deleteEntriesForMeetup(
      ownerId: user.id,
      meetupId: meetup.id,
    );
    ref.invalidate(passportMyEntriesProvider);
    ref.invalidate(passportPublicEntriesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${meetup.title}” was deleted.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete party: $e')),
      );
    }
  }
}
