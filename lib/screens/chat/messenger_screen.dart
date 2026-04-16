import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/direct_message.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_message_repository.dart';
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
        'Pick one friend for DM, or several for a group',
        style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
      ),
      onTap: () => _showFriendPicker(context, myUid),
    );
  }

  Future<void> _showFriendPicker(BuildContext context, String myUid) async {
    final existingDmOthers = existingConvos
        .where((c) => !c.isGroupChat)
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ComposeRecipientsSheet(
        navigatorContext: context,
        myUid: myUid,
        friendProfiles: profiles,
        existingDmOthers: existingDmOthers,
      ),
    );
  }
}

Future<String> _commaSeparatedOtherNames(Conversation c, String myUid) async {
  final others = c.otherParticipantUids(myUid);
  if (others.isEmpty) return 'Group chat';
  final names = <String>[];
  for (final id in others.take(6)) {
    final p = await FirestoreProfileRepository.fetchProfile(id);
    final n = p?.displayName.trim();
    names.add(n != null && n.isNotEmpty ? n : 'Member');
  }
  if (others.length > names.length) {
    return '${names.join(', ')} (+${others.length - names.length})';
  }
  return names.join(', ');
}

class _ComposeRecipientsSheet extends StatefulWidget {
  const _ComposeRecipientsSheet({
    required this.navigatorContext,
    required this.myUid,
    required this.friendProfiles,
    required this.existingDmOthers,
  });

  final BuildContext navigatorContext;
  final String myUid;
  final List<UserProfile> friendProfiles;
  final Set<String> existingDmOthers;

  @override
  State<_ComposeRecipientsSheet> createState() => _ComposeRecipientsSheetState();
}

class _ComposeRecipientsSheetState extends State<_ComposeRecipientsSheet> {
  final Set<String> _selected = {};
  bool _busy = false;

  Future<void> _start(BuildContext sheetContext) async {
    if (_selected.isEmpty) return;
    final router = GoRouter.of(widget.navigatorContext);
    setState(() => _busy = true);
    try {
      final ids = _selected.toList();
      if (ids.length == 1) {
        if (sheetContext.mounted) Navigator.pop(sheetContext);
        if (!mounted) return;
        router.push('/chat/${ids.first}');
        return;
      }
      final convId = await FirestoreMessageRepository.ensureGroupConversation([
        widget.myUid,
        ...ids,
      ]);
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (!mounted) return;
      router.push('/conversation/$convId');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'New message',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'One friend: direct chat. Multiple: group chat with everyone.',
                style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.friendProfiles.isEmpty
                  ? Center(
                      child: Text(
                        'No friends yet.',
                        style: TextStyle(color: PawPartyColors.textHint),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: widget.friendProfiles.length,
                      itemBuilder: (_, i) {
                        final p = widget.friendProfiles[i];
                        final sel = _selected.contains(p.id);
                        final hasDm = widget.existingDmOthers.contains(p.id);
                        return ListTile(
                          onTap: _busy
                              ? null
                              : () {
                                  setState(() {
                                    if (sel) {
                                      _selected.remove(p.id);
                                    } else {
                                      _selected.add(p.id);
                                    }
                                  });
                                },
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
                          subtitle: hasDm
                              ? Text(
                                  'Has DM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: PawPartyColors.textHint,
                                  ),
                                )
                              : null,
                          trailing: Checkbox(
                            value: sel,
                            onChanged: _busy
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selected.add(p.id);
                                      } else {
                                        _selected.remove(p.id);
                                      }
                                    });
                                  },
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _busy || _selected.isEmpty
                    ? null
                    : () => _start(context),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selected.length <= 1
                            ? 'Start chat'
                            : 'Start group (${_selected.length})',
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.myUid});

  final Conversation conversation;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = conversation.hasUnread(myUid);
    final df = DateFormat.MMMd().add_jm();

    if (conversation.isGroupChat) {
      return FutureBuilder<String>(
        future: _commaSeparatedOtherNames(conversation, myUid),
        builder: (context, snap) {
          final title = snap.data ?? 'Group chat';
          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.group, color: PawPartyColors.primary),
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
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            onTap: () => context.push('/conversation/${conversation.id}'),
          );
        },
      );
    }

    final otherUid = conversation.otherUid(myUid);
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
