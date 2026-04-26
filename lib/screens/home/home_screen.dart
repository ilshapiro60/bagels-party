import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/feed_item.dart';
import '../../models/meetup.dart';
import '../../models/party_invite.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/feed_provider.dart';
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
    final areaLabel = authState.user?.neighborhood ?? 'Set your area';
    final photoUrl = authState.user?.photoUrl;
    final feedItems = ref.watch(feedItemsProvider).value ?? [];

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
                  height: 220,
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
                              onTitleTap: isHost
                                  ? () => context.push(
                                        '/edit-party/${meetup.id}',
                                        extra: meetup,
                                      )
                                  : null,
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
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverList.separated(
              itemCount: feedItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, i) => _HomeFeedItem(item: feedItems[i]),
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
              GestureDetector(
                onTap: () => context.go('/discover'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 17, color: PawPartyColors.primary),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        areaLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              color: PawPartyColors.primary,
                            ),
                      ),
                    ),
                  ],
                ),
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

class _HomeFeedItem extends StatelessWidget {
  const _HomeFeedItem({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            _InlineVideoPlayer(url: item.mediaUrl)
          else
            CachedNetworkImage(
              imageUrl: item.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
              errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
            ),
          // bottom gradient
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
          ),
          // "Popular in" pill
          if (item.isFromOtherArea)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Popular in ${item.areaLabel}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
          // author + caption at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.caption != null && item.caption!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.caption!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({required this.url});
  final String url;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _vc;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final vc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _vc = vc;
    await vc.initialize();
    vc.setLooping(true);
    vc.setVolume(0);
    if (mounted) {
      setState(() => _ready = true);
      vc.play();
    }
  }

  @override
  void dispose() {
    final vc = _vc;
    _vc = null;
    _ready = false;
    vc?.pause();
    vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _vc == null) {
      return const ColoredBox(color: Color(0xFF1A1A1A));
    }
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _vc!.value.isPlaying ? _vc!.pause() : _vc!.play();
        });
      },
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _vc!.value.size.width,
            height: _vc!.value.size.height,
            child: VideoPlayer(_vc!),
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
