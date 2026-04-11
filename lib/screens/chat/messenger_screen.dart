import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/direct_message.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_profile_repository.dart';
import '../../widgets/paw_file_image.dart';

class MessengerScreen extends ConsumerWidget {
  const MessengerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).user?.id;
    final convosAsync = ref.watch(conversationsProvider);
    final friendUids = ref.watch(authStateProvider).user?.friendUids ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: convosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (convos) {
          if (convos.isEmpty && friendUids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 56, color: PawPartyColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet.\nAdd friends to start messaging!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawPartyColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (friendUids.isNotEmpty)
                _NewConversationButton(
                  friendUids: friendUids,
                  existingConvos: convos,
                  myUid: uid ?? '',
                ),
              ...convos.map((c) => _ConversationTile(
                    conversation: c,
                    myUid: uid ?? '',
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _NewConversationButton extends StatelessWidget {
  const _NewConversationButton({
    required this.friendUids,
    required this.existingConvos,
    required this.myUid,
  });

  final List<String> friendUids;
  final List<Conversation> existingConvos;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: PawPartyColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: PawPartyColors.primary),
      ),
      title: const Text('New message'),
      subtitle: Text(
        'Start a conversation with a friend',
        style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
      ),
      onTap: () => _showFriendPicker(context),
    );
  }

  Future<void> _showFriendPicker(BuildContext context) async {
    final existingOtherUids = existingConvos
        .map((c) => c.otherUid(myUid))
        .toSet();

    final profiles = <UserProfile>[];
    for (final uid in friendUids) {
      try {
        final p = await FirestoreProfileRepository.fetchProfile(uid);
        if (p != null) profiles.add(p);
      } catch (_) {}
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select a friend',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: profiles.isEmpty
                  ? Center(
                      child: Text(
                        'No friends yet.',
                        style: TextStyle(color: PawPartyColors.textHint),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: profiles.length,
                      itemBuilder: (_, i) {
                        final p = profiles[i];
                        final hasConvo = existingOtherUids.contains(p.id);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                PawPartyColors.primary.withValues(alpha: 0.15),
                            child: p.photoUrl != null && p.photoUrl!.isNotEmpty
                                ? ClipOval(
                                    child: PawFileOrNetworkImage(
                                      path: p.photoUrl!,
                                      width: 40,
                                      height: 40,
                                    ),
                                  )
                                : const Icon(Icons.person,
                                    color: PawPartyColors.primary),
                          ),
                          title: Text(p.displayName),
                          trailing: hasConvo
                              ? Text('Active',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: PawPartyColors.textHint))
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/chat/${p.id}');
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.myUid});

  final Conversation conversation;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = conversation.otherUid(myUid);
    final hasUnread = conversation.hasUnread(myUid);
    final df = DateFormat.MMMd().add_jm();

    return FutureBuilder<UserProfile?>(
      future: FirestoreProfileRepository.fetchProfile(otherUid),
      builder: (context, snap) {
        final friend = snap.data;
        final name = friend?.displayName ?? 'User';
        final photo = friend?.photoUrl;
        final hasPhoto = photo != null && photo.isNotEmpty;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
                child: hasPhoto
                    ? ClipOval(
                        child: PawFileOrNetworkImage(
                          path: photo,
                          width: 44,
                          height: 44,
                        ),
                      )
                    : const Icon(Icons.person, color: PawPartyColors.primary),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: PawPartyColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: PawPartyColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: conversation.lastMessage != null
              ? Text(
                  conversation.lastMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasUnread
                        ? PawPartyColors.textPrimary
                        : PawPartyColors.textHint,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                )
              : null,
          trailing: Text(
            df.format(conversation.lastUpdated),
            style: TextStyle(fontSize: 11, color: PawPartyColors.textHint),
          ),
          onTap: () => context.push('/chat/$otherUid'),
        );
      },
    );
  }
}
