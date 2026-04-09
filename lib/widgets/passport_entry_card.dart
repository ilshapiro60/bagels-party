import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../config/theme.dart';
import '../models/journal_comment.dart';
import '../models/party_album_item.dart';
import '../models/passport_entry.dart';
import '../providers/app_providers.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_party_album_repository.dart';
import '../services/firestore_passport_repository.dart';
import '../utils/media_picker_utils.dart';
import 'fullscreen_video.dart';
import 'paw_file_image.dart';
import 'paw_video_thumb.dart';

class PassportEntryCard extends ConsumerWidget {
  final PassportEntry entry;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool showPetAttribution;
  const PassportEntryCard({
    super.key,
    required this.entry,
    this.onDelete,
    this.onEdit,
    this.showPetAttribution = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(partyAlbumProvider(entry.meetupId));
    final albumItems = albumAsync.value ?? [];
    final comments = entry.isPublic
        ? (ref.watch(journalCommentsProvider(entry.id)).value ?? [])
        : <JournalComment>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (showPetAttribution && entry.petName.isNotEmpty)
            _buildPetAttribution(),
          _buildBody(context, ref, albumItems),
          if (entry.isPublic)
            _buildCommentsSection(context, ref, comments),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeColor(entry.meetupTheme).withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _themeColor(entry.meetupTheme).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _themeColor(entry.meetupTheme).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                entry.playOutcome.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.meetupTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(entry.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: PawPartyColors.textSecondary,
                      ),
                    ),
                    if (entry.meetupTheme != null) ...[
                      const Text(' • ',
                          style: TextStyle(color: PawPartyColors.textHint)),
                      Flexible(
                        child: Text(
                          entry.meetupTheme!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _themeColor(entry.meetupTheme),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (entry.rating != null) _buildRating(entry.rating!),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 20, color: PawPartyColors.textSecondary),
              tooltip: 'Edit entry',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: PawPartyColors.error),
              tooltip: 'Delete entry',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildPetAttribution() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: PawPartyColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.petName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PawPartyColors.secondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, List<PartyAlbumItem> albumItems) {
    final currentUid = ref.watch(authStateProvider).user?.id;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home, size: 14, color: PawPartyColors.textHint),
              const SizedBox(width: 6),
              Text(
                'Hosted by ${entry.hostName}',
                style: TextStyle(
                    fontSize: 13, color: PawPartyColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.pets, size: 14, color: PawPartyColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Met: ${entry.metPetNames.join(", ")}',
                  style: TextStyle(
                      fontSize: 13, color: PawPartyColors.textSecondary),
                ),
              ),
            ],
          ),
          if (entry.behaviorNotes != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PawPartyColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote,
                      size: 16, color: PawPartyColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.behaviorNotes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: PawPartyColors.textPrimary,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (entry.photoUrls.isNotEmpty || entry.videoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...entry.photoUrls.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: PawFileOrNetworkImage(path: p),
                        ),
                      ),
                    ),
                  ),
                  ...entry.videoPaths.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => openFullscreenLocalVideo(context, p),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: PawVideoThumbnail(path: p, height: 72),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Shared party album section
          _buildSharedAlbumSection(context, ref, albumItems, currentUid),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(
                entry.playOutcome.label,
                _outcomeColor(entry.playOutcome),
              ),
              if (entry.warmUpMinutes > 0)
                _tag(
                  '${entry.warmUpMinutes}min warm-up',
                  PawPartyColors.secondary,
                ),
              if (entry.wasAnxious) _tag('Anxious', PawPartyColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSharedAlbumSection(BuildContext context, WidgetRef ref,
      List<PartyAlbumItem> albumItems, String? currentUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.photo_library_outlined,
                size: 14, color: PawPartyColors.textHint),
            const SizedBox(width: 6),
            Text(
              'Party album',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PawPartyColors.textSecondary,
              ),
            ),
            if (albumItems.isNotEmpty)
              Text(
                ' (${albumItems.length})',
                style: TextStyle(
                    fontSize: 12, color: PawPartyColors.textHint),
              ),
            const Spacer(),
            SizedBox(
              height: 28,
              child: TextButton.icon(
                onPressed: () =>
                    _showAddToAlbumSheet(context, ref, entry.meetupId),
                icon: const Icon(Icons.add_photo_alternate, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        if (albumItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: albumItems.length,
              itemBuilder: (ctx, i) {
                final item = albumItems[i];
                final isOwn = item.uploaderId == currentUid;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: PawFileOrNetworkImage(path: item.mediaUrl),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.uploaderName.split(' ').first,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (isOwn)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _confirmDeleteAlbumItem(
                                context, ref, item),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(3),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showAddToAlbumSheet(
      BuildContext context, WidgetRef ref, String meetupId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to party album',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final path = source == ImageSource.gallery
          ? await pickPhotoFromGallery()
          : await pickPhotoFromCamera();
      if (path == null) return;

      final user = ref.read(authStateProvider).user;
      if (user == null) return;

      final storage = FirebaseStorageService.instance;
      final url = await storage.uploadAlbumMedia(
        localPath: path,
        meetupId: meetupId,
      );

      final item = PartyAlbumItem(
        id: const Uuid().v4(),
        meetupId: meetupId,
        uploaderId: user.id,
        uploaderName: user.displayName,
        mediaUrl: url,
        mediaType: 'photo',
        createdAt: DateTime.now(),
      );

      await FirestorePartyAlbumRepository.addItem(item);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added to party album')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add photo: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAlbumItem(
      BuildContext context, WidgetRef ref, PartyAlbumItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('This will remove your photo from the party album.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PawPartyColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;

    try {
      await FirestorePartyAlbumRepository.deleteItem(
        itemId: item.id,
        actingUid: uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  Widget _buildCommentsSection(
      BuildContext context, WidgetRef ref, List<JournalComment> comments) {
    final currentUid = ref.watch(authStateProvider).user?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 14, color: PawPartyColors.textHint),
              const SizedBox(width: 6),
              Text(
                'Comments${comments.isNotEmpty ? ' (${comments.length})' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PawPartyColors.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: TextButton(
                  onPressed: () => _showAddCommentDialog(context, ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...comments.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            PawPartyColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          c.authorDisplayName.isNotEmpty
                              ? c.authorDisplayName[0]
                              : '?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: PawPartyColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.authorDisplayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              c.body,
                              style: TextStyle(
                                fontSize: 12,
                                color: PawPartyColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c.authorId == currentUid)
                        GestureDetector(
                          onTap: () => _deleteComment(context, ref, c),
                          child: Icon(Icons.close,
                              size: 14, color: PawPartyColors.textHint),
                        ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddCommentDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (ok != true || controller.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    try {
      await FirestorePassportRepository.addComment(
        entryId: entry.id,
        authorId: user.id,
        authorDisplayName: user.displayName,
        body: controller.text.trim(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(
      BuildContext context, WidgetRef ref, JournalComment comment) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    try {
      await FirestorePassportRepository.deleteComment(
        entryId: entry.id,
        commentId: comment.id,
        actingUid: uid,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete comment: $e')),
        );
      }
    }
  }

  Widget _buildRating(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PawPartyColors.pizzaGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: PawPartyColors.pizzaGold),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PawPartyColors.pizzaGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _themeColor(String? theme) {
    switch (theme) {
      case 'Summer Splash':
        return Colors.blue;
      case 'Birthday Bash':
        return PawPartyColors.primary;
      case 'Holiday Howl':
        return Colors.red;
      case 'New Pet Welcome':
        return PawPartyColors.secondary;
      default:
        return PawPartyColors.textSecondary;
    }
  }

  Color _outcomeColor(PlayOutcome outcome) {
    switch (outcome) {
      case PlayOutcome.excellent:
        return PawPartyColors.success;
      case PlayOutcome.good:
        return PawPartyColors.secondary;
      case PlayOutcome.okay:
        return PawPartyColors.pizzaGold;
      case PlayOutcome.difficult:
        return PawPartyColors.error;
      case PlayOutcome.notCompatible:
        return Colors.red;
    }
  }
}
