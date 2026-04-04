import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/fullscreen_video.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_video_thumb.dart';

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
          _OwnerCard(owner: owner, isCurrentUser: owner.id == user?.id),
          const SizedBox(height: 20),
          _PetProfileHeader(pet: pet, isMine: isMine),
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

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner, required this.isCurrentUser});

  final UserProfile owner;
  final bool isCurrentUser;

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
