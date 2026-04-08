import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../models/user_profile.dart';

class InviteFriendsScreen extends ConsumerStatefulWidget {
  const InviteFriendsScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  ConsumerState<InviteFriendsScreen> createState() =>
      _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends ConsumerState<InviteFriendsScreen> {
  final _selected = <String>{};
  List<UserProfile>? _friends;
  /// Friends who already have a pending or accepted invite for this party.
  Set<String> _alreadyInvited = {};
  bool _loading = true;
  bool _sending = false;

  void _leaveInviteScreen() {
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final profiles = <UserProfile>[];
    for (final uid in user.friendUids) {
      final p = await FirestoreProfileRepository.fetchProfile(uid);
      if (p != null) profiles.add(p);
    }
    profiles.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    try {
      _alreadyInvited = await FirestoreMeetupRepository.guestIdsWithActiveInvite(
        meetupId: widget.meetupId,
        hostId: user.id,
      );
    } catch (_) {
      _alreadyInvited = {};
    }
    if (mounted) {
      setState(() {
        _friends = profiles;
        _loading = false;
      });
    }
  }

  Future<void> _sendInvites() async {
    if (_selected.isEmpty || _sending) return;
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final guests = _selected.map((uid) {
        final friend = _friends!.firstWhere((f) => f.id == uid);
        return (uid: uid, displayName: friend.displayName);
      }).toList();

      final meetup =
          await FirestoreMeetupRepository.fetchMeetup(widget.meetupId);
      final title = meetup?.title ?? 'a party';

      await FirestoreMeetupRepository.sendPartyInvites(
        meetupId: widget.meetupId,
        meetupTitle: title,
        hostId: user.id,
        hostName: user.displayName,
        guests: guests,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invited ${guests.length} friend${guests.length > 1 ? "s" : ""}!',
          ),
          backgroundColor: PawPartyColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _leaveInviteScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send invites: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Friends'),
        actions: [
          TextButton(
            onPressed: _leaveInviteScreen,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends == null || _friends!.isEmpty
              ? _buildEmptyState()
              : _buildFriendsList(),
      bottomNavigationBar: (_friends != null && _friends!.isNotEmpty)
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: PawPartyColors.textHint),
            const SizedBox(height: 16),
            Text(
              'No connections yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Send paw buddy requests on the Discover tab to build your friend list, then invite them to parties.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PawPartyColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _leaveInviteScreen,
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _friends!.length,
      itemBuilder: (context, i) {
        final friend = _friends![i];
        final already = _alreadyInvited.contains(friend.id);
        final isSelected = _selected.contains(friend.id);
        return CheckboxListTile(
          value: isSelected,
          onChanged: already
              ? null
              : (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(friend.id);
                    } else {
                      _selected.remove(friend.id);
                    }
                  });
                },
          secondary: CircleAvatar(
            backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
            child: Text(
              friend.displayName.isNotEmpty
                  ? friend.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: PawPartyColors.primary,
              ),
            ),
          ),
          title: Text(friend.displayName),
          subtitle: Text(
            already ? 'Already invited' : (friend.neighborhood ?? 'Nearby'),
            style: TextStyle(
              fontSize: 12,
              color: already ? PawPartyColors.primary : PawPartyColors.textSecondary,
              fontWeight: already ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _selected.isNotEmpty && !_sending ? _sendInvites : null,
            child: _sending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _selected.isEmpty
                        ? 'Select friends to invite'
                        : 'Send ${_selected.length} invite${_selected.length > 1 ? "s" : ""}',
                  ),
          ),
        ),
      ),
    );
  }
}
