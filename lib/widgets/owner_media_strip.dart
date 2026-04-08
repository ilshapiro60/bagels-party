import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';
import '../providers/app_providers.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_pet_repository.dart';
import '../utils/media_picker_utils.dart';
import 'fullscreen_video.dart';
import 'paw_file_image.dart';
import 'paw_video_thumb.dart';

String _firebaseErrorSnackText(Object e) {
  if (e is FirebaseException) {
    final msg = e.message?.trim();
    if (msg != null && msg.isNotEmpty) return '${e.code}: $msg';
    return e.code;
  }
  return e.toString();
}

class OwnerMediaStrip extends ConsumerStatefulWidget {
  const OwnerMediaStrip({super.key});

  @override
  ConsumerState<OwnerMediaStrip> createState() => _OwnerMediaStripState();
}

class _OwnerMediaStripState extends ConsumerState<OwnerMediaStrip> {
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
    final user = ref.read(authStateProvider).user;
    if (path != null && user != null) {
      try {
        final url = await FirebaseStorageService.instance.uploadProfileAvatar(
          path,
          allowLocalFallback: false,
        );
        if (!mounted) return;
        if (!FirestorePetRepository.isShareableMediaUrl(url)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not upload profile photo. Check your connection and try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        ref.read(authStateProvider.notifier).updateUser(
              user.copyWith(photoUrl: url),
            );
        setState(() {});
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not upload profile photo (${_firebaseErrorSnackText(e)}). '
              'If this is not the network, check Firebase Storage rules and App Check.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not upload profile photo: ${_firebaseErrorSnackText(e)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addGalleryPhoto() async {
    final path = await pickPhotoFromGallery();
    final user = ref.read(authStateProvider).user;
    if (path != null && user != null) {
      try {
        final url =
            await FirebaseStorageService.instance.uploadProfileGalleryImage(
          path,
          allowLocalFallback: false,
        );
        if (!mounted) return;
        if (!FirestorePetRepository.isShareableMediaUrl(url)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not upload photo. Check your connection and try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        ref.read(authStateProvider.notifier).updateUser(
              user.copyWith(
                ownerGalleryImagePaths: [...user.ownerGalleryImagePaths, url],
              ),
            );
        setState(() {});
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not upload photo (${_firebaseErrorSnackText(e)}). '
              'If this is not the network, check Firebase Storage rules and App Check.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload photo: ${_firebaseErrorSnackText(e)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addGalleryVideo() async {
    final path = await pickVideoFromGallery();
    final user = ref.read(authStateProvider).user;
    if (path != null && user != null) {
      try {
        final url =
            await FirebaseStorageService.instance.uploadProfileGalleryVideo(
          path,
          allowLocalFallback: false,
        );
        if (!mounted) return;
        if (!FirestorePetRepository.isShareableMediaUrl(url)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not upload video. Check your connection and try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        ref.read(authStateProvider.notifier).updateUser(
              user.copyWith(
                ownerGalleryVideoPaths: [...user.ownerGalleryVideoPaths, url],
              ),
            );
        setState(() {});
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not upload video (${_firebaseErrorSnackText(e)}). '
              'If this is not the network, check Firebase Storage rules and App Check.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload video: ${_firebaseErrorSnackText(e)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Your photos & videos', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: _setProfilePhoto,
              icon: const Icon(Icons.face, size: 18),
              label: const Text('Profile pic'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...user.ownerGalleryImagePaths.map(
              (path) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: PawFileOrNetworkImage(path: path),
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
                        onTap: () {
                          ref.read(authStateProvider.notifier).updateUser(
                                user.copyWith(
                                  ownerGalleryImagePaths: user.ownerGalleryImagePaths
                                      .where((p) => p != path)
                                      .toList(),
                                ),
                              );
                          setState(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...user.ownerGalleryVideoPaths.map(
              (path) => Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => openFullscreenLocalVideo(context, path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: PawVideoThumbnail(path: path, height: 80),
                      ),
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
                        onTap: () {
                          ref.read(authStateProvider.notifier).updateUser(
                                user.copyWith(
                                  ownerGalleryVideoPaths: user.ownerGalleryVideoPaths
                                      .where((p) => p != path)
                                      .toList(),
                                ),
                              );
                          setState(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Photo'),
              onPressed: _addGalleryPhoto,
            ),
            ActionChip(
              avatar: const Icon(Icons.videocam, size: 18),
              label: const Text('Video'),
              onPressed: _addGalleryVideo,
            ),
          ],
        ),
      ],
    );
  }
}
