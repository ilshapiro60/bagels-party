import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/party_invite.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_meetup_repository.dart';

class ManagePartyGuestsScreen extends ConsumerStatefulWidget {
  const ManagePartyGuestsScreen({
    super.key,
    required this.meetupId,
  });

  final String meetupId;

  @override
  ConsumerState<ManagePartyGuestsScreen> createState() =>
      _ManagePartyGuestsScreenState();
}

class _ManagePartyGuestsScreenState extends ConsumerState<ManagePartyGuestsScreen> {
  String? _title;
  bool _loadingMeetup = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMeetup();
  }

  Future<void> _loadMeetup() async {
    try {
      final m = await FirestoreMeetupRepository.fetchMeetup(widget.meetupId);
      final uid = ref.read(authStateProvider).user?.id;
      if (!mounted) return;
      if (m == null) {
        setState(() {
          _loadingMeetup = false;
          _loadError = 'This party was not found.';
        });
        return;
      }
      if (uid == null || m.hostId != uid) {
        setState(() {
          _loadingMeetup = false;
          _loadError = 'Only the host can manage guests for this party.';
        });
        return;
      }
      setState(() {
        _title = m.title;
        _loadingMeetup = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMeetup = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _confirmRemove(PartyInvite invite) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove invite?'),
        content: Text(
          '${invite.guestName} will be removed from this party’s guest list. '
          'They can be invited again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PawPartyColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await FirestoreMeetupRepository.deletePartyInvite(
        inviteId: invite.id,
        actingHostId: uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest removed from the list.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  String _statusLabel(PartyInviteStatus s) {
    switch (s) {
      case PartyInviteStatus.pending:
        return 'Pending';
      case PartyInviteStatus.accepted:
        return 'Accepted';
      case PartyInviteStatus.declined:
        return 'Declined';
    }
  }

  Color _statusColor(PartyInviteStatus s) {
    switch (s) {
      case PartyInviteStatus.pending:
        return PawPartyColors.pizzaGold;
      case PartyInviteStatus.accepted:
        return PawPartyColors.success;
      case PartyInviteStatus.declined:
        return PawPartyColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).user?.id;

    if (_loadingMeetup) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guests')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guests')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final invitesAsync = ref.watch(
      partyInvitesForHostedMeetupProvider((
        meetupId: widget.meetupId,
        hostId: uid!,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? 'Guests'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/invite-friends/${widget.meetupId}'),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Invite'),
          ),
        ],
      ),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load guests: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (invites) {
          if (invites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 56, color: PawPartyColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      'No invites yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Invite friends so they can accept and see your party details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawPartyColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/invite-friends/${widget.meetupId}'),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Invite friends'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sorted = [...invites]..sort((a, b) {
              final o = {
                PartyInviteStatus.pending: 0,
                PartyInviteStatus.accepted: 1,
                PartyInviteStatus.declined: 2,
              };
              final c = o[a.status]!.compareTo(o[b.status]!);
              if (c != 0) return c;
              return b.sentAt.compareTo(a.sentAt);
            });

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final inv = sorted[i];
              return ListTile(
                title: Text(inv.guestName),
                subtitle: Text(
                  'Sent ${_formatSent(inv.sentAt)}',
                  style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(inv.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(inv.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(inv.status),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: PawPartyColors.error),
                      tooltip: 'Remove invite',
                      onPressed: () => _confirmRemove(inv),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatSent(DateTime t) {
    final now = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'today';
    if (d == today.subtract(const Duration(days: 1))) return 'yesterday';
    return '${t.month}/${t.day}/${t.year}';
  }
}
