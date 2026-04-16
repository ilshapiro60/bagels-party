import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/party_invite_card.dart';

class PartyInvitationsListScreen extends ConsumerWidget {
  const PartyInvitationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(futureIncomingPartyInvitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load invitations: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (invites) {
          if (invites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No upcoming invitations.\nWhen a neighbor invites you to a future party, it will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PawPartyColors.textSecondary, height: 1.4),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: invites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => PartyInviteCard(invite: invites[i]),
          );
        },
      ),
    );
  }
}
