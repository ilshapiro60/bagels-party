import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/direct_message.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_message_repository.dart';
import '../../widgets/paw_file_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.friendUid});

  final String friendUid;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _conversationId;
  bool _initializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final myUid = ref.read(authStateProvider).user?.id;
    if (myUid == null) return;
    try {
      final convId = await FirestoreMessageRepository.ensureConversation(
        myUid,
        widget.friendUid,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = convId;
        _initializing = false;
      });
      FirestoreMessageRepository.markConversationRead(convId, myUid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversationId == null) return;
    final myUid = ref.read(authStateProvider).user?.id;
    if (myUid == null) return;

    _controller.clear();
    await FirestoreMessageRepository.sendMessage(
      conversationId: _conversationId!,
      fromUid: myUid,
      body: text,
    );
    _scrollToBottom();
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
    final friendProfile = ref.watch(ownerProfileProvider(widget.friendUid));
    final friendName = friendProfile.when(
      data: (p) => p.displayName,
      loading: () => 'Friend',
      error: (_, _) => 'Friend',
    );
    final friendPhoto = friendProfile.when<String?>(
      data: (p) => p.photoUrl,
      loading: () => null,
      error: (_, _) => null,
    );
    final myUid = ref.watch(authStateProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
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
        ),
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
                Expanded(child: _buildMessageList(myUid)),
                _buildInputBar(),
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
                'No messages yet — say hi!',
                style: TextStyle(color: PawPartyColors.textSecondary),
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
                _MessageBubble(message: msg, isMine: isMine),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: PawPartyColors.surface,
          border: Border(top: BorderSide(color: PawPartyColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: PawPartyColors.surfaceVariant,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _send,
              icon: const Icon(Icons.send, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: PawPartyColors.primary,
                foregroundColor: Colors.white,
              ),
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
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
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
            Text(
              message.body,
              style: TextStyle(
                fontSize: 15,
                color: isMine ? Colors.white : PawPartyColors.textPrimary,
                height: 1.35,
              ),
            ),
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
