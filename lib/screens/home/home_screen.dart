import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../models/party_invite.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_passport_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../services/approximate_location.dart';
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
            SliverToBoxAdapter(
              child: _buildFriendsSection(context, ref, authState.user),
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
            SliverToBoxAdapter(
              child: _buildNearbyEventsPreview(context, ref, authState.user),
            ),
            if (meetups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Your parties', Icons.celebration),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 320,
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
                              onAddPhotos: () => context.push(
                                Uri(path: '/add-story', queryParameters: {
                                  'meetupId': meetup.id,
                                  'meetupTitle': meetup.title,
                                }).toString(),
                              ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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

  Widget _buildFriendsSection(
    BuildContext context,
    WidgetRef ref,
    UserProfile? user,
  ) {
    final friendUids = user?.friendUids ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Friends', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (user != null)
                TextButton(
                  onPressed: () => _showShoutDialog(context, ref, user),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Shout'),
                ),
              TextButton(
                onPressed: () => context.push('/friends'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (friendUids.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: PawPartyColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 24, color: PawPartyColors.textHint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No friends yet — discover pets nearby to connect.',
                      style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Discover'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: friendUids.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  return _FriendChip(uid: friendUids[i]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNearbyEventsPreview(
    BuildContext context,
    WidgetRef ref,
    UserProfile? user,
  ) {
    final eventsAsync = ref.watch(publicMeetupsProvider);
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (events) {
        final nearby = events.where((m) {
          if (user?.latitude == null || user?.longitude == null) return true;
          final d = haversineMeters(
            GeoPoint(user!.latitude!, user.longitude!),
            GeoPoint(m.latitude, m.longitude),
          );
          return d <= 5 * 1609.34;
        }).toList();

        if (nearby.isEmpty) return const SizedBox.shrink();

        final preview = nearby.take(3).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Events nearby', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text('See all (${nearby.length})'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...preview.map((m) => _NearbyEventTile(meetup: m, user: user)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartyStoriesCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Material(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/party-stories'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.celebration, size: 20, color: PawPartyColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Party stories',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  'Photos & videos',
                  style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: PawPartyColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaNewsletterCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Material(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/neighborhood-news'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 20, color: PawPartyColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Area newsletter',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  '2-week feed',
                  style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: PawPartyColors.textHint),
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

class _NearbyEventTile extends StatelessWidget {
  const _NearbyEventTile({required this.meetup, required this.user});

  final Meetup meetup;
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(meetup.dateTime);
    final distLabel = _distanceLabel();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/discover'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PawPartyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('d').format(meetup.dateTime),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PawPartyColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meetup.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr${distLabel.isNotEmpty ? ' · $distLabel' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (meetup.hostName.isNotEmpty)
                  Text(
                    meetup.hostName.split(' ').first,
                    style: TextStyle(fontSize: 11, color: PawPartyColors.textHint),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: PawPartyColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _distanceLabel() {
    if (user?.latitude == null || user?.longitude == null) return '';
    final meters = haversineMeters(
      GeoPoint(user!.latitude!, user!.longitude!),
      GeoPoint(meetup.latitude, meetup.longitude),
    );
    final miles = meters / 1609.34;
    if (miles < 0.3) return 'Nearby';
    return '${miles.toStringAsFixed(1)} mi';
  }
}

class _FriendChip extends ConsumerWidget {
  const _FriendChip({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerProfileProvider(uid));
    return async.when(
      data: (p) => GestureDetector(
        onTap: () => context.push('/friend/$uid'),
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
                child: p.photoUrl != null && p.photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: PawFileOrNetworkImage(
                          path: p.photoUrl!,
                          width: 44,
                          height: 44,
                        ),
                      )
                    : Text(
                        p.displayName.isNotEmpty ? p.displayName[0] : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PawPartyColors.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                p.displayName.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      loading: () => const SizedBox(
        width: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox(width: 56),
    );
  }
}

void _showShoutDialog(BuildContext context, WidgetRef ref, UserProfile user) {
  final controller = TextEditingController();
  final presets = [
    'Walking my dog at the park — come join us!',
    'At the dog park right now, stop by!',
    'Anyone up for a walk this evening?',
  ];

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Shout to friends'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send a quick message to all your friends.',
              style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g., Walking my dog at 7 AM — join me!',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: presets
                  .map(
                    (p) => ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 11)),
                      onPressed: () => controller.text = p,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(ctx);
            await _sendShout(context, ref, user, text);
          },
          icon: const Icon(Icons.campaign, size: 18),
          label: const Text('Send'),
        ),
      ],
    ),
  );
}

Future<void> _sendShout(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
  String message,
) async {
  try {
    await FirestoreProfileRepository.broadcastShout(
      fromUid: user.id,
      fromName: user.displayName,
      friendUids: user.friendUids,
      message: message,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shout sent to your friends!')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send shout: $e')),
      );
    }
  }
}

Future<void> _deletePartyLinkedMedia(WidgetRef ref, String meetupId) async {
  final storage = FirebaseStorageService.instance;
  final urls = <String>{};
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
