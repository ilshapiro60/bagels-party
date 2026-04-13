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
import '../../widgets/friend_owner_chip.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_fullscreen_photo_viewer.dart';

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
              child: _buildHeader(context, ref, userName, areaLabel, photoUrl),
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
              child: _buildNearbyEventsPreview(context, ref, authState.user),
            ),
            if (meetups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Your parties', Icons.celebration),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
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
                height: 160,
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
              child: _buildNewsletterCard(context),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String name,
    String areaLabel,
    String? photoUrl,
  ) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final hasUnread = ref.watch(hasUnreadMessagesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: PawPartyColors.textSecondary),
                    const SizedBox(width: 3),
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
            onTap: () => context.push('/messenger'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PawPartyColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: PawPartyColors.primary,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: PawPartyColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: PawPartyColors.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PawPartyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline,
                size: 22,
                color: PawPartyColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/profile'),
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

  Widget _buildNewsletterCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/neighborhood-news'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 22, color: PawPartyColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area Newsletter',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lost pets, tips, local buzz & more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: PawPartyColors.textHint,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: PawPartyColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsSection(
    BuildContext context,
    WidgetRef ref,
    UserProfile? user,
  ) {
    final friendUids = user?.friendUids ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Friends', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (user != null)
                IconButton(
                  onPressed: () => _showShoutDialog(context, ref, user),
                  tooltip: 'Shout to friends',
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: Icon(Icons.campaign_outlined, color: PawPartyColors.primary, size: 22),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: PawPartyColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 20, color: PawPartyColors.textHint),
                  const SizedBox(width: 8),
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
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: friendUids.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  return FriendOwnerChip(uid: friendUids[i]);
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Events nearby', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/discover', extra: 2),
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

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PawPartyColors.primary),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPetMiniCard(BuildContext context, Pet pet) {
    final photoUrls = pet.photoUrlsForViewer;
    final thumb = pet.photoUrl != null && pet.photoUrl!.trim().isNotEmpty
        ? pet.photoUrl!.trim()
        : (photoUrls.isNotEmpty ? photoUrls.first : null);

    final avatar = CircleAvatar(
      radius: 30,
      backgroundColor: PawPartyColors.primary.withValues(alpha: 0.1),
      child: thumb != null
          ? ClipOval(
              child: PawFileOrNetworkImage(
                path: thumb,
                width: 60,
                height: 60,
              ),
            )
          : Text(
              pet.name.isNotEmpty ? pet.name[0] : '?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: PawPartyColors.primary,
              ),
            ),
    );

    return Container(
      width: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (photoUrls.isNotEmpty) {
                showPawFullscreenPhotos(context, urls: photoUrls);
              } else {
                context.push('/pet/${pet.id}');
              }
            },
            child: avatar,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/pet/${pet.id}'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }

  Widget _buildAddPetCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/create-pet'),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: PawPartyColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PawPartyColors.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PawPartyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 22, color: PawPartyColors.primary),
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
            padding: const EdgeInsets.only(bottom: 8),
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
            padding: const EdgeInsets.only(bottom: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, size: 18, color: PawPartyColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    inv.meetupTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${inv.hostName} invited you',
              style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(PartyInviteStatus.declined),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(PartyInviteStatus.accepted),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
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
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go('/discover', extra: 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PawPartyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('d').format(meetup.dateTime),
                      style: TextStyle(
                        fontSize: 14,
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
        'Your passport entries and album photos linked to this meetup are removed, '
        'and stored photos/videos are deleted when possible.',
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
