import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/party_invite.dart';
import '../providers/app_providers.dart';
import '../services/firestore_meetup_repository.dart';

class PartyInviteCard extends ConsumerStatefulWidget {
  const PartyInviteCard({super.key, required this.invite});

  final PartyInvite invite;

  @override
  ConsumerState<PartyInviteCard> createState() => _PartyInviteCardState();
}

class _PartyInviteCardState extends ConsumerState<PartyInviteCard> {
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

  String _statusLine(PartyInviteStatus s) {
    switch (s) {
      case PartyInviteStatus.pending:
        return 'Awaiting your response';
      case PartyInviteStatus.accepted:
        return 'You accepted this invite';
      case PartyInviteStatus.declined:
        return 'You declined';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invite;
    final pending = inv.status == PartyInviteStatus.pending;

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
            const SizedBox(height: 4),
            Text(
              _statusLine(inv.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PawPartyColors.textHint,
              ),
            ),
            if (pending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _respond(PartyInviteStatus.declined),
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
                      onPressed: _busy ? null : () => _respond(PartyInviteStatus.accepted),
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
          ],
        ),
      ),
    );
  }
}
