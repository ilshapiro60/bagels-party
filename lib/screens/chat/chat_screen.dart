import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme.dart';
import '../../models/direct_message.dart';
import '../../models/pet_buddy_owner_mute.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_chat_safety_repository.dart';
import '../../services/firestore_message_repository.dart';
import '../../services/firestore_pet_buddy_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../services/local_media.dart';
import '../../services/profile_persistence.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_fullscreen_photo_viewer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  /// 1:1 DM with a friend (deterministic conversation id).
  const ChatScreen.friend({super.key, required this.friendUid}) : conversationId = null;

  /// Open an existing conversation by Firestore doc id (DM or group).
  const ChatScreen.conversation({super.key, required this.conversationId})
      : friendUid = null;

  final String? friendUid;
  final String? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _conversationId;
  bool _initializing = true;
  String? _initError;
  final _pendingMediaUrls = <String>[];
  bool _busyUpload = false;
  bool _sending = false;
  int _participantCount = 2;
  List<String> _otherParticipantIds = [];
  /// Comma-separated names for group / conversation-by-id app bar (null for 1:1 friend route).
  String? _conversationTitle;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final myUid = ref.read(authStateProvider).user?.id;
    if (myUid == null) return;
    final cid = widget.conversationId;
    if (cid != null) {
      try {
        final parts = await FirestoreMessageRepository.fetchParticipantIds(cid);
        if (!parts.contains(myUid)) {
          throw StateError('You are not in this conversation.');
        }
        final others = parts.where((u) => u != myUid).toList();
        final title = await _loadCommaSeparatedNames(others);
        if (!mounted) return;
        setState(() {
          _conversationId = cid;
          _participantCount = parts.length;
          _otherParticipantIds = others;
          _conversationTitle = title;
          _initializing = false;
        });
        await FirestoreMessageRepository.markConversationRead(cid, myUid);
        unawaited(FirestoreMessageRepository.pruneExpiredMessages(cid));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _initError = e.toString();
          _initializing = false;
        });
      }
      return;
    }

    final fid = widget.friendUid!;
    try {
      final convId = await FirestoreMessageRepository.ensureConversation(myUid, fid);
      if (!mounted) return;
      setState(() {
        _conversationId = convId;
        _participantCount = 2;
        _otherParticipantIds = [fid];
        _conversationTitle = null;
        _initializing = false;
      });
      FirestoreMessageRepository.markConversationRead(convId, myUid);
      unawaited(FirestoreMessageRepository.pruneExpiredMessages(convId));
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString();
      if (e is FirebaseException && e.code == 'permission-denied') {
        msg =
            'Messaging is not available. This can happen when there is a block between accounts.';
      }
      setState(() {
        _initError = msg;
        _initializing = false;
      });
    }
  }

  Future<String> _loadCommaSeparatedNames(List<String> uids) async {
    if (uids.isEmpty) return 'Chat';
    final names = <String>[];
    for (final id in uids.take(8)) {
      final p = await FirestoreProfileRepository.fetchProfile(id);
      final n = p?.displayName.trim();
      names.add(n != null && n.isNotEmpty ? n : 'Member');
    }
    if (uids.length > names.length) {
      return '${names.join(', ')} (+${uids.length - names.length})';
    }
    return names.join(', ');
  }

  bool get _isGroupChat => _participantCount > 2;

  bool _isPairBlocked(String myUid, List<PetBuddyOwnerMute> mutes) {
    final fid = widget.friendUid;
    if (fid == null) return false;
    final id = FirestorePetBuddyRepository.ownerMuteDocId(myUid, fid);
    return mutes.any((m) => m.docId == id);
  }

  Future<void> _refreshUser(String uid) async {
    final fresh = await FirestoreProfileRepository.fetchProfile(uid);
    if (fresh != null && mounted) {
      final merged = await ProfilePersistence.mergeWithSaved(fresh);
      ref.read(authStateProvider.notifier).updateUser(merged);
    }
  }

  Future<void> _reportConversation() async {
    final user = ref.read(authStateProvider).user;
    final convId = _conversationId;
    if (user == null || convId == null) return;
    final reason = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report conversation'),
        content: TextField(
          controller: reason,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What is going wrong? (harassment, scams, inappropriate photos, etc.)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (submitted != true || !mounted) return;

    String? snippet;
    final msgs = ref.read(messagesProvider(convId)).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    if (msgs != null && msgs.isNotEmpty) {
      final t = msgs.last.body.trim();
      if (t.isNotEmpty) {
        snippet = t.length > 120 ? '${t.substring(0, 120)}…' : t;
      }
    }

    String? reportedUid = widget.friendUid;
    if (reportedUid == null && _otherParticipantIds.isNotEmpty) {
      if (_otherParticipantIds.length == 1) {
        reportedUid = _otherParticipantIds.first;
      } else {
        if (!mounted) return;
        reportedUid = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Who are you reporting?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _otherParticipantIds.length,
                  itemBuilder: (ctx, i) {
                    final uid = _otherParticipantIds[i];
                    return FutureBuilder<UserProfile?>(
                      future: FirestoreProfileRepository.fetchProfile(uid),
                      builder: (ctx, snap) {
                        final p = snap.data;
                        final label = (p?.displayName ?? '').trim().isNotEmpty
                            ? p!.displayName.trim()
                            : 'Member';
                        return ListTile(
                          title: Text(label),
                          subtitle: Text(uid, style: const TextStyle(fontSize: 11)),
                          onTap: () => Navigator.pop(ctx, uid),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
        if (reportedUid == null || !mounted) return;
      }
    }
    if (reportedUid == null) return;

    try {
      await FirestoreChatSafetyRepository.submitReport(
        reporter: user,
        conversationId: convId,
        reportedUid: reportedUid,
        reason: reason.text,
        contextSnippet: snippet,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks — moderators will review.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _blockUser() async {
    final fid = widget.friendUid;
    if (fid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'This removes your connection, breaks paw buddy links between your pets, '
          'stops new buddy requests, and stops both of you from sending messages here '
          'until someone unblocks from Friends.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PawPartyColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestoreProfileRepository.removeFriend(uid: uid, friendUid: fid);
      await FirestorePetBuddyRepository.muteBuddyOwners(
        actingUid: uid,
        otherOwnerId: fid,
      );
      await _refreshUser(uid);
      ref.invalidate(petBuddyOwnerMutesProvider);
      for (final p in ref.read(userPetsProvider)) {
        ref.invalidate(buddyPetsForPetProvider(p.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not block: $e')),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_conversationId == null || _busyUpload || _sending) return;
    final myUid = ref.read(authStateProvider).user?.id;
    if (myUid == null) return;
    final mutes = ref.read(petBuddyOwnerMutesProvider).maybeWhen(
          data: (v) => v,
          orElse: () => const <PetBuddyOwnerMute>[],
        );
    if (_isPairBlocked(myUid, mutes)) return;

    final text = _controller.text.trim();
    final media = List<String>.from(_pendingMediaUrls);
    if (text.isEmpty && media.isEmpty) return;

    final savedText = text;
    _controller.clear();
    setState(() {
      _pendingMediaUrls.clear();
      _sending = true;
    });

    try {
      await FirestoreMessageRepository.sendMessage(
        conversationId: _conversationId!,
        fromUid: myUid,
        body: savedText,
        mediaUrls: media,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
        setState(() {
          _controller.text = savedText;
          _pendingMediaUrls.addAll(media);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addPhotoFrom(ImageSource source) async {
    if (_conversationId == null || _busyUpload) return;
    final myUid = ref.read(authStateProvider).user?.id;
    if (myUid == null) return;

    if (_pendingMediaUrls.length >= FirestoreMessageRepository.maxMediaUrlsPerMessage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can attach up to ${FirestoreMessageRepository.maxMediaUrlsPerMessage} photos per message.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _busyUpload = true);
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 88,
      );
      if (x == null || !mounted) return;
      final local = await persistPickedFile(x);
      if (local == null || !mounted) return;

      final objectPath =
          'users/$myUid/messages/${_conversationId}_${const Uuid().v4()}${extensionForPath(local)}';
      final url = await FirebaseStorageService.instance.uploadLocalPath(
        localPath: local,
        storageRelativePath: objectPath,
        allowLocalFallback: false,
      );
      if (!mounted) return;
      setState(() => _pendingMediaUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUpload = false);
    }
  }

  String extensionForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    return '.jpg';
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhotoFrom(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhotoFrom(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fid = widget.friendUid;
    final friendProfile =
        fid != null ? ref.watch(ownerProfileProvider(fid)) : null;
    final friendName = friendProfile?.when(
          data: (p) => p.displayName,
          loading: () => 'Friend',
          error: (_, _) => 'Friend',
        ) ??
        'Friend';
    final friendPhoto = friendProfile?.when<String?>(
      data: (p) => p.photoUrl,
      loading: () => null,
      error: (_, _) => null,
    );
    final myUid = ref.watch(authStateProvider).user?.id;
    final mutesAsync = ref.watch(petBuddyOwnerMutesProvider);
    final isDmBlocked = fid != null &&
        myUid != null &&
        mutesAsync.maybeWhen(
          data: (mutes) => _isPairBlocked(myUid, mutes),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: fid != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
                    child: friendPhoto != null && friendPhoto.isNotEmpty
                        ? ClipOval(
                            child: PawFileOrNetworkImage(
                              path: friendPhoto,
                              width: 36,
                              height: 36,
                            ),
                          )
                        : Text(
                            friendName.isNotEmpty ? friendName[0] : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: PawPartyColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      friendName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      _isGroupChat ? Icons.group : Icons.person,
                      color: PawPartyColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _conversationTitle ?? (_isGroupChat ? 'Group chat' : 'Chat'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') _reportConversation();
              if (v == 'block') _blockUser();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'report', child: Text('Report…')),
              if (fid != null)
                const PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: PawPartyColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Could not open chat',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _initError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _initializing = true;
                              _initError = null;
                            });
                            _initConversation();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                      child: Text(
                        'Messages are kept for ${FirestoreMessageRepository.messageRetention.inDays} days.',
                        style: TextStyle(fontSize: 11, color: PawPartyColors.textHint),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (isDmBlocked)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: PawPartyColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PawPartyColors.error.withValues(alpha: 0.35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(
                              'You have a block with this person. Messaging is disabled until '
                              'someone removes the block under Friends → Paw buddy blocks.',
                              style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary, height: 1.35),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    Expanded(child: _buildMessageList(myUid)),
                    _buildInputBar(isDmBlocked: isDmBlocked),
                  ],
                ),
    );
  }

  Widget _buildMessageList(String? myUid) {
    if (_conversationId == null) return const SizedBox.shrink();
    final messagesAsync = ref.watch(messagesProvider(_conversationId!));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No messages yet — say hi or tap + to send a photo.\n'
                'Only the last ${FirestoreMessageRepository.messageRetention.inDays} days are kept.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PawPartyColors.textSecondary, height: 1.35),
              ),
            ),
          );
        }
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            final isMine = msg.fromUid == myUid;
            final showDate = i == 0 ||
                !_sameDay(messages[i - 1].createdAt, msg.createdAt);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate)
                  _DateSeparator(date: msg.createdAt),
                if (_isGroupChat && !isMine && myUid != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final asyncP = ref.watch(ownerProfileProvider(msg.fromUid));
                      final label = asyncP.when(
                        data: (p) {
                          final n = p.displayName.trim();
                          return n.isNotEmpty ? n : 'Member';
                        },
                        loading: () => '…',
                        error: (_, _) => 'Member',
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 2),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: PawPartyColors.textSecondary,
                              ),
                            ),
                          ),
                          _MessageBubble(message: msg, isMine: isMine),
                        ],
                      );
                    },
                  )
                else
                  _MessageBubble(message: msg, isMine: isMine),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar({required bool isDmBlocked}) {
    if (isDmBlocked) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            'Sending is turned off because of a mutual block.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
          ),
        ),
      );
    }

    final canSend = !_busyUpload &&
        !_sending &&
        (_controller.text.trim().isNotEmpty || _pendingMediaUrls.isNotEmpty);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: PawPartyColors.surface,
          border: Border(top: BorderSide(color: PawPartyColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pendingMediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                child: SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pendingMediaUrls.length,
                    separatorBuilder: (_, unused) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final u = _pendingMediaUrls[i];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: PawFileOrNetworkImage(
                              path: u,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Material(
                              color: PawPartyColors.error,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => _pendingMediaUrls.removeAt(i)),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Add photo',
                  onPressed: _busyUpload ? null : _showAttachSheet,
                  icon: _busyUpload
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.add_photo_alternate_outlined,
                          color: PawPartyColors.primary),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _pendingMediaUrls.isEmpty
                          ? 'Message…'
                          : 'Add a caption (optional)…',
                      filled: true,
                      fillColor: PawPartyColors.surfaceVariant,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (canSend) _send();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: canSend ? _send : null,
                  icon: const Icon(Icons.send, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: PawPartyColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (_sameDay(date, now)) {
      label = 'Today';
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final DirectMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(message.createdAt);
    final media = message.mediaUrls;
    final bodyText = message.body.trim();
    final maxImgW = MediaQuery.sizeOf(context).width * 0.62;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? PawPartyColors.primary
              : PawPartyColors.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.isShout)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign,
                        size: 14,
                        color: isMine ? Colors.white70 : PawPartyColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Shout',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMine ? Colors.white70 : PawPartyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (media.isNotEmpty)
              for (var i = 0; i < media.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: GestureDetector(
                    onTap: () => showPawFullscreenPhotos(
                      context,
                      urls: media,
                      initialIndex: i,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isMine
                                ? Colors.white24
                                : PawPartyColors.divider,
                          ),
                        ),
                        child: PawFileOrNetworkImage(
                          path: media[i],
                          width: maxImgW,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            if (bodyText.isNotEmpty) ...[
              if (media.isNotEmpty) const SizedBox(height: 8),
              Text(
                message.body,
                style: TextStyle(
                  fontSize: 15,
                  color: isMine ? Colors.white : PawPartyColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.65)
                    : PawPartyColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
