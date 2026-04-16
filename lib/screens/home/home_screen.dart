import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../models/neighborhood_news.dart';
import '../../models/party_invite.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_passport_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../services/approximate_location.dart';
import '../../widgets/meetup_card.dart';
import '../../widgets/friend_owner_chip.dart';
import '../../widgets/party_invite_card.dart';
import '../../widgets/paw_file_image.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final meetupsRaw = ref.watch(upcomingMeetupsProvider).value ?? [];
    final meetupsOrdered = sortHostedMeetupsFutureFirst(meetupsRaw);
    final futureMeetupsCount = meetupsRaw.where((m) => m.hasNotEnded).length;
    final futureInvites = ref.watch(futureIncomingPartyInvitesProvider).value ?? [];
    final invitationsCount = futureInvites.length;
    final pendingInvites = futureInvites
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
              child: _buildHeader(
                context,
                ref,
                userName,
                areaLabel,
                photoUrl,
                myPartiesCount: futureMeetupsCount,
                invitationsCount: invitationsCount,
              ),
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
            if (meetupsOrdered.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Your parties', Icons.celebration),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: meetupsOrdered.length,
                    itemBuilder: (context, index) {
                      final meetup = meetupsOrdered[index];
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
                              onTap: isHost
                                  ? () {
                                      if (!meetup.hasNotEnded) {
                                        context.go(
                                          '/passport?meetupId=${meetup.id}',
                                        );
                                      } else {
                                        context.push(
                                          '/party-guests/${meetup.id}',
                                        );
                                      }
                                    }
                                  : null,
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
              child: _buildAreaNewsletterSection(context, ref, authState.user),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaNewsletterSection(
    BuildContext context,
    WidgetRef ref,
    UserProfile? user,
  ) {
    if (user == null) return const SizedBox.shrink();

    if (user.neighborhoodKey.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_outlined, size: 20, color: PawPartyColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Area newsletter',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set your neighborhood in Profile to read posts from nearby pet parents.',
              style: TextStyle(fontSize: 14, height: 1.35, color: PawPartyColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/profile'),
              child: const Text('Open Profile'),
            ),
          ],
        ),
      );
    }

    final postsAsync = ref.watch(neighborhoodNewsPostsProvider);
    return postsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_outlined, size: 20, color: PawPartyColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Area newsletter',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      error: (err, st) => const SizedBox.shrink(),
      data: (posts) {
        final preview = posts.take(3).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.forum_outlined, size: 20, color: PawPartyColors.primary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Area newsletter',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/neighborhood-news'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: Text(
                      posts.isEmpty ? 'Open' : 'See all (${posts.length})',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (preview.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'No posts in the last 30 days. Share a tip, lost/found pet, or event with neighbors.',
                    style: TextStyle(fontSize: 14, height: 1.35, color: PawPartyColors.textSecondary),
                  ),
                )
              else
                ...preview.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _AreaNewsletterPreviewTile(post: p),
                  ),
                ),
              if (isFirebaseInitialized)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.push('/neighborhood-news/new'),
                    icon: const Icon(Icons.post_add_outlined, size: 18),
                    label: const Text('Post an update'),
                    style: TextButton.styleFrom(
                      foregroundColor: PawPartyColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String name,
    String areaLabel,
    String? photoUrl, {
    required int myPartiesCount,
    required int invitationsCount,
  }) {
    final trimmed = photoUrl?.trim() ?? '';
    final hasPhoto = trimmed.isNotEmpty;
    const avatarRadius = 34.0;

    Widget partyStat({
      required int count,
      required String label,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PawPartyColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: PawPartyColors.primary,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
                  child: hasPhoto
                      ? ClipOval(
                          child: PawFileOrNetworkImage(
                            path: trimmed,
                            width: avatarRadius * 2,
                            height: avatarRadius * 2,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.person, size: avatarRadius * 1.15, color: PawPartyColors.primary),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 17, color: PawPartyColors.textSecondary),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      areaLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  partyStat(
                    count: myPartiesCount,
                    label: 'My Parties',
                    onTap: () => context.push('/my-parties'),
                  ),
                  const SizedBox(width: 8),
                  partyStat(
                    count: invitationsCount,
                    label: 'Invitations',
                    onTap: () => context.push('/party-invitations'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildFriendsSection(
    BuildContext context,
    WidgetRef ref,
    UserProfile? user,
  ) {
    final friendUids = user?.friendUids ?? [];
    final hasUnread = ref.watch(hasUnreadMessagesProvider);
    const friendsActionIconSize = 28.0;
    final friendsActionStyle = IconButton.styleFrom(
      backgroundColor: PawPartyColors.primary.withValues(alpha: 0.1),
      foregroundColor: PawPartyColors.primary,
      padding: const EdgeInsets.all(10),
      minimumSize: const Size(48, 48),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Friends', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/messenger'),
                tooltip: 'Messages',
                style: friendsActionStyle,
                icon: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: friendsActionIconSize, color: PawPartyColors.primary),
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -4,
                        child: Container(
                          width: 12,
                          height: 12,
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
              if (user != null)
                IconButton(
                  onPressed: () => _showShoutDialog(context, ref, user),
                  tooltip: 'Shout to friends',
                  style: friendsActionStyle,
                  icon: Icon(Icons.campaign_outlined, size: friendsActionIconSize, color: PawPartyColors.primary),
                ),
              IconButton(
                onPressed: () => context.push('/friends'),
                tooltip: 'Manage friends',
                style: friendsActionStyle,
                icon: Icon(Icons.manage_accounts_outlined, size: friendsActionIconSize, color: PawPartyColors.primary),
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
                  Icon(Icons.people_outline, size: 22, color: PawPartyColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No friends yet — discover pets nearby to connect.',
                      style: TextStyle(fontSize: 14, color: PawPartyColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Discover'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 68,
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
                  Text('Events nearby', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/discover', extra: 2),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
          Icon(icon, size: 20, color: PawPartyColors.primary),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
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
            child: PartyInviteCard(invite: invite),
          );
        }).toList(),
      ),
    );
  }

}

String _areaNewsletterPreviewLine(NeighborhoodNewsPost p) {
  final title = p.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final body = p.body.trim();
  if (body.isNotEmpty) {
    return body.length > 72 ? '${body.substring(0, 72)}…' : body;
  }
  if (p.photoUrls.isNotEmpty) return 'Photo post';
  if (p.videoUrls.isNotEmpty) return 'Video post';
  return 'Neighborhood update';
}

class _AreaNewsletterPreviewTile extends StatelessWidget {
  const _AreaNewsletterPreviewTile({required this.post});

  final NeighborhoodNewsPost post;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final cat = post.newsCategory;
    final thumb = post.photoUrls.isNotEmpty ? post.photoUrls.first.trim() : '';

    return Material(
      color: PawPartyColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(
          '/neighborhood-news/post/${post.id}',
          extra: post,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumb.isNotEmpty
                    ? PawFileOrNetworkImage(
                        path: thumb,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PawPartyColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(cat.icon, color: PawPartyColors.primary, size: 22),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _areaNewsletterPreviewLine(post),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.authorDisplayName} · ${df.format(post.createdAt)} · ${cat.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: PawPartyColors.textHint),
            ],
          ),
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
                        fontSize: 15,
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr${distLabel.isNotEmpty ? ' · $distLabel' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (meetup.hostName.isNotEmpty)
                  Text(
                    meetup.hostName.split(' ').first,
                    style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
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
              'Sends one group chat to all friends. The message starts with their names (comma-separated), then your text.',
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
