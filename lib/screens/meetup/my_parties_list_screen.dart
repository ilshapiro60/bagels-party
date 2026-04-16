import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../models/party_invite.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_passport_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../widgets/meetup_card.dart';

class MyPartiesListScreen extends ConsumerWidget {
  const MyPartiesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetupsAsync = ref.watch(futureHostedMeetupsProvider);
    final userId = ref.watch(authStateProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My parties'),
      ),
      body: meetupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load parties: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (meetups) {
          if (meetups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You have no upcoming parties you are hosting.\nTap Discover, then Events, to explore or host one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PawPartyColors.textSecondary, height: 1.4),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: meetups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final meetup = meetups[index];
              final isHost = userId != null && meetup.hostId == userId;
              return Center(
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
                          if (list.isEmpty) return 'No invites — tap Invite';
                          final acc = list
                              .where((i) => i.status == PartyInviteStatus.accepted)
                              .length;
                          final pend =
                              list.where((i) => i.status == PartyInviteStatus.pending).length;
                          final dec =
                              list.where((i) => i.status == PartyInviteStatus.declined).length;
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
                          ? () => context.push('/party-guests/${meetup.id}')
                          : null,
                      onHostDelete: (m) => _confirmDeleteHostedParty(context, ref, m),
                      onHostInviteMore: isHost
                          ? () => context.push('/invite-friends/${meetup.id}')
                          : null,
                      onHostManageGuests: isHost
                          ? () => context.push('/party-guests/${meetup.id}')
                          : null,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
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
