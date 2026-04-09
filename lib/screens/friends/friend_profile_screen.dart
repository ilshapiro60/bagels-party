import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_pet_buddy_repository.dart';
import '../../services/firestore_pet_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../services/profile_persistence.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({super.key, required this.friendUid});

  final String friendUid;

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  late Future<List<Pet>> _petsFuture;

  @override
  void initState() {
    super.initState();
    _petsFuture = FirestorePetRepository.loadForUser(widget.friendUid);
  }

  bool get _isFriend {
    final user = ref.read(authStateProvider).user;
    return user != null && user.friendUids.contains(widget.friendUid);
  }

  Future<void> _removeFriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove connection?'),
        content: const Text(
          'You will no longer appear in each other\u2019s connections. '
          'You can reconnect later via a new paw buddy request.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestoreProfileRepository.removeFriend(uid: uid, friendUid: widget.friendUid);
      await _refreshUser(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection removed.')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  Future<void> _blockUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'This will remove your connection, break any paw buddy links between your pets, '
          'and prevent either of you from sending new buddy requests until someone unblocks.',
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
      await FirestoreProfileRepository.removeFriend(uid: uid, friendUid: widget.friendUid);
      await FirestorePetBuddyRepository.muteBuddyOwners(
        actingUid: uid,
        otherOwnerId: widget.friendUid,
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

  Future<void> _refreshUser(String uid) async {
    final fresh = await FirestoreProfileRepository.fetchProfile(uid);
    if (fresh != null && mounted) {
      final merged = await ProfilePersistence.mergeWithSaved(fresh);
      ref.read(authStateProvider.notifier).updateUser(merged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(ownerProfileProvider(widget.friendUid));
    final isFriend = _isFriend;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') _removeFriend();
              if (v == 'block') _blockUser();
            },
            itemBuilder: (ctx) => [
              if (isFriend)
                const PopupMenuItem(value: 'remove', child: Text('Remove connection')),
              const PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (profile) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: profile.photoUrl != null
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: profile.photoUrl == null
                      ? Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (profile.neighborhood != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    profile.neighborhood!,
                    style: TextStyle(fontSize: 14, color: PawPartyColors.textSecondary),
                  ),
                ),
              ],
              if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: PawPartyColors.textPrimary, height: 1.4),
                ),
              ],

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: () => context.push('/chat/${widget.friendUid}'),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Send message'),
              ),

              const SizedBox(height: 28),

              Text('Pets', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              FutureBuilder<List<Pet>>(
                future: _petsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text(
                      'Could not load pets.',
                      style: TextStyle(color: PawPartyColors.textSecondary),
                    );
                  }
                  final pets = snap.data ?? [];
                  if (pets.isEmpty) {
                    return Text(
                      'No pets listed yet.',
                      style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                    );
                  }
                  return Column(
                    children: pets.map((pet) => _PetTile(pet: pet)).toList(),
                  );
                },
              ),

              const SizedBox(height: 16),

              _buildStatRow('Parties hosted', '${profile.hostCount}'),
              _buildStatRow('Parties attended', '${profile.attendCount}'),
              if (profile.hostRating > 0)
                _buildStatRow('Host rating', profile.hostRating.toStringAsFixed(1)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/pet/${pet.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: pet.photoUrl != null && pet.photoUrl!.isNotEmpty
                    ? NetworkImage(pet.photoUrl!)
                    : null,
                child: pet.photoUrl == null || pet.photoUrl!.isEmpty
                    ? const Icon(Icons.pets, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [pet.breed, pet.type].where((s) => s != null && s.isNotEmpty).join(' \u2022 '),
                      style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: PawPartyColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
