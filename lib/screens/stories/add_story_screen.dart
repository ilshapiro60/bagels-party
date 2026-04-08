import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme.dart';
import '../../models/party_story.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_story_repository.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/fullscreen_video.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_video_thumb.dart';

class AddStoryScreen extends ConsumerStatefulWidget {
  const AddStoryScreen({super.key});

  @override
  ConsumerState<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends ConsumerState<AddStoryScreen> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final List<String> _images = [];
  final List<String> _videos = [];
  bool _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _showAddMedia() async {
    final choice = await showModalBottomSheet<String>(
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
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(ctx, 'pg'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Photo with camera'),
              onTap: () => Navigator.pop(ctx, 'pc'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video from gallery'),
              onTap: () => Navigator.pop(ctx, 'vg'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record video'),
              onTap: () => Navigator.pop(ctx, 'vc'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    String? path;
    switch (choice) {
      case 'pg':
        path = await pickPhotoFromGallery();
        if (path != null) setState(() => _images.add(path!));
        break;
      case 'pc':
        path = await pickPhotoFromCamera();
        if (path != null) setState(() => _images.add(path!));
        break;
      case 'vg':
        path = await pickVideoFromGallery();
        if (path != null) setState(() => _videos.add(path!));
        break;
      case 'vc':
        path = await pickVideoFromCamera();
        if (path != null) setState(() => _videos.add(path!));
        break;
    }
  }

  Future<void> _publish() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title for your story')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      final storyId = const Uuid().v4();
      final storage = FirebaseStorageService.instance;
      final imagePaths = <String>[];
      for (final p in _images) {
        imagePaths.add(await storage.uploadStoryMedia(localPath: p, storyId: storyId));
      }
      final videoPaths = <String>[];
      for (final v in _videos) {
        videoPaths.add(await storage.uploadStoryMedia(localPath: v, storyId: storyId));
      }

      final story = PartyStory(
        id: storyId,
        title: _title.text.trim(),
        caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        createdAt: DateTime.now(),
        authorId: user.id,
        authorName: user.displayName,
        authorPhotoPath: user.photoUrl,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
        latitude: user.latitude,
        longitude: user.longitude,
        neighborhoodKey: user.neighborhoodKey,
      );

      await FirestoreStoryRepository.createStory(story);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story posted!')),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New party story'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : () => _publish(),
            child: _publishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PawPartyColors.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g., Best party this spring',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          Text('Photos & videos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showAddMedia,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add media'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._images.map(
                (path) => _ThumbWrap(
                  child: PawFileOrNetworkImage(
                    path: path,
                    width: 88,
                    height: 88,
                  ),
                  onRemove: () => setState(() => _images.remove(path)),
                ),
              ),
              ..._videos.map(
                (path) => _ThumbWrap(
                  child: GestureDetector(
                    onTap: () => openFullscreenLocalVideo(context, path),
                    child: PawVideoThumbnail(path: path, height: 88),
                  ),
                  onRemove: () => setState(() => _videos.remove(path)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'With Firebase configured, media uploads to Storage; otherwise files stay local.',
            style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ThumbWrap extends StatelessWidget {
  const _ThumbWrap({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 88, height: 88, child: child),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: PawPartyColors.error,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
