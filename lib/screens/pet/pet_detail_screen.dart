import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_pet_buddy_repository.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/fullscreen_video.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_video_thumb.dart';

void _invalidatePetBuddyCaches(WidgetRef ref) {
  for (final p in ref.read(userPetsProvider)) {
    ref.invalidate(buddyPetsForPetProvider(p.id));
  }
  ref.invalidate(petBuddyOwnerMutesProvider);
  ref.invalidate(incomingPetBuddyRequestsProvider);
  ref.invalidate(outgoingPetBuddyRequestsProvider);
}

class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({super.key, required this.petId});

  final String petId;

  Pet? _findPet(WidgetRef ref) {
    for (final p in ref.watch(userPetsProvider)) {
      if (p.id == petId) return p;
    }
    for (final p in ref.watch(nearbyPetsProvider)) {
      if (p.id == petId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = _findPet(ref);
    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pet')),
        body: const Center(child: Text('Pet not found')),
      );
    }

    final user = ref.watch(authStateProvider).user;
    final isMine = user != null && pet.ownerId == user.id;
    final owner = ref.watch(ownerProfileProvider(pet.ownerId)).when(
          data: (v) => v,
          error: (err, _) => UserProfile.placeholderNeighbor(pet.ownerId),
          loading: () => UserProfile.placeholderNeighbor(pet.ownerId),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isMine) ...[
            _CompactOwnerStrip(owner: owner),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.push('/edit-pet/${pet.id}', extra: pet),
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _OwnerCard(
              owner: owner,
              isCurrentUser: false,
              trailing: _BefriendPetAction(otherPet: pet),
            ),
            const SizedBox(height: 20),
          ],
          _PetProfileHeader(pet: pet, isMine: isMine),
          _PetBuddiesStrip(profilePetId: pet.id, isMine: isMine),
          if (pet.bio != null && pet.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(pet.bio!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Text('Photos & videos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (isMine) _OwnerMediaActions(pet: pet),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pet.photoUrl != null && pet.photoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PawFileOrNetworkImage(
                    path: pet.photoUrl!,
                    width: 88,
                    height: 88,
                  ),
                ),
              ...pet.photoGallery.map(
                (path) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PawFileOrNetworkImage(path: path, width: 88, height: 88),
                ),
              ),
              ...pet.videoPaths.map(
                (path) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => openFullscreenLocalVideo(context, path),
                    child: PawVideoThumbnail(path: path, height: 88),
                  ),
                ),
              ),
            ],
          ),
          if (pet.photoGallery.isEmpty &&
              pet.videoPaths.isEmpty &&
              (pet.photoUrl == null || pet.photoUrl!.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                isMine
                    ? 'Add photos or videos above to show off your pet.'
                    : 'No extra media yet.',
                style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// Large avatar + name row; owners can set the pet’s main profile photo (camera / gallery).
class _PetProfileHeader extends ConsumerStatefulWidget {
  const _PetProfileHeader({required this.pet, required this.isMine});

  final Pet pet;
  final bool isMine;

  @override
  ConsumerState<_PetProfileHeader> createState() => _PetProfileHeaderState();
}

class _PetProfileHeaderState extends ConsumerState<_PetProfileHeader> {
  bool _busy = false;

  Future<void> _setProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    final path = source == ImageSource.gallery
        ? await pickPhotoFromGallery()
        : await pickPhotoFromCamera();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await FirebaseStorageService.instance.uploadPetAvatar(
        localPath: path,
        petId: widget.pet.id,
      );
      final updated = widget.pet.copyWith(photoUrl: url);
      await ref.read(userPetsProvider.notifier).updatePet(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.pet.photoUrl != null && widget.pet.photoUrl!.isNotEmpty
                  ? "${widget.pet.name}'s profile photo was updated"
                  : "${widget.pet.name}'s profile photo was added",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final hasPhoto = pet.photoUrl != null && pet.photoUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: hasPhoto
                      ? PawFileOrNetworkImage(
                          path: pet.photoUrl!,
                          width: 100,
                          height: 100,
                        )
                      : Container(
                          width: 100,
                          height: 100,
                          color: PawPartyColors.surfaceVariant,
                          child: Icon(Icons.pets, size: 48, color: PawPartyColors.primary),
                        ),
                ),
                if (widget.isMine)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Material(
                      elevation: 2,
                      color: PawPartyColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : _setProfilePhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pet.breed ?? pet.type} • ${pet.gender} • ${pet.ageDisplay}',
                    style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 14),
                  ),
                  Text(
                    pet.size,
                    style: TextStyle(color: PawPartyColors.textHint, fontSize: 13),
                  ),
                  if (widget.isMine) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _setProfilePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(
                        hasPhoto ? 'Change profile photo' : 'Add profile photo',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Minimal owner row for “your pet” — keeps the screen focused on the pet.
class _CompactOwnerStrip extends StatelessWidget {
  const _CompactOwnerStrip({required this.owner});

  final UserProfile owner;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
          child: owner.photoUrl != null && owner.photoUrl!.isNotEmpty
              ? ClipOval(
                  child: PawFileOrNetworkImage(
                    path: owner.photoUrl!,
                    width: 40,
                    height: 40,
                  ),
                )
              : Icon(Icons.person, color: PawPartyColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PawPartyColors.textSecondary,
                ),
              ),
              Text(
                owner.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (owner.neighborhood != null && owner.neighborhood!.isNotEmpty)
                Text(
                  owner.neighborhood!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.isCurrentUser,
    this.trailing,
  });

  final UserProfile owner;
  final bool isCurrentUser;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PawPartyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
              child: owner.photoUrl != null && owner.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: PawFileOrNetworkImage(
                        path: owner.photoUrl!,
                        width: 56,
                        height: 56,
                      ),
                    )
                  : Icon(Icons.person, color: PawPartyColors.primary, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentUser ? 'You' : 'Pet parent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PawPartyColors.textSecondary,
                    ),
                  ),
                  Text(
                    owner.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (owner.neighborhood != null)
                    Text(
                      owner.neighborhood!,
                      style: TextStyle(fontSize: 13, color: PawPartyColors.textHint),
                    ),
                ],
              ),
            ),
            if (!isCurrentUser)
              trailing ??
                  FilledButton.tonal(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Messaging coming soon')),
                      );
                    },
                    child: const Text('Message'),
                  ),
          ],
        ),
      ),
    );
  }
}

Future<void> _onBefriendTap(
  BuildContext context,
  WidgetRef ref,
  String myUid,
  List<Pet> myPets,
  Pet otherPet,
) async {
  if (!isFirebaseInitialized) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Firebase must be configured to connect pets.'),
      ),
    );
    return;
  }
  if (myPets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a pet to your profile first.')),
    );
    return;
  }
  final Pet? chosen = myPets.length == 1
      ? myPets.first
      : await showModalBottomSheet<Pet>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    'Which pet is connecting?',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                ...myPets.map(
                  (p) => ListTile(
                    leading: CircleAvatar(
                      child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                    ),
                    title: Text(p.name),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
  if (chosen == null || !context.mounted) return;
  if (await FirestorePetBuddyRepository.isMutedBetween(myUid, otherPet.ownerId)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Paw buddy requests are blocked with this parent. You can unblock under Friends.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  try {
    final sent = await FirestorePetBuddyRepository.sendBuddyRequest(
      fromUid: myUid,
      fromPetId: chosen.id,
      toPetId: otherPet.id,
      toOwnerId: otherPet.ownerId,
    );
    ref.invalidate(outgoingPetBuddyRequestsProvider);
    if (!context.mounted) return;
    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send a new request (it may already be pending).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Request sent. ${otherPet.name}'s parent can accept under Friends.",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not save: $e')),
    );
  }
}

class _BefriendPetAction extends ConsumerWidget {
  const _BefriendPetAction({required this.otherPet});

  final Pet otherPet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    if (user == null) return const SizedBox.shrink();

    final myPets = ref.watch(userPetsProvider);
    final buddiesAsync = ref.watch(buddyPetsForPetProvider(otherPet.id));
    final outgoingAsync = ref.watch(outgoingPetBuddyRequestsProvider);
    final mutesAsync = ref.watch(petBuddyOwnerMutesProvider);

    final loading = buddiesAsync.isLoading ||
        outgoingAsync.isLoading ||
        mutesAsync.isLoading;
    if (loading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final mutes = mutesAsync.value ?? [];
    final mutedWithOwner = mutes.any(
      (m) => m.otherUid(user.id) == otherPet.ownerId,
    );
    if (mutedWithOwner) {
      return Chip(
        avatar: Icon(Icons.block, size: 18, color: PawPartyColors.textSecondary),
        label: const Text('Blocked'),
        side: BorderSide(color: PawPartyColors.divider),
      );
    }

    final buddies = buddiesAsync.value ?? [];
    final outgoing = outgoingAsync.value ?? [];
    final mine = myPets.map((p) => p.id).toSet();
    final linked = buddies.any((p) => mine.contains(p.id));
    if (linked) {
      return Chip(
        avatar: Icon(Icons.pets, size: 18, color: PawPartyColors.primary),
        label: const Text('Paw buddies'),
        side: BorderSide(
          color: PawPartyColors.primary.withValues(alpha: 0.35),
        ),
        backgroundColor: PawPartyColors.primary.withValues(alpha: 0.08),
      );
    }

    final pendingOut = outgoing.any((r) => r.toPetId == otherPet.id);
    if (pendingOut) {
      return Chip(
        avatar: Icon(Icons.schedule_send, size: 18, color: PawPartyColors.textSecondary),
        label: const Text('Request sent'),
        side: BorderSide(color: PawPartyColors.divider),
      );
    }

    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: () => _onBefriendTap(context, ref, user.id, myPets, otherPet),
      child: const Text('Befriend'),
    );
  }
}

class _PetBuddiesStrip extends ConsumerWidget {
  const _PetBuddiesStrip({
    required this.profilePetId,
    required this.isMine,
  });

  final String profilePetId;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(buddyPetsForPetProvider(profilePetId));
    final myUid = ref.watch(authStateProvider).user?.id;
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (buddies) {
        if (buddies.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paw buddies',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: buddies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final b = buddies[i];
                  return Material(
                    color: PawPartyColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          onTap: () => context.push('/pet/${b.id}'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 88,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PawPartyColors.divider),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: b.photoUrl != null &&
                                            b.photoUrl!.isNotEmpty
                                        ? PawFileOrNetworkImage(
                                            path: b.photoUrl!,
                                            width: 72,
                                            height: 72,
                                          )
                                        : ColoredBox(
                                            color: PawPartyColors.surfaceVariant,
                                            child: Center(
                                              child: Icon(
                                                Icons.pets,
                                                color: PawPartyColors.primary,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  b.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isMine && myUid != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Material(
                              color: PawPartyColors.surface.withValues(
                                alpha: 0.95,
                              ),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                tooltip: 'Buddy options',
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove paw buddy'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'block',
                                    child: Text("Block parent's pets"),
                                  ),
                                ],
                                onSelected: (value) async {
                                  if (value == 'remove') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Remove paw buddy?'),
                                        content: Text(
                                          'Remove ${b.name} as a paw buddy for this pet? '
                                          'You can send a new request later (unless blocked).',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true || !context.mounted) return;
                                    try {
                                      await FirestorePetBuddyRepository
                                          .removeBuddy(profilePetId, b.id);
                                      _invalidatePetBuddyCaches(ref);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${b.name} is no longer a paw buddy for this pet.',
                                            ),
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Could not remove: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  } else if (value == 'block') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Block pet parent?'),
                                        content: Text(
                                          'This removes every paw buddy link between your pets '
                                          "and ${b.name}'s parent's pets, and stops new buddy "
                                          'requests in both directions until you unblock under Friends.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, true),
                                            child: const Text('Block'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true || !context.mounted) return;
                                    try {
                                      await FirestorePetBuddyRepository
                                          .muteBuddyOwners(
                                        actingUid: myUid,
                                        otherOwnerId: b.ownerId,
                                      );
                                      _invalidatePetBuddyCaches(ref);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Paw buddy links with that parent are removed and blocked.',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Could not block: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _OwnerMediaActions extends ConsumerStatefulWidget {
  const _OwnerMediaActions({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_OwnerMediaActions> createState() => _OwnerMediaActionsState();
}

class _OwnerMediaActionsState extends ConsumerState<_OwnerMediaActions> {
  bool _busy = false;

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    final path = source == ImageSource.gallery
        ? await pickPhotoFromGallery()
        : await pickPhotoFromCamera();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await FirebaseStorageService.instance.uploadPetGalleryPhoto(
        localPath: path,
        petId: widget.pet.id,
      );
      final updated = widget.pet.copyWith(
        photoGallery: [...widget.pet.photoGallery, url],
      );
      await ref.read(userPetsProvider.notifier).updatePet(updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addVideo() async {
    final useCamera = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video from gallery'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record video'),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (!mounted || useCamera == null) return;
    final path = useCamera
        ? await pickVideoFromCamera()
        : await pickVideoFromGallery();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await FirebaseStorageService.instance.uploadPetVideo(
        localPath: path,
        petId: widget.pet.id,
      );
      final updated = widget.pet.copyWith(
        videoPaths: [...widget.pet.videoPaths, url],
      );
      await ref.read(userPetsProvider.notifier).updatePet(updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ActionChip(
          avatar: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate, size: 18),
          label: const Text('Add photo'),
          onPressed: _busy ? null : _addPhoto,
        ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: const Icon(Icons.videocam, size: 18),
          label: const Text('Add video'),
          onPressed: _busy ? null : _addVideo,
        ),
      ],
    );
  }
}
