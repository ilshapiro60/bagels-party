import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/connection_invite.dart';
import '../../models/pet.dart';
import '../../models/pet_buddy_request.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_invite_repository.dart';
import '../../services/firestore_pet_buddy_repository.dart';
import '../../services/firestore_pet_repository.dart';
import '../../services/firestore_profile_repository.dart';

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

final _incomingInvitesProvider = StreamProvider<List<ConnectionInvite>>((ref) {
  final email = ref.watch(authStateProvider).user?.email;
  return FirestoreInviteRepository.watchIncoming(email);
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  String? _selectedPetId;
  bool _sending = false;

  Pet? _petForSelection(
    List<(Pet pet, String ownerLabel)> options,
    String? petId,
  ) {
    if (petId == null) return null;
    for (final o in options) {
      if (o.$1.id == petId) return o.$1;
    }
    return null;
  }

  Future<void> _sendInvite() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final options = ref.read(friendsPetInviteOptionsProvider).value;
    if (options == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still loading your friends\' pets.')),
      );
      return;
    }
    final chosen = _petForSelection(options, _selectedPetId);
    if (chosen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a pet from your friends list.')),
      );
      return;
    }
    if (!user.friendUids.contains(chosen.ownerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only invite using pets from your connections.'),
        ),
      );
      return;
    }
    final profile = await FirestoreProfileRepository.fetchProfile(chosen.ownerId);
    final email = profile?.email.trim() ?? '';
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That friend has no email on file yet.'),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await FirestoreInviteRepository.sendInvite(
        fromUid: user.id,
        fromDisplayName: user.displayName,
        fromEmail: user.email,
        toEmail: email,
      );
      if (!mounted) return;
      setState(() => _selectedPetId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Invite sent to $email (${chosen.name}'s parent). They sign in with that account to accept.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _accept(ConnectionInvite inv) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestoreInviteRepository.acceptInvite(
        inviteId: inv.id,
        toUid: uid,
        fromUid: inv.fromUid,
      );
      await ref.read(authStateProvider.notifier).restoreSession();
      ref.invalidate(friendsPetInviteOptionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You\'re connected with ${inv.fromDisplayName}!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> _decline(ConnectionInvite inv) async {
    try {
      await FirestoreInviteRepository.declineInvite(inv.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decline failed: $e')),
      );
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
      ref.invalidate(incomingPetBuddyRequestsProvider);
      ref.invalidate(outgoingPetBuddyRequestsProvider);
      ref.invalidate(buddyPetsForPetProvider(r.fromPetId));
      ref.invalidate(buddyPetsForPetProvider(r.toPetId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paw buddies confirmed.')),
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final invitesAsync = ref.watch(_incomingInvitesProvider);
    final petBuddyIncoming = ref.watch(incomingPetBuddyRequestsProvider);
    final petBuddyOutgoing = ref.watch(outgoingPetBuddyRequestsProvider);
    final invitePetOptions = ref.watch(friendsPetInviteOptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Send a connection invite',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick one of your connections’ pets. The invite goes to that pet parent’s account email — same one they use to sign in.',
            style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
          ),
          const SizedBox(height: 12),
          invitePetOptions.when(
            data: (options) {
              if (user != null && user.friendUids.isEmpty) {
                return Text(
                  'You don’t have connections yet. When someone accepts your invite or you connect elsewhere, their pets will show up here.',
                  style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 13),
                );
              }
              if (options.isEmpty) {
                return Text(
                  'Your connections haven’t added pets yet, so there’s nothing to choose.',
                  style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 13),
                );
              }
              final selectedPet = _petForSelection(options, _selectedPetId);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Friend's pet",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pets_outlined),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Pet>(
                        isExpanded: true,
                        value: selectedPet,
                        hint: const Text('Select a pet'),
                        items: options
                            .map(
                              (o) => DropdownMenuItem<Pet>(
                                value: o.$1,
                                child: Text(
                                  '${o.$1.name} · ${o.$2}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _sending
                            ? null
                            : (Pet? p) => setState(() => _selectedPetId = p?.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _sending ? null : _sendInvite,
                    child: _sending
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send invite'),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load friends’ pets: $e',
              style: TextStyle(color: PawPartyColors.error, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Incoming invites',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          invitesAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No pending invites.',
                  style: TextStyle(color: PawPartyColors.textSecondary),
                );
              }
              return Column(
                children: list.map((inv) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.fromDisplayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'wants to connect on Bagel\'s Party',
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
                                  onPressed: () => _decline(inv),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _accept(inv),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('Error: $e'),
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
