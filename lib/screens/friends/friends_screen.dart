import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/pet.dart';
import '../../models/pet_buddy_request.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_pet_buddy_repository.dart';
import '../../services/firestore_pet_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../services/profile_persistence.dart';

String _petBuddyLoadErrorMessage(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied')) {
    return 'Pet buddy requests blocked by Firestore rules. Deploy the latest rules.';
  }
  if (s.contains('failed-precondition') || s.contains('index')) {
    return 'Firestore needs an index for pet buddy requests. Run: '
        'firebase deploy --only firestore:indexes (or use the link in the debug console).';
  }
  return 'Could not load pet buddy requests: $e';
}

class _FriendConnectionTile extends ConsumerWidget {
  const _FriendConnectionTile({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerProfileProvider(uid));
    return async.when(
      data: (p) => ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(p.displayName),
        subtitle: Text(
          p.neighborhood ?? 'Neighborhood not set',
          style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
        ),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('Loading…'),
      ),
      error: (err, _) => ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text('Friend ($uid)'),
      ),
    );
  }
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncConnectionsOnOpen());
  }

  /// Merges paw-buddy acceptances into [friendUids] (e.g. requester after remote accept).
  Future<void> _syncConnectionsOnOpen() async {
    if (!mounted) return;
    final user = ref.read(authStateProvider).user;
    if (user == null || !isFirebaseInitialized) return;
    try {
      await FirestoreProfileRepository.syncFriendsFromAcceptedPetBuddyRequests(
        user.id,
      );
      if (!mounted) return;
      final fresh = await FirestoreProfileRepository.fetchProfile(user.id);
      if (fresh != null && mounted) {
        final merged = await ProfilePersistence.mergeWithSaved(fresh);
        ref.read(authStateProvider.notifier).updateUser(merged);
      }
    } catch (_) {
      // Offline / rules: screen still usable.
    }
  }

  Future<void> _acceptPetBuddy(PetBuddyRequest r) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestorePetBuddyRepository.acceptRequest(
        requestId: r.id,
        actingUid: uid,
      );
      await FirestoreProfileRepository.syncFriendsFromAcceptedPetBuddyRequests(
        uid,
      );
      final fresh = await FirestoreProfileRepository.fetchProfile(uid);
      if (fresh != null && mounted) {
        final merged = await ProfilePersistence.mergeWithSaved(fresh);
        ref.read(authStateProvider.notifier).updateUser(merged);
      }
      ref.invalidate(incomingPetBuddyRequestsProvider);
      ref.invalidate(outgoingPetBuddyRequestsProvider);
      ref.invalidate(buddyPetsForPetProvider(r.fromPetId));
      ref.invalidate(buddyPetsForPetProvider(r.toPetId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paw buddies confirmed — you are connected as pet parents.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> _declinePetBuddy(PetBuddyRequest r) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestorePetBuddyRepository.declineRequest(
        requestId: r.id,
        actingUid: uid,
      );
      ref.invalidate(incomingPetBuddyRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buddy request declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decline failed: $e')),
      );
    }
  }

  Future<void> _cancelPetBuddyOutgoing(PetBuddyRequest r) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestorePetBuddyRepository.cancelOutgoingRequest(
        requestId: r.id,
        actingUid: uid,
      );
      ref.invalidate(outgoingPetBuddyRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buddy request withdrawn.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    }
  }

  Future<void> _unmutePetBuddyOwner(String otherOwnerId) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestorePetBuddyRepository.unmuteBuddyOwners(
        actingUid: uid,
        otherOwnerId: otherOwnerId,
      );
      for (final p in ref.read(userPetsProvider)) {
        ref.invalidate(buddyPetsForPetProvider(p.id));
      }
      ref.invalidate(petBuddyOwnerMutesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can send paw buddy requests to each other again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unblock: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final petBuddyIncoming = ref.watch(incomingPetBuddyRequestsProvider);
    final petBuddyOutgoing = ref.watch(outgoingPetBuddyRequestsProvider);
    final petBuddyMutes = ref.watch(petBuddyOwnerMutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncConnectionsOnOpen();
          ref.invalidate(incomingPetBuddyRequestsProvider);
          ref.invalidate(outgoingPetBuddyRequestsProvider);
          ref.invalidate(petBuddyOwnerMutesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
          Text(
            'Connections',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Browse nearby pets on Discover, open a profile, and tap Befriend to send a paw buddy request. '
            'When the other parent accepts, your pets are linked and you show up under each other’s connections.',
            style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/discover'),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Open Discover'),
          ),
          const SizedBox(height: 32),
          Text(
            'Pet buddy requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Another parent must accept before pets show as paw buddies.',
            style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
          ),
          const SizedBox(height: 12),
          petBuddyIncoming.when(
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No pending pet buddy requests.',
                  style: TextStyle(color: PawPartyColors.textSecondary),
                );
              }
              return Column(
                children: list
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IncomingPetBuddyCard(
                          request: r,
                          onAccept: () => _acceptPetBuddy(r),
                          onDecline: () => _declinePetBuddy(r),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => Text(
              'Loading pet buddy requests…',
              style: TextStyle(color: PawPartyColors.textSecondary),
            ),
            error: (e, _) => Text(
              _petBuddyLoadErrorMessage(e),
              style: TextStyle(color: PawPartyColors.error, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Pet buddy requests you sent',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          petBuddyOutgoing.when(
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'None waiting.',
                  style: TextStyle(color: PawPartyColors.textSecondary),
                );
              }
              return Column(
                children: list
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OutgoingPetBuddyCard(
                          request: r,
                          onCancel: () => _cancelPetBuddyOutgoing(r),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => Text(
              'Loading…',
              style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 13),
            ),
            error: (e, _) => Text(
              _petBuddyLoadErrorMessage(e),
              style: TextStyle(color: PawPartyColors.error, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Paw buddy blocks',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Parents you have blocked (or who blocked you) cannot send paw buddy requests until someone unblocks here.',
            style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
          ),
          const SizedBox(height: 12),
          petBuddyMutes.when(
            data: (mutes) {
              if (mutes.isEmpty || user == null) {
                return Text(
                  'No active paw buddy blocks.',
                  style: TextStyle(color: PawPartyColors.textSecondary),
                );
              }
              return Column(
                children: mutes.map((m) {
                  final otherId = m.otherUid(user.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: ref
                                  .watch(ownerProfileProvider(otherId))
                                  .when(
                                    data: (p) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(p.displayName),
                                      subtitle: Text(
                                        'Paw buddy requests paused',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: PawPartyColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    loading: () => const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text('Loading…'),
                                    ),
                                    error: (e, s) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text('User ($otherId)'),
                                    ),
                                  ),
                            ),
                            TextButton(
                              onPressed: () => _unmutePetBuddyOwner(otherId),
                              child: const Text('Unblock'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => Text(
              'Loading…',
              style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 13),
            ),
            error: (e, _) => Text(
              'Could not load blocks: $e',
              style: TextStyle(color: PawPartyColors.error, fontSize: 13),
            ),
          ),
          if (user != null && user.friendUids.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Your connections (${user.friendUids.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...user.friendUids.map((uid) => _FriendConnectionTile(uid: uid)),
          ],
        ],
        ),
      ),
    );
  }
}

class _IncomingPetBuddyCard extends StatefulWidget {
  const _IncomingPetBuddyCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final PetBuddyRequest request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<_IncomingPetBuddyCard> createState() => _IncomingPetBuddyCardState();
}

class _IncomingPetBuddyCardState extends State<_IncomingPetBuddyCard> {
  late Future<({Pet? from, Pet? to})> _petsFuture;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _petsFuture = Future.wait([
      FirestorePetRepository.fetchPet(r.fromOwnerId, r.fromPetId),
      FirestorePetRepository.fetchPet(r.toOwnerId, r.toPetId),
    ]).then((list) => (from: list[0], to: list[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<({Pet? from, Pet? to})>(
          future: _petsFuture,
          builder: (context, snap) {
            final from = snap.data?.from;
            final to = snap.data?.to;
            final fromName = from?.name ?? 'Their pet';
            final toName = to?.name ?? 'Your pet';
            final busy = snap.connectionState == ConnectionState.waiting;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fromName → $toName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$fromName’s parent wants a paw buddy link with $toName.',
                  style: TextStyle(
                    fontSize: 13,
                    color: PawPartyColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => widget.onDecline(),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : () => widget.onAccept(),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutgoingPetBuddyCard extends StatefulWidget {
  const _OutgoingPetBuddyCard({
    required this.request,
    required this.onCancel,
  });

  final PetBuddyRequest request;
  final Future<void> Function() onCancel;

  @override
  State<_OutgoingPetBuddyCard> createState() => _OutgoingPetBuddyCardState();
}

class _OutgoingPetBuddyCardState extends State<_OutgoingPetBuddyCard> {
  late Future<Pet?> _theirPetFuture;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _theirPetFuture =
        FirestorePetRepository.fetchPet(r.toOwnerId, r.toPetId);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Pet?>(
          future: _theirPetFuture,
          builder: (context, snap) {
            final name = snap.data?.name ?? 'their pet';
            final busy = snap.connectionState == ConnectionState.waiting;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting on $name’s parent',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'They can accept or decline under Friends.',
                        style: TextStyle(
                          fontSize: 13,
                          color: PawPartyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => widget.onCancel(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
