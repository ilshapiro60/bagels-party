import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/connection_invite.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_invite_repository.dart';

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
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your friend\'s email address.')),
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
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invite sent to $email. They must sign in with that Google/email account to accept.',
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final invitesAsync = ref.watch(_incomingInvitesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Invite someone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Use the same email they use for Google or email sign-in on Bagel\'s Party.',
            style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Friend\'s email',
              border: OutlineInputBorder(),
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
