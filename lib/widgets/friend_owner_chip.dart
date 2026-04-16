import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../providers/app_providers.dart';
import 'paw_file_image.dart';
import 'paw_fullscreen_photo_viewer.dart';

/// Home / Friends: friend parent avatar + first name.
///
/// When [openFullscreenOnAvatarTap] is true (default, e.g. Home), tapping the
/// photo opens a fullscreen gallery when URLs exist; the name always opens profile.
/// When false (e.g. Friends / Manage), avatar and name both open profile only.
class FriendOwnerChip extends ConsumerWidget {
  const FriendOwnerChip({
    super.key,
    required this.uid,
    this.openFullscreenOnAvatarTap = true,
  });

  final String uid;
  final bool openFullscreenOnAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerProfileProvider(uid));
    return async.when(
      data: (p) {
        final urls = p.ownerPhotoUrlsForViewer;
        final thumb = p.photoUrl != null && p.photoUrl!.trim().isNotEmpty
            ? p.photoUrl!.trim()
            : (urls.isNotEmpty ? urls.first : null);

        final avatar = CircleAvatar(
          radius: 22,
          backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
          child: thumb != null
              ? ClipOval(
                  child: PawFileOrNetworkImage(
                    path: thumb,
                    width: 44,
                    height: 44,
                  ),
                )
              : Text(
                  p.displayName.isNotEmpty ? p.displayName[0] : '?',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: PawPartyColors.primary,
                  ),
                ),
        );

        final name = Text(
          p.displayName.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        );

        if (!openFullscreenOnAvatarTap) {
          return SizedBox(
            width: 56,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/friend/$uid'),
              child: Column(
                children: [
                  avatar,
                  const SizedBox(height: 4),
                  name,
                ],
              ),
            ),
          );
        }

        return SizedBox(
          width: 56,
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (urls.isNotEmpty) {
                    showPawFullscreenPhotos(context, urls: urls);
                  } else {
                    context.push('/friend/$uid');
                  }
                },
                child: avatar,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/friend/$uid'),
                child: name,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox(width: 56),
    );
  }
}
